import Foundation

/// Disk cache for MIDI/OGG bytes (Android `MidiFileCache` parity).
public final class MidiFileCache: @unchecked Sendable {
    public static let shared = MidiFileCache()
    
    private let cacheDir: URL
    private let defaults = UserDefaults.standard
    private let lock = NSLock()
    
    private static let ttl: TimeInterval = 24 * 60 * 60
    private static let maxBytes: Int64 = 80 * 1024 * 1024
    private static let prefsPrefix = "midi_file_cache_meta_"
    
    public struct Entry: Sendable {
        public let bytes: Data
        public let fromDisk: Bool
    }
    
    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = caches.appendingPathComponent("midi_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    public static func configFingerprint(
        githubToken: String?,
        midiHymnsRanges: String?,
        midiKeerthanesRanges: String?,
        disableOggFallback: String?,
        audioBackupUrl: String?
    ) -> String {
        let raw = [
            githubToken ?? "",
            midiHymnsRanges ?? "",
            midiKeerthanesRanges ?? "",
            disableOggFallback ?? "",
            audioBackupUrl ?? ""
        ].joined(separator: "|")
        return sha256(raw).prefix(16).description
    }
    
    public static func currentFingerprint() -> String {
        let d = UserDefaults.standard
        return configFingerprint(
            githubToken: d.string(forKey: "github_midi_token_cached"),
            midiHymnsRanges: d.string(forKey: "midi_hymns_ranges_cached"),
            midiKeerthanesRanges: d.string(forKey: "midi_keerthanes_ranges_cached"),
            disableOggFallback: d.string(forKey: "disable_ogg_fallback_cached"),
            audioBackupUrl: d.string(forKey: "audio_backup_url_cached")
        )
    }
    
    public func getIfFresh(url: String, fingerprint: String) -> Entry? {
        lock.lock(); defer { lock.unlock() }
        let key = Self.cacheKey(url)
        let file = cacheDir.appendingPathComponent("\(key).bin")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        
        let storedFingerprint = defaults.string(forKey: metaKey(key, "fp"))
        let cachedAt = defaults.double(forKey: metaKey(key, "at"))
        let age = Date().timeIntervalSince1970 - cachedAt
        let mismatch = storedFingerprint != nil && storedFingerprint != fingerprint
        let expired = cachedAt > 0 && age > Self.ttl
        
        if mismatch || expired {
            deleteEntry(key: key)
            return nil
        }
        
        guard let bytes = try? Data(contentsOf: file), !bytes.isEmpty else {
            deleteEntry(key: key)
            return nil
        }
        return Entry(bytes: bytes, fromDisk: true)
    }
    
    public func put(url: String, bytes: Data, fingerprint: String) {
        guard !bytes.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        let key = Self.cacheKey(url)
        let file = cacheDir.appendingPathComponent("\(key).bin")
        do {
            try bytes.write(to: file, options: .atomic)
            defaults.set(Date().timeIntervalSince1970, forKey: metaKey(key, "at"))
            defaults.set(url, forKey: metaKey(key, "url"))
            defaults.set(fingerprint, forKey: metaKey(key, "fp"))
            pruneIfNeeded()
        } catch {
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    public func invalidateAll() {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.prefsPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
    
    private func deleteEntry(key: String) {
        let file = cacheDir.appendingPathComponent("\(key).bin")
        try? FileManager.default.removeItem(at: file)
        defaults.removeObject(forKey: metaKey(key, "at"))
        defaults.removeObject(forKey: metaKey(key, "url"))
        defaults.removeObject(forKey: metaKey(key, "fp"))
    }
    
    private func pruneIfNeeded() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ))?.filter { $0.pathExtension == "bin" } ?? []
        
        var total = files.reduce(Int64(0)) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            return sum + size
        }
        guard total > Self.maxBytes else { return }
        
        let ordered = files.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a < b
        }
        
        for file in ordered {
            if total <= Self.maxBytes { break }
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            total -= size
            deleteEntry(key: file.deletingPathExtension().lastPathComponent)
        }
    }
    
    private func metaKey(_ key: String, _ field: String) -> String {
        "\(Self.prefsPrefix)\(key)_\(field)"
    }
    
    private static func cacheKey(_ url: String) -> String {
        String(sha256(url).prefix(40))
    }
    
    private static func sha256(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return input }
        // Lightweight FNV-1a style hash is fine for cache keys when CryptoKit isn't required;
        // use a stable hex digest via CommonCrypto-free fold for portability.
        var hash: UInt64 = 14695981039346656037
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        // Mix in a second pass for longer keys
        var hash2: UInt64 = 0xcbf29ce484222325
        for byte in data.reversed() {
            hash2 ^= UInt64(byte)
            hash2 = hash2 &* 1099511628211
        }
        return String(format: "%016llx%016llx", hash, hash2)
    }
}
