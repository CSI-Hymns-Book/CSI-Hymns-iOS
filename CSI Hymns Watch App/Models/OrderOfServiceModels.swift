import Foundation

/// Core Page structure for liturgies.
public struct OrderPage: Codable, Identifiable, Hashable, Sendable {
    public var id: String { "\(type)-\(pageNo)" }
    public var pageNo: Int
    public var title: String?
    public var content: String
    public var type: String // 'regular' or 'festival'
    
    enum CodingKeys: String, CodingKey {
        case pageNo = "page_no"
        case title
        case content
        case type
    }
    
    public init(pageNo: Int, title: String?, content: String, type: String) {
        self.pageNo = pageNo
        self.title = title
        self.content = content
        self.type = type
    }
}

/// Table-of-contents entry from order-of-service JSON `index`.
public struct OrderIndexEntry: Hashable, Identifiable, Sendable {
    public var id: String { "\(pageNo)-\(title)" }
    public let pageNo: Int
    public let title: String
    
    public init(pageNo: Int, title: String) {
        self.pageNo = pageNo
        self.title = title
    }
}

/// TOC section with its pages.
public struct OrderPageSection: Hashable, Identifiable, Sendable {
    public var id: String { "\(startPageNo)-\(title)" }
    public let title: String
    public let startPageNo: Int
    public let pages: [OrderPage]
    
    public init(title: String, startPageNo: Int, pages: [OrderPage]) {
        self.title = title
        self.startPageNo = startPageNo
        self.pages = pages
    }
}
