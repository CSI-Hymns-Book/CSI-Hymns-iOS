import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif

/// Fast offline data loader for Apple Watch, indexing hymns, keerthanes, and MT hymns with O(1) lookups.
@MainActor
public final class WatchDataLoader: ObservableObject {
    public static let shared = WatchDataLoader()
    
    @Published public private(set) var hymns: [Hymn] = []
    @Published public private(set) var keerthanes: [Hymn] = []
    @Published public private(set) var mtHymns: [Hymn] = []
    @Published public private(set) var isLoaded: Bool = false
    
    // O(1) Fast lookup tables by number
    private var hymnsByNumber: [Int: Hymn] = [:]
    private var keerthanesByNumber: [Int: Hymn] = [:]
    private var mtHymnsByNumber: [Int: Hymn] = [:]
    
    private init() {
        loadAllData()
    }
    
    public func loadAllData() {
        loadHymns()
        loadKeerthanes()
        loadMtHymns()
        isLoaded = true
    }
    
    private func loadDataAsset(name: String) -> Data? {
        #if canImport(UIKit)
        if let asset = NSDataAsset(name: name) {
            return asset.data
        }
        #endif
        if let url = Bundle.main.url(forResource: name, withExtension: "json") {
            return try? Data(contentsOf: url)
        }
        return nil
    }
    
    private func loadHymns() {
        guard let data = loadDataAsset(name: "hymns_data") else {
            print("WatchDataLoader: Failed to find hymns_data")
            return
        }
        do {
            let items = try JSONDecoder().decode([Hymn].self, from: data)
            let sorted = items.map {
                var h = $0
                h.type = "hymn"
                return h
            }.sorted { $0.number < $1.number }
            self.hymns = sorted
            
            var dict: [Int: Hymn] = [:]
            dict.reserveCapacity(sorted.count)
            for h in sorted { dict[h.number] = h }
            self.hymnsByNumber = dict
        } catch {
            print("WatchDataLoader: Error decoding hymns: \(error)")
        }
    }
    
    private func loadKeerthanes() {
        guard let data = loadDataAsset(name: "keerthane_data") else {
            print("WatchDataLoader: Failed to find keerthane_data")
            return
        }
        do {
            let items = try JSONDecoder().decode([Hymn].self, from: data)
            let sorted = items.map {
                var h = $0
                h.type = "keerthane"
                return h
            }.sorted { $0.number < $1.number }
            self.keerthanes = sorted
            
            var dict: [Int: Hymn] = [:]
            dict.reserveCapacity(sorted.count)
            for h in sorted { dict[h.number] = h }
            self.keerthanesByNumber = dict
        } catch {
            print("WatchDataLoader: Error decoding keerthanes: \(error)")
        }
    }
    
    private func loadMtHymns() {
        guard let data = loadDataAsset(name: "mangalore_hymns_data") else {
            print("WatchDataLoader: Failed to find mangalore_hymns_data")
            return
        }
        do {
            let items = try JSONDecoder().decode([Hymn].self, from: data)
            let sorted = items.map {
                var h = $0
                h.type = "mt"
                return h
            }.sorted { $0.number < $1.number }
            self.mtHymns = sorted
            
            var dict: [Int: Hymn] = [:]
            dict.reserveCapacity(sorted.count)
            for h in sorted { dict[h.number] = h }
            self.mtHymnsByNumber = dict
        } catch {
            print("WatchDataLoader: Error decoding MT hymns: \(error)")
        }
    }
    
    // MARK: - Direct Fast Access
    
    public func songs(for type: String) -> [Hymn] {
        switch type {
        case "keerthane": return keerthanes
        case "mt": return mtHymns
        default: return hymns
        }
    }
    
    public func song(type: String, number: Int) -> Hymn? {
        switch type {
        case "keerthane":
            return keerthanesByNumber[number]
        case "mt":
            return mtHymnsByNumber[number]
        default:
            return hymnsByNumber[number]
        }
    }
    
    public func search(query: String, in type: String) -> [Hymn] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return songs(for: type)
        }
        
        if let num = Int(trimmed) {
            if let found = song(type: type, number: num) {
                return [found]
            }
            return []
        }
        
        let source = songs(for: type)
        let lower = trimmed.lowercased()
        return source.filter {
            $0.title.localizedCaseInsensitiveContains(lower) ||
            $0.lyricsKannada.localizedCaseInsensitiveContains(lower) ||
            $0.lyricsEnglish.localizedCaseInsensitiveContains(lower)
        }
    }
}
