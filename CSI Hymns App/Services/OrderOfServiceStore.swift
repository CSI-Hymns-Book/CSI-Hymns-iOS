import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Table-of-contents entry from order-of-service JSON `index` (Android `OrderIndexEntry` parity).
public struct OrderIndexEntry: Hashable, Identifiable, Sendable {
    public var id: String { "\(pageNo)-\(title)" }
    public let pageNo: Int
    public let title: String
    
    public init(pageNo: Int, title: String) {
        self.pageNo = pageNo
        self.title = title
    }
}

/// Parsed order-of-service document: pages + optional TOC index.
public struct OrderOfServiceDocument: Sendable {
    public let pages: [OrderPage]
    public let index: [OrderIndexEntry]
    public let rawData: Data
    
    public func pages(ofType type: String) -> [OrderPage] {
        pages.filter { $0.type == type }.sorted { $0.pageNo < $1.pageNo }
    }
    
    public var regularIndex: [OrderIndexEntry] {
        index.sorted { $0.pageNo < $1.pageNo }
    }
}

/// Local + remote order-of-service JSON handling (Android `OrderOfServiceRepository` + `ContentLocalStore` parity).
public enum OrderOfServiceStore {
    public static let cacheKey = "orderOfServiceData"
    public static let legacyCacheKey = "csi_cached_liturgies_json"
    public static let lastUpdateKey = "lastOrderOfServiceUpdate"
    public static let remoteURL = URL(string: "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/refs/heads/main/order-of-service_data.json")!
    public static let refreshedNotification = Notification.Name("csi_liturgies_refreshed")
    
    private static let threeDaysMs: Double = 3 * 24 * 60 * 60 * 1000
    
    // MARK: - Load
    
    /// Loads the best available document: UserDefaults cache → legacy cache → bundled asset → offline seed string.
    public static func loadDocument() -> OrderOfServiceDocument? {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let doc = try? parseDocument(from: data) {
            let merged = ensureIndexMerged(doc)
            if merged.rawData != data {
                UserDefaults.standard.set(merged.rawData, forKey: cacheKey)
            }
            return merged
        }
        
        if let data = UserDefaults.standard.data(forKey: legacyCacheKey),
           let doc = try? parseDocument(from: data) {
            let merged = ensureIndexMerged(doc)
            UserDefaults.standard.set(merged.rawData, forKey: cacheKey)
            return merged
        }
        
        if let bundled = bundledAssetData(),
           let doc = try? parseDocument(from: bundled) {
            UserDefaults.standard.set(doc.rawData, forKey: cacheKey)
            return doc
        }
        
        if let seed = LiturgyOfflineSeeds.fallbackJSON.data(using: .utf8),
           let doc = try? parseDocument(from: seed) {
            let merged = ensureIndexMerged(doc)
            UserDefaults.standard.set(merged.rawData, forKey: cacheKey)
            return merged
        }
        
        return nil
    }
    
    public static func loadPages(type: String) -> (pages: [OrderPage], index: [OrderIndexEntry]) {
        guard let doc = loadDocument() else { return ([], []) }
        let pages = doc.pages(ofType: type)
        let index = type == "regular" ? doc.regularIndex : []
        return (pages, index)
    }
    
    // MARK: - Sync
    
    /// Seeds cache on first launch and refreshes from network when the 3-day window elapsed.
    public static func ensureSeededAndRefreshIfStale() async {
        if UserDefaults.standard.data(forKey: cacheKey) == nil {
            _ = loadDocument()
        } else {
            // Still merge index if an older cache is missing TOC.
            if let data = UserDefaults.standard.data(forKey: cacheKey),
               let doc = try? parseDocument(from: data) {
                let merged = ensureIndexMerged(doc)
                if merged.rawData != data {
                    UserDefaults.standard.set(merged.rawData, forKey: cacheKey)
                }
            }
        }
        
        let last = UserDefaults.standard.double(forKey: lastUpdateKey)
        let now = Date().timeIntervalSince1970 * 1000
        guard now - last >= threeDaysMs else { return }
        _ = await refreshFromNetwork(force: false)
    }
    
    @discardableResult
    public static func refreshFromNetwork(force: Bool = true) async -> Bool {
        do {
            var request = URLRequest(url: remoteURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            var doc = try parseDocument(from: data)
            doc = ensureIndexMerged(doc)
            // Prefer remote index when present; ensureIndexMerged only fills missing.
            UserDefaults.standard.set(doc.rawData, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970 * 1000, forKey: lastUpdateKey)
            NotificationCenter.default.post(name: refreshedNotification, object: nil)
            return true
        } catch {
            print("OrderOfServiceStore: refresh failed: \(error)")
            return false
        }
    }
    
    // MARK: - Parse (Android parity)
    
    public static func parseDocument(from data: Data) throws -> OrderOfServiceDocument {
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        var pages: [OrderPage] = []
        var index: [OrderIndexEntry] = []
        
        if let list = jsonObject as? [[String: Any]] {
            for item in list {
                if let page = parsePageItem(item, forcedType: nil) {
                    pages.append(page)
                }
            }
        } else if let dict = jsonObject as? [String: Any] {
            if let indexArr = dict["index"] as? [[String: Any]] {
                index = parseIndexArray(indexArr)
            }
            
            if dict.keys.contains("regular") || dict.keys.contains("festival") {
                for key in ["regular", "festival"] {
                    if let block = dict[key] as? [[String: Any]] {
                        for item in block {
                            if let page = parsePageItem(item, forcedType: key) {
                                pages.append(page)
                            }
                        }
                    }
                }
            } else if index.isEmpty {
                // Legacy map of pageNo → content string
                for (k, v) in dict where k != "index" {
                    let pageNo = Int(k) ?? 0
                    let content = String(describing: v)
                    pages.append(OrderPage(pageNo: pageNo, title: nil, content: content, type: "regular"))
                }
            }
        } else {
            throw NSError(domain: "LiturgyParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])
        }
        
        pages.sort { $0.pageNo < $1.pageNo }
        index.sort { $0.pageNo < $1.pageNo }
        return OrderOfServiceDocument(pages: pages, index: index, rawData: data)
    }
    
    /// Updates one page inside the grouped JSON while preserving `index` / other groups (Android `savePage`).
    public static func applyPageUpdate(_ updated: OrderPage, to rawData: Data) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: rawData) as? [String: Any] else {
            throw NSError(domain: "LiturgyParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Expected grouped order-of-service object"])
        }
        
        let groupKey = updated.type
        guard var arr = root[groupKey] as? [[String: Any]] else {
            throw NSError(domain: "LiturgyParser", code: 404, userInfo: [NSLocalizedDescriptionKey: "Group \(groupKey) missing"])
        }
        
        var found = false
        for i in arr.indices {
            let pageNo = intValue(arr[i]["page_no"]) ?? intValue(arr[i]["pageNo"])
            if pageNo == updated.pageNo {
                arr[i]["content"] = updated.content
                if let title = updated.title {
                    arr[i]["title"] = title
                } else {
                    arr[i]["title"] = NSNull()
                }
                // Normalize key spelling going forward
                arr[i]["page_no"] = updated.pageNo
                arr[i].removeValue(forKey: "pageNo")
                found = true
                break
            }
        }
        guard found else {
            throw NSError(domain: "LiturgyParser", code: 404, userInfo: [NSLocalizedDescriptionKey: "Liturgy page not found"])
        }
        
        root[groupKey] = arr
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }
    
    // MARK: - Private
    
    private static func parseIndexArray(_ arr: [[String: Any]]) -> [OrderIndexEntry] {
        var entries: [OrderIndexEntry] = []
        for item in arr {
            guard let pageNo = intValue(item["page_no"]) ?? intValue(item["pageNo"]) else { continue }
            let title = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !title.isEmpty {
                entries.append(OrderIndexEntry(pageNo: pageNo, title: title))
            }
        }
        return entries
    }
    
    private static func parsePageItem(_ item: [String: Any], forcedType: String?) -> OrderPage? {
        guard let pageNo = intValue(item["page_no"]) ?? intValue(item["pageNo"]) else { return nil }
        let title: String?
        if item["title"] is NSNull {
            title = nil
        } else {
            title = item["title"] as? String
        }
        let content = (item["content"] as? String) ?? ""
        let type = forcedType ?? ((item["type"] as? String) ?? "regular")
        return OrderPage(pageNo: pageNo, title: title, content: content, type: type)
    }
    
    private static func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let n = any as? NSNumber { return n.intValue }
        if let s = any as? String { return Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }
    
    private static func bundledAssetData() -> Data? {
        #if canImport(UIKit)
        if let asset = NSDataAsset(name: "order_of_service_data") {
            return asset.data
        }
        #endif
        if let url = Bundle.main.url(forResource: "order_of_service_data", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }
    
    /// If cached JSON has no `index`, merge TOC from the bundled Android asset (Android `ensureOrderIndexFromAsset`).
    private static func ensureIndexMerged(_ doc: OrderOfServiceDocument) -> OrderOfServiceDocument {
        if !doc.index.isEmpty { return doc }
        guard let bundled = bundledAssetData(),
              let bundledDoc = try? parseDocument(from: bundled),
              !bundledDoc.index.isEmpty,
              var root = try? JSONSerialization.jsonObject(with: doc.rawData) as? [String: Any] else {
            return doc
        }
        
        let indexArray: [[String: Any]] = bundledDoc.index.map {
            ["page_no": $0.pageNo, "title": $0.title]
        }
        root["index"] = indexArray
        guard let mergedData = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
              let merged = try? parseDocument(from: mergedData) else {
            return doc
        }
        return merged
    }
}
