import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif

/// Fast offline data loader for Apple Watch, loading hymns, keerthanes, MT hymns, and liturgies.
@MainActor
public final class WatchDataLoader: ObservableObject {
    public static let shared = WatchDataLoader()
    
    @Published public private(set) var hymns: [Hymn] = []
    @Published public private(set) var keerthanes: [Hymn] = []
    @Published public private(set) var mtHymns: [Hymn] = []
    @Published public private(set) var regularLiturgies: [OrderPage] = []
    @Published public private(set) var festivalLiturgies: [OrderPage] = []
    @Published public private(set) var isLoaded: Bool = false
    
    private init() {
        loadAllData()
    }
    
    public func loadAllData() {
        loadHymns()
        loadKeerthanes()
        loadMtHymns()
        loadLiturgies()
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
            self.hymns = items.map {
                var h = $0
                h.type = "hymn"
                return h
            }.sorted { $0.number < $1.number }
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
            self.keerthanes = items.map {
                var h = $0
                h.type = "keerthane"
                return h
            }.sorted { $0.number < $1.number }
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
            self.mtHymns = items.map {
                var h = $0
                h.type = "mt"
                return h
            }.sorted { $0.number < $1.number }
        } catch {
            print("WatchDataLoader: Error decoding MT hymns: \(error)")
        }
    }
    
    private func loadLiturgies() {
        guard let data = loadDataAsset(name: "order_of_service_data") else {
            print("WatchDataLoader: Failed to find order_of_service_data")
            return
        }
        do {
            if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var pages: [OrderPage] = []
                if let pagesArr = root["pages"] as? [[String: Any]] {
                    for p in pagesArr {
                        let pageNo = p["page_no"] as? Int ?? 0
                        let title = p["title"] as? String
                        let content = p["content"] as? String ?? ""
                        let type = p["type"] as? String ?? "regular"
                        pages.append(OrderPage(pageNo: pageNo, title: title, content: content, type: type))
                    }
                }
                self.regularLiturgies = pages.filter { $0.type == "regular" }.sorted { $0.pageNo < $1.pageNo }
                self.festivalLiturgies = pages.filter { $0.type == "festival" }.sorted { $0.pageNo < $1.pageNo }
            }
        } catch {
            print("WatchDataLoader: Error decoding order of service: \(error)")
        }
    }
    
    // MARK: - Search & Lookup
    
    public func song(type: String, number: Int) -> Hymn? {
        switch type {
        case "keerthane":
            return keerthanes.first { $0.number == number }
        case "mt":
            return mtHymns.first { $0.number == number }
        default:
            return hymns.first { $0.number == number }
        }
    }
    
    public func search(query: String, in type: String) -> [Hymn] {
        let source: [Hymn]
        switch type {
        case "keerthane": source = keerthanes
        case "mt": source = mtHymns
        default: source = hymns
        }
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return source }
        
        if let num = Int(trimmed) {
            return source.filter { $0.number == num }
        }
        
        let lower = trimmed.lowercased()
        return source.filter {
            $0.title.localizedCaseInsensitiveContains(lower) ||
            $0.lyricsKannada.localizedCaseInsensitiveContains(lower) ||
            $0.lyricsEnglish.localizedCaseInsensitiveContains(lower)
        }
    }
}
