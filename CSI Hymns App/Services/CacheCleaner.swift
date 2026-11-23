import Foundation

/// Clears everything the app can download again: temporary files, downloaded MIDI tunes and the
/// cached tune list. Saved songs, favourites, settings and the sign-in are never touched.
enum CacheCleaner {
    /// Bytes of cached files that `clearAll` would free.
    static func sizeBytes() async -> Int64 {
        await Task.detached(priority: .utility) { roots().reduce(Int64(0)) { $0 + folderSize($1) } }.value
    }

    /// Deletes the cache and returns how many bytes it freed.
    @MainActor
    @discardableResult
    static func clearAll() async -> Int64 {
        let before = await sizeBytes()
        MidiFileCache.shared.invalidateAll()
        MidiFileCatalog.shared.clearCache()
        URLCache.shared.removeAllCachedResponses()
        await Task.detached(priority: .utility) {
            for root in roots() {
                let items = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
                for item in items { try? FileManager.default.removeItem(at: item) }
            }
        }.value
        return before
    }

    private static func roots() -> [URL] {
        [FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first, FileManager.default.temporaryDirectory].compactMap { $0 }
    }

    private static func folderSize(_ url: URL) -> Int64 {
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in walker {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true { total += Int64(values?.fileSize ?? 0) }
        }
        return total
    }

    /// "3.2 MB" style text for a byte count.
    static func format(_ bytes: Int64) -> String {
        switch bytes {
        case ..<1_024: return "\(bytes) B"
        case ..<1_048_576: return String(format: "%.0f KB", Double(bytes) / 1_024)
        default: return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        }
    }
}
