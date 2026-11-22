import Foundation
import Observation
import Security

/// Who may see the presenter tools: signed-in admins, and only while presenter mode is switched on
/// (remote config `presenter_mode_enabled`, or the local override saved from Admin Controls).
enum PresenterMode {
    static var isAvailable: Bool {
        let config = AppConfigService.shared.config
        guard AdminPrefs.hasAnyAdminRole(
            currentUserEmail: SupabaseService.instance.currentUserEmail,
            adminEmailsConfig: config.adminEmails
        ) else { return false }
        if config.presenterModeEnabled == true { return true }
        guard let data = UserDefaults.standard.data(forKey: "admin_local_config"),
              let local = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return local["presenter_mode_enabled"] as? Bool == true
    }
}

/// Controls FreeShow (church projection software, port 5510) on the local Wi-Fi network over its
/// Socket.IO 4 WebSocket, the same protocol the Android app speaks. Connection is by IP address;
/// automatic discovery is not ported.
@MainActor
@Observable
final class FreeShowRemoteManager {
    static let shared = FreeShowRemoteManager()

    nonisolated static let defaultPort = 5510
    nonisolated static let defaultPassword = "1542"
    private static let connectTimeout: Duration = .seconds(8)

    enum ConnectionState: Equatable {
        case disconnected
        case connecting(host: String)
        case connected(host: String, port: Int)
        case failed(message: String)
    }

    private(set) var state: ConnectionState = .disconnected
    private(set) var liveSlideIndex: Int?
    private(set) var isScreenCleared = false

    private var socket: URLSessionWebSocketTask?
    /// Bumped on every connect and disconnect so callbacks from an older socket are ignored.
    private var generation = 0
    private var pendingPassword = defaultPassword
    private var pendingShow: (id: String, json: String)?
    private var currentShowId: String?
    private let session = URLSession(configuration: .default)

    private init() {}

    // MARK: - Saved connection

    var savedHost: String { UserDefaults.standard.string(forKey: "freeshow_last_host") ?? "" }

    var savedPort: Int {
        let port = UserDefaults.standard.integer(forKey: "freeshow_last_port")
        return port == 0 ? Self.defaultPort : port
    }

    /// The password lives in the Keychain, not in UserDefaults.
    var savedPassword: String { FreeShowKeychain.load() ?? Self.defaultPassword }

    private func saveConnection(host: String, port: Int, password: String) {
        UserDefaults.standard.set(host, forKey: "freeshow_last_host")
        UserDefaults.standard.set(port, forKey: "freeshow_last_port")
        FreeShowKeychain.save(password)
    }

    // MARK: - Connection

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    /// Connects to FreeShow and, once it accepts the password, sends `pendingShow` and projects its first slide.
    func connect(host: String, port: Int = defaultPort, password: String = defaultPassword, pendingShow: (id: String, json: String)? = nil) {
        disconnect()

        let cleanHost = host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^(https?|wss?)://", with: "", options: .regularExpression)
        guard !cleanHost.isEmpty else {
            state = .failed(message: "Please enter a valid IP address")
            return
        }
        guard (1...65535).contains(port),
              let url = URL(string: "ws://\(cleanHost):\(port)/socket.io/?EIO=4&transport=websocket") else {
            state = .failed(message: "That address or port is not valid")
            return
        }

        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingPassword = trimmedPassword.isEmpty ? Self.defaultPassword : trimmedPassword
        self.pendingShow = pendingShow
        state = .connecting(host: cleanHost)

        let task = session.webSocketTask(with: url)
        socket = task
        let connectionGeneration = generation
        task.resume()
        listen(on: task, generation: connectionGeneration, host: cleanHost, port: port)

        Task { [weak self] in
            try? await Task.sleep(for: Self.connectTimeout)
            guard let self, connectionGeneration == self.generation, case .connecting = self.state else { return }
            self.fail("FreeShow did not answer at \(cleanHost):\(port). Check the IP address, the password and that FreeShow's remote is on.")
        }
    }

    func disconnect() {
        generation += 1
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        pendingShow = nil
        currentShowId = nil
        liveSlideIndex = nil
        isScreenCleared = false
        state = .disconnected
    }

    private func fail(_ message: String) {
        generation += 1
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        pendingShow = nil
        liveSlideIndex = nil
        state = .failed(message: message)
    }

    private func listen(on task: URLSessionWebSocketTask, generation connectionGeneration: Int, host: String, port: Int) {
        task.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, connectionGeneration == self.generation else { return }
                switch result {
                case .success(let message):
                    if case .string(let text) = message {
                        self.handle(text, host: host, port: port)
                    }
                    self.listen(on: task, generation: connectionGeneration, host: host, port: port)
                case .failure(let error):
                    if case .connected = self.state {
                        self.disconnect()
                    } else {
                        self.fail("Could not connect to FreeShow at \(host):\(port): \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Protocol

    private func handle(_ message: String, host: String, port: Int) {
        if message.hasPrefix("0") {
            // Engine.IO handshake: open the Socket.IO session.
            send("40")
        } else if message.hasPrefix("40") {
            // Socket.IO connected: authenticate with the remote password.
            send("42\(remotePacket(channel: "ACCESS", payload: pendingPassword))")
        } else if message == "2" {
            // Engine.IO ping.
            send("3")
        } else if message.hasPrefix("42") {
            handleEvent(String(message.dropFirst(2)), host: host, port: port)
        }
    }

    private func handleEvent(_ json: String, host: String, port: Int) {
        guard let data = json.data(using: .utf8),
              let array = (try? JSONSerialization.jsonObject(with: data)) as? [Any],
              array.count >= 2,
              array[0] as? String == "REMOTE",
              let packet = array[1] as? [String: Any],
              let channel = packet["channel"] as? String else { return }
        let payload = packet["data"]

        switch channel {
        case "ACCESS":
            saveConnection(host: host, port: port, password: pendingPassword)
            state = .connected(host: host, port: port)
            if let show = pendingShow {
                pendingShow = nil
                beam(showId: show.id, showJSON: show.json)
            }
        case "OUT":
            guard let out = payload as? [String: Any] else { return }
            let slide = out["slide"] as? Int
            liveSlideIndex = slide
            isScreenCleared = slide == nil
            currentShowId = (out["show"] as? [String: Any])?["id"] as? String ?? currentShowId
        case "OUT_DATA":
            guard let out = payload as? [String: Any], out["slide"] != nil else { return }
            let slide = out["slide"] as? Int
            liveSlideIndex = slide
            isScreenCleared = slide == nil
        default:
            break
        }
    }

    private func send(_ text: String) {
        socket?.send(.string(text)) { error in
            if let error { print("FreeShowRemoteManager: send failed: \(error.localizedDescription)") }
        }
    }

    private func remotePacket(channel: String, payload: Any) -> String {
        let packet: [Any] = ["REMOTE", ["id": "", "channel": channel, "data": payload]]
        return FreeShowFormatter.jsonString(packet, pretty: false) ?? "[]"
    }

    private func sendRemote(_ channel: String, _ payload: Any = [String: Any]()) {
        send("42\(remotePacket(channel: channel, payload: payload))")
    }

    // MARK: - Controls

    /// Sends a show to FreeShow, selects it and projects its first slide.
    func beam(showId: String, showJSON: String) {
        currentShowId = showId
        sendRemote("API:set_show", ["id": showId, "value": showJSON])
        Task { [weak self] in
            // Give FreeShow a moment to register the show before selecting it.
            try? await Task.sleep(for: .milliseconds(150))
            self?.sendRemote("API:id_select_show", ["id": showId])
            try? await Task.sleep(for: .milliseconds(100))
            self?.selectSlide(0)
        }
    }

    func selectSlide(_ index: Int) {
        guard let showId = currentShowId else { return }
        liveSlideIndex = index
        isScreenCleared = false
        sendRemote("API:index_select_slide", ["index": index, "showId": showId])
    }

    func nextSlide() {
        liveSlideIndex = (liveSlideIndex ?? -1) + 1
        isScreenCleared = false
        sendRemote("API:next_slide")
    }

    func previousSlide() {
        if let current = liveSlideIndex, current > 0 { liveSlideIndex = current - 1 }
        isScreenCleared = false
        sendRemote("API:previous_slide")
    }

    func toggleClear() {
        if isScreenCleared {
            isScreenCleared = false
            sendRemote("API:restore_output")
        } else {
            isScreenCleared = true
            sendRemote("API:clear_all")
        }
    }
}

private enum FreeShowKeychain {
    private static let service = "com.reyzie.hymns.freeshow"
    private static let account = "remote-password"

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    static func save(_ password: String) {
        SecItemDelete(baseQuery as CFDictionary)
        var item = baseQuery
        item[kSecValueData as String] = Data(password.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    static func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
