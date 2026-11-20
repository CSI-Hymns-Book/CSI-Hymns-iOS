import SwiftUI
import UIKit

/// Admin-only presenter tools for one song: export it for FreeShow, or project it to a FreeShow
/// running on the same Wi-Fi network.
struct FreeShowPresenterSheet: View {
    let hymn: Hymn

    @Environment(\.dismiss) private var dismiss
    @State private var mode: LyricsLanguageMode
    @State private var host: String
    @State private var portText: String
    @State private var password: String
    @State private var projectURL: URL?

    private let remote = FreeShowRemoteManager.shared

    init(hymn: Hymn) {
        self.hymn = hymn
        let remote = FreeShowRemoteManager.shared
        _mode = State(initialValue: hymn.lyricsKannada.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .english : .kannada)
        _host = State(initialValue: remote.savedHost)
        _portText = State(initialValue: String(remote.savedPort))
        _password = State(initialValue: remote.savedPassword)
    }

    private var isKeerthane: Bool { hymn.type == "keerthane" }

    private var slides: [PresentationSlide] {
        FreeShowFormatter.parseSlides(
            number: hymn.number,
            title: hymn.title,
            isKeerthane: isKeerthane,
            kannadaLyrics: hymn.lyricsKannada,
            englishLyrics: hymn.lyricsEnglish,
            mode: mode
        )
    }

    private var quickLyricsText: String {
        FreeShowFormatter.formatQuickLyricsText(number: hymn.number, title: hymn.title, isKeerthane: isKeerthane, slides: slides)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lyrics") {
                    Picker("Language", selection: $mode) {
                        ForEach(LyricsLanguageMode.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Slides (\(slides.count))") {
                    ForEach(Array(slides.enumerated()), id: \.offset) { _, slide in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(slide.group).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(slide.content).font(.footnote).lineLimit(2)
                        }
                    }
                }

                Section("Export") {
                    if let projectURL {
                        ShareLink(item: projectURL) {
                            Label("Share FreeShow project (.project)", systemImage: "square.and.arrow.up")
                        }
                    }
                    ShareLink(item: quickLyricsText, subject: Text("\(hymn.title)")) {
                        Label("Share Quick Lyrics text", systemImage: "text.alignleft")
                    }
                }

                projectorSection
            }
            .navigationTitle("Presenter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: mode) { projectURL = makeProjectFile() }
        }
    }

    // MARK: - Projector

    private var projectorSection: some View {
        Section {
            TextField("FreeShow IP address", text: $host)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Port", text: $portText)
                .keyboardType(.numberPad)
            SecureField("Remote password", text: $password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                beam()
            } label: {
                Label(remote.isConnected ? "Beam this song" : "Connect & beam", systemImage: "dot.radiowaves.left.and.right")
            }
            .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty || slides.isEmpty)

            statusRow

            if remote.isConnected {
                HStack {
                    Button { remote.previousSlide() } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Button { remote.toggleClear() } label: {
                        Label(remote.isScreenCleared ? "Show" : "Clear", systemImage: remote.isScreenCleared ? "play.rectangle" : "rectangle.slash")
                    }
                    Spacer()
                    Button { remote.nextSlide() } label: { Image(systemName: "chevron.right") }
                }
                .buttonStyle(.bordered)
                Button("Disconnect", role: .destructive) { remote.disconnect() }
            }
        } header: {
            Text("Project to FreeShow")
        } footer: {
            Text("Your phone and the computer running FreeShow must be on the same Wi-Fi, with FreeShow's remote control turned on.")
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch remote.state {
        case .disconnected:
            EmptyView()
        case .connecting(let host):
            HStack(spacing: 8) { ProgressView(); Text("Connecting to \(host)…").font(.footnote) }
        case .connected(let host, _):
            Label("Connected to \(host)", systemImage: "checkmark.circle.fill").font(.footnote).foregroundStyle(.green)
            if let index = remote.liveSlideIndex, index >= 0, index < slides.count {
                Text("Live: \(slides[index].group)").font(.footnote).foregroundStyle(.secondary)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.red)
        }
    }

    private func beam() {
        guard let show = FreeShowFormatter.showForBeam(
            number: hymn.number,
            title: hymn.title,
            isKeerthane: isKeerthane,
            slides: slides,
            logoDataURI: Self.logoPNG(size: 96).map { "data:image/png;base64," + $0.base64EncodedString() }
        ) else { return }

        if remote.isConnected {
            remote.beam(showId: show.id, showJSON: show.json)
        } else {
            remote.connect(
                host: host,
                port: Int(portText.trimmingCharacters(in: .whitespaces)) ?? FreeShowRemoteManager.defaultPort,
                password: password,
                pendingShow: show
            )
        }
    }

    // MARK: - Files

    private func makeProjectFile() -> URL? {
        guard let file = FreeShowFormatter.projectFile(
            number: hymn.number,
            title: hymn.title,
            isKeerthane: isKeerthane,
            slides: slides,
            logoPNG: Self.logoPNG(size: 256)
        ) else { return nil }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FreeShow", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(file.fileName)
            try file.data.write(to: url, options: .atomic)
            return url
        } catch {
            print("FreeShowPresenterSheet: could not write project file: \(error)")
            return nil
        }
    }

    /// The app logo as a square PNG, shown in the credit line of each slide.
    private static func logoPNG(size: CGFloat) -> Data? {
        guard let image = UIImage(named: "app_logo") else { return nil }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.pngData { _ in image.draw(in: CGRect(x: 0, y: 0, width: size, height: size)) }
    }
}
