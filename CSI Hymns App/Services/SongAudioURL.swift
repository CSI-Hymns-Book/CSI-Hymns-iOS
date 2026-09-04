import Foundation

/// Builds CDN / midi-vault audio URLs (Android AudioViewModel + HymnDetailScreen parity).
enum SongAudioURL {
    static let midiVaultBase = "https://raw.githubusercontent.com/Reynold29/midi-vault/main"
    static let midiFilesBase = "https://raw.githubusercontent.com/reynold29/midi-files/main"
    
    struct AudioConfig {
        let midiHymns: Set<String>
        let midiKeerthanes: Set<Int>
        let disableOgg: String
        let audioBackup: String?
        let githubToken: String?
        let midiFileNames: [String]
    }
    
    static var currentConfig: AudioConfig {
        let defaults = UserDefaults.standard
        return AudioConfig(
            midiHymns: RemoteAppConfig.parseMeters(defaults.string(forKey: "midi_hymns_ranges_cached")),
            midiKeerthanes: RemoteAppConfig.parseRanges(defaults.string(forKey: "midi_keerthanes_ranges_cached")),
            disableOgg: (defaults.string(forKey: "disable_ogg_fallback_cached") ?? "").lowercased(),
            audioBackup: defaults.string(forKey: "audio_backup_url_cached")?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            githubToken: defaults.string(forKey: "github_midi_token_cached")?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            midiFileNames: cachedMidiFileNames()
        )
    }
    
    private static func cachedMidiFileNames() -> [String] {
        guard let json = UserDefaults.standard.string(forKey: "cached_midi_files_json"),
              let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return arr.compactMap { $0["name"] as? String }
    }
    
    static func streamURL(for hymn: Hymn, selectedTune: String? = nil, midiFiles: [String]? = nil) -> String {
        let config = currentConfig
        let files = midiFiles ?? config.midiFileNames
        let option = selectedTune ?? defaultOption(for: hymn)
        let isMidi = isMidiMigrated(hymn: hymn, option: option, files: files, config: config)
        
        if hymn.type == "keerthane" {
            if isMidi {
                return "\(midiVaultBase)/Keerthane/Keerthane_\(hymn.number).mid"
            }
            return "\(midiFilesBase)/Keerthane/Keerthane_\(hymn.number).ogg"
        }
        
        if hymn.type == "mt" || isMtReference(option) {
            let source = selectedTune ?? option
            let resolved = mangaloreTuneToken(from: source, fallbackNumber: hymn.number)
            return "\(midiVaultBase)/Mangalore%20Tunes/mt\(resolved).mid"
        }
        
        if isMidi {
            // Song-specific MIDI stems (hymn_12 / 12_v2) use the option as filename.
            if looksLikeSongSpecificStem(option, hymnNumber: hymn.number) {
                let encoded = option.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? option
                return "\(midiVaultBase)/Hymns/\(encoded).mid"
            }
            let meterName = MeterUtils.meterMidiFileName(option.isEmpty ? "\(hymn.number)" : option)
            return "\(midiVaultBase)/Hymns/\(meterName).mid"
        }
        
        return "\(midiFilesBase)/Hymns/Hymn_\(hymn.number).ogg"
    }
    
    static func oggFallbackURL(for hymn: Hymn) -> String {
        if hymn.type == "keerthane" {
            return "\(midiFilesBase)/Keerthane/Keerthane_\(hymn.number).ogg"
        }
        return "\(midiFilesBase)/Hymns/Hymn_\(hymn.number).ogg"
    }
    
    static func shouldAllowOggFallback(for hymn: Hymn) -> Bool {
        let config = currentConfig
        if hymn.type == "keerthane" {
            let forced = config.midiKeerthanes.contains(hymn.number)
                || config.disableOgg == "keerthane"
                || config.disableOgg == "both"
            return !forced
        }
        if hymn.type == "mt" { return false }
        let forced = config.disableOgg == "hymns" || config.disableOgg == "both"
        return !forced
    }
    
    static func backupURL(for primaryURL: String) -> String? {
        guard let base = currentConfig.audioBackup?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty,
              base != "null" else { return nil }
        let trimmedBase = base.hasSuffix("/") ? String(base.dropLast()) : base
        let prefixes = [
            "https://raw.githubusercontent.com/Reynold29/midi-vault/main/",
            "https://raw.githubusercontent.com/reynold29/midi-vault/main/",
            "https://raw.githubusercontent.com/reynold29/midi-files/main/",
            "https://raw.githubusercontent.com/Reynold29/midi-files/main/"
        ]
        for prefix in prefixes where primaryURL.lowercased().hasPrefix(prefix.lowercased()) {
            let path = String(primaryURL.dropFirst(prefix.count))
            return "\(trimmedBase)/\(path)"
        }
        if let range = primaryURL.range(of: "api.github.com/repos/Reynold29/midi-vault/contents/") {
            let path = String(primaryURL[range.upperBound...])
            return "\(trimmedBase)/\(path)"
        }
        return nil
    }
    
    static func isMidiFileURL(_ url: String) -> Bool {
        url.lowercased().hasSuffix(".mid") || url.lowercased().hasSuffix(".midi")
    }
    
    static func checkUrlExists(urlStr: String) async -> Bool {
        guard URL(string: urlStr) != nil else { return false }
        var request: URLRequest
        if let token = currentConfig.githubToken,
           urlStr.localizedCaseInsensitiveContains("midi-vault"),
           let api = githubProbeRequest(urlStr: urlStr, token: token) {
            request = api
        } else if let url = URL(string: urlStr) {
            request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 2.0
        } else {
            return false
        }
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 500
            return (200...399).contains(code)
        } catch {
            return false
        }
    }
    
    private static func githubProbeRequest(urlStr: String, token: String) -> URLRequest? {
        let rawPath: String
        if let range = urlStr.range(of: "/midi-vault/main/", options: .caseInsensitive) {
            rawPath = String(urlStr[range.upperBound...])
        } else {
            return nil
        }
        let decoded = rawPath.removingPercentEncoding ?? rawPath
        let encoded = decoded.split(separator: "/").map {
            String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
        }.joined(separator: "/")
        guard let apiURL = URL(string: "https://api.github.com/repos/Reynold29/midi-vault/contents/\(encoded)") else {
            return nil
        }
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 3
        return request
    }
    
    static func extractTuneOptions(for hymn: Hymn, midiFiles: [String]? = nil) -> [String] {
        let files = midiFiles ?? currentConfig.midiFileNames
        if hymn.type == "keerthane" { return ["\(hymn.number)"] }
        
        var options: [String] = []
        let signature = hymn.signature
        
        if hymn.type == "mt" {
            if let regex = try? NSRegularExpression(pattern: "\\b\\d+[b-e]?\\b", options: [.caseInsensitive]) {
                let ns = signature as NSString
                options = regex.matches(in: signature, range: NSRange(location: 0, length: ns.length))
                    .map { ns.substring(with: $0.range).lowercased() }
            }
            if options.isEmpty { options.append("\(hymn.number)") }
            return unique(options)
        }
        
        // Song-specific MIDI files first (hymn_N / N_v2 / hymn_N_name)
        let songNum = "\(hymn.number)"
        let songSpecific = files.filter { filename in
            let name = stem(filename).lowercased()
            return name == "hymn_\(songNum)"
                || name == songNum
                || name.hasPrefix("hymn_\(songNum)_")
                || name.hasPrefix("\(songNum)_")
        }.sorted { a, b in
            let an = stem(a).lowercased()
            let bn = stem(b).lowercased()
            if an == "hymn_\(songNum)" || an == songNum { return true }
            if bn == "hymn_\(songNum)" || bn == songNum { return false }
            return an < bn
        }
        options.append(contentsOf: songSpecific.map { stem($0) })
        
        let signatures: [String]
        if signature.contains("/") {
            signatures = signature.split(separator: "/").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        } else if !signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            signatures = [signature.trimmingCharacters(in: .whitespacesAndNewlines)]
        } else {
            signatures = []
        }
        
        for sig in signatures {
            if isMtReference(sig) {
                options.append(sig)
                continue
            }
            let normalizedSig = MeterUtils.normalizedMeter(sig)
            let matched = files.filter { filename in
                let name = stem(filename)
                let normalizedName = MeterUtils.normalizedMeter(name)
                return normalizedName == normalizedSig || normalizedName.hasPrefix("\(normalizedSig)_")
            }
            if matched.isEmpty {
                options.append(sig)
            } else {
                options.append(contentsOf: matched.map { stem($0) })
            }
        }
        
        if options.isEmpty {
            options.append("\(hymn.number)")
        }
        return unique(options)
    }
    
    static func isMidiMigrated(hymn: Hymn, option: String, files: [String]? = nil) -> Bool {
        isMidiMigrated(hymn: hymn, option: option, files: files ?? currentConfig.midiFileNames, config: currentConfig)
    }
    
    // MARK: - Private
    
    private static func defaultOption(for hymn: Hymn) -> String {
        if hymn.type == "keerthane" { return "\(hymn.number)" }
        let signature = hymn.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        if signature.contains("/") {
            return signature.split(separator: "/").first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "\(hymn.number)"
        }
        return signature.isEmpty ? "\(hymn.number)" : signature
    }
    
    private static func isMtReference(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.contains("m.t.") || lower.contains("mang.t.b.") || lower.hasPrefix("mt")
    }
    
    /// Android parity: keep digits and lowercase `b/c/d/e` only (e.g. `50b`).
    /// Do **not** lowercase — otherwise `Mang.T.B.50` wrongly becomes `B50` / `b50`.
    private static func mangaloreTuneToken(from source: String, fallbackNumber: Int) -> String {
        let token = String(source.filter { $0.isNumber || $0 == "b" || $0 == "c" || $0 == "d" || $0 == "e" })
        return token.isEmpty ? "\(fallbackNumber)" : token
    }
    
    private static func looksLikeSongSpecificStem(_ option: String, hymnNumber: Int) -> Bool {
        let lower = option.lowercased()
        let n = "\(hymnNumber)"
        return lower == "hymn_\(n)"
            || lower == n
            || lower.hasPrefix("hymn_\(n)_")
            || lower.hasPrefix("\(n)_")
    }
    
    private static func isMidiMigrated(
        hymn: Hymn,
        option: String,
        files: [String],
        config: AudioConfig
    ) -> Bool {
        let disable = config.disableOgg
        
        if hymn.type == "keerthane" {
            return config.midiKeerthanes.contains(hymn.number)
                || disable == "keerthane"
                || disable == "both"
        }
        
        if hymn.type == "mt" || isMtReference(option) {
            return true
        }
        
        if disable == "hymns" || disable == "both" {
            return true
        }
        
        let baseMeter = option.contains("_") ? String(option.split(separator: "_").first ?? Substring(option)) : option
        let normalized = MeterUtils.normalizedMeter(baseMeter)
        
        let hasMatchingFiles = files.contains { filename in
            let nameWithoutExt = stem(filename)
            let normalizedName = MeterUtils.normalizedMeter(nameWithoutExt)
            return nameWithoutExt.caseInsensitiveCompare(option) == .orderedSame
                || normalizedName == normalized
                || normalizedName.hasPrefix("\(normalized)_")
                || nameWithoutExt.lowercased().hasPrefix("hymn_\(hymn.number)")
                || nameWithoutExt.lowercased().hasPrefix("\(hymn.number)_")
        }
        
        return hasMatchingFiles
            || config.midiHymns.contains(normalized)
            || config.midiHymns.contains(MeterUtils.normalizedMeter(option))
            || config.midiHymns.contains("\(hymn.number)")
    }
    
    private static func stem(_ filename: String) -> String {
        filename.lowercased().hasSuffix(".mid") ? String(filename.dropLast(4)) : filename
    }
    
    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let key = value.lowercased()
            if seen.insert(key).inserted {
                result.append(value)
            }
        }
        return result
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
