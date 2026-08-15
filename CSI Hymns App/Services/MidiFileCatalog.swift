import Foundation
import Observation

/// Prefetches and caches GitHub midi-vault Hymns file names (Android `HymnsRepository.getMidiFileNames`).
@MainActor
@Observable
public final class MidiFileCatalog {
    public static let shared = MidiFileCatalog()
    
    public private(set) var fileNames: [String] = []
    public private(set) var isLoading = false
    public private(set) var lastError: String?
    
    private static let jsonKey = "cached_midi_files_json"
    private static let fingerprintKey = "cached_midi_files_fingerprint"
    
    private let fallbackList = [
        "c.m.refrain_wondrous_love.mid",
        "5.5.8.8.5.5_fleming.mid",
        "7.7.7.7.refrain.mid",
        "11.10.11.10.mid",
        "s.m.mid",
        "c.m.mid",
        "l.m.mid",
        "d.c.m.mid",
        "6.5.6.5.mid",
        "8.7.8.7.mid",
        "7.6.7.6.d.mid"
    ]
    
    private init() {
        if let cached = loadCachedNames(), !cached.isEmpty {
            fileNames = cached
        } else {
            fileNames = fallbackList
        }
        Task { await refresh() }
    }
    
    public func refresh(force: Bool = false) async {
        let fingerprint = MidiFileCache.currentFingerprint()
        let storedFingerprint = UserDefaults.standard.string(forKey: Self.fingerprintKey)
        
        if !force,
           fingerprint == storedFingerprint,
           let cached = loadCachedNames(),
           !cached.isEmpty {
            fileNames = cached
            return
        }
        
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        let token = cleanToken(UserDefaults.standard.string(forKey: "github_midi_token_cached"))
        guard let url = URL(string: "https://api.github.com/repos/Reynold29/midi-vault/contents/Hymns") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("CSI-Hymns-iOS", forHTTPHeaderField: "User-Agent")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                lastError = "MIDI catalog HTTP error"
                if fileNames.isEmpty { fileNames = fallbackList }
                return
            }
            let names = parseGitHubContentsNames(data)
            if names.isEmpty {
                if fileNames.isEmpty { fileNames = fallbackList }
                return
            }
            fileNames = names
            if let json = String(data: data, encoding: .utf8) {
                UserDefaults.standard.set(json, forKey: Self.jsonKey)
                UserDefaults.standard.set(fingerprint, forKey: Self.fingerprintKey)
            }
        } catch {
            lastError = error.localizedDescription
            if fileNames.isEmpty { fileNames = fallbackList }
        }
    }
    
    public func hasMatchingFiles(for option: String, hymnNumber: Int) -> Bool {
        let baseMeter = option.contains("_") ? String(option.split(separator: "_").first ?? Substring(option)) : option
        let normalized = MeterUtils.normalizedMeter(baseMeter)
        let lowerNum = "\(hymnNumber)"
        return fileNames.contains { filename in
            let name = filename.replacingOccurrences(of: ".mid", with: "", options: [.caseInsensitive, .anchored])
                .replacingOccurrences(of: ".mid", with: "", options: .caseInsensitive)
            let nameWithoutExt = filename.lowercased().hasSuffix(".mid")
                ? String(filename.dropLast(4))
                : filename
            let normalizedName = MeterUtils.normalizedMeter(nameWithoutExt)
            return nameWithoutExt.caseInsensitiveCompare(option) == .orderedSame
                || normalizedName == normalized
                || normalizedName.hasPrefix("\(normalized)_")
                || nameWithoutExt.lowercased().hasPrefix("hymn_\(lowerNum)")
                || nameWithoutExt.lowercased().hasPrefix("\(lowerNum)_")
        }
    }
    
    private func loadCachedNames() -> [String]? {
        guard let json = UserDefaults.standard.string(forKey: Self.jsonKey),
              let data = json.data(using: .utf8) else { return nil }
        let names = parseGitHubContentsNames(data)
        return names.isEmpty ? nil : names
    }
    
    private func parseGitHubContentsNames(_ data: Data) -> [String] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return arr.compactMap { $0["name"] as? String }
    }
    
    private func cleanToken(_ raw: String?) -> String? {
        guard var token = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty, token != "null" else {
            return nil
        }
        token = token
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }
}
