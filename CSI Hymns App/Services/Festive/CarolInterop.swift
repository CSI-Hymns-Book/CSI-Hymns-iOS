import Foundation

// Inter-app hand-off with YKC One (and carol helpers). Pure Foundation.

/// iOS cannot tell which app opened a link, so the caller names itself with `from=<bundleId>`.
/// That is only trusted if it is on this hard-coded allowlist AND has a known return scheme;
/// anything else is ignored. Nothing is exchanged beyond "open the Carols book" / "go back".
public enum CarolInterop {
    public static let hymnsBundleId = "com.reyzie.hymns"
    public static let linkScheme = "csihymns"
    public static let linkHost = "carols"

    /// Partner apps allowed to open the Carols book and be returned to (hard-coded for now).
    public static let allowedCallers: Set<String> = ["com.reyzie.hymns", "com.reyzie.oneykc"]

    /// Return scheme and display name per partner. A whitelabeled app is added here (and in
    /// the app's Info.plist `LSApplicationQueriesSchemes`).
    public static let partners: [String: (label: String, scheme: String)] = [
        "com.reyzie.oneykc": (label: "YKC One", scheme: "ykcone")
    ]

    public struct Caller: Equatable, Sendable {
        public let bundleId: String
        public let label: String
        public let returnURL: URL
    }

    /// The partner to accept a `csihymns://carols?from=...` link from, or nil to ignore it.
    public static func resolveCaller(scheme: String?, host: String?, from: String?) -> Caller? {
        guard scheme?.lowercased() == linkScheme, host?.lowercased() == linkHost else { return nil }
        guard let from = from?.trimmingCharacters(in: .whitespaces),
              from != hymnsBundleId,
              allowedCallers.contains(from),
              let partner = partners[from],
              let url = URL(string: "\(partner.scheme)://") else { return nil }
        return Caller(bundleId: from, label: partner.label, returnURL: url)
    }

    public static func resolveCaller(url: URL) -> Caller? {
        let from = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "from" })?.value
        return resolveCaller(scheme: url.scheme, host: url.host, from: from)
    }

    /// Whether the link is the Carols link at all (even from an unknown caller).
    public static func isCarolsLink(_ url: URL) -> Bool {
        url.scheme?.lowercased() == linkScheme && url.host?.lowercased() == linkHost
    }

    public static func canReturn(to caller: Caller) -> Bool {
        allowedCallers.contains(caller.bundleId) && partners[caller.bundleId]?.scheme == caller.returnURL.scheme
    }
}

// MARK: - Carol helpers

public enum CarolRecents {
    public static let defaultMax = 6
    public static func push(_ ids: [String], _ id: String, max: Int = defaultMax) -> [String] {
        Array(([id] + ids.filter { $0 != id }).prefix(max))
    }
}

public enum CarolTextScale {
    public static let min = 0.8, max = 1.8, defaultScale = 1.0
    public static func clamp(_ s: Double) -> Double { Swift.min(Swift.max(s, min), max) }
    public static func bigger(_ s: Double) -> Double { clamp(((s + 0.1) * 10).rounded() / 10) }
    public static func smaller(_ s: Double) -> Double { clamp(((s - 0.1) * 10).rounded() / 10) }
}

/// Up to two capital letters for a church avatar: "St. Paul's Church" -> "SP".
public func churchInitials(_ name: String) -> String {
    let letters = name.split(separator: " ").compactMap { word in word.first(where: { $0.isLetter }) }.prefix(2)
    return letters.isEmpty ? "✦" : String(letters).uppercased()
}

/// A stable colour slot (0..<slotCount) for a church name.
public func churchColorSlot(_ name: String, slotCount: Int) -> Int {
    var hash: UInt64 = 5381
    for byte in name.trimmingCharacters(in: .whitespaces).lowercased().utf8 { hash = hash &* 33 &+ UInt64(byte) }
    return Int(hash % UInt64(slotCount))
}

/// Splits lyrics into verses at blank lines.
public func splitStanzas(_ lyrics: String) -> [String] {
    lyrics.replacingOccurrences(of: "\r\n", with: "\n")
        .components(separatedBy: "\n\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .flatMap { block -> [String] in
            // "\n \n" style gaps (a blank line holding spaces) also separate verses.
            block.components(separatedBy: "\n \n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
}

// MARK: - Presenter paging

/// Which way a tap on the presenter moves: the left half goes back, the right half goes forward.
enum PresenterTap: Equatable, Sendable {
    case previous, next

    static func at(x: Double, width: Double) -> PresenterTap { x < width / 2 ? .previous : .next }
}

enum PresenterPaging {
    /// The page after a move, kept inside 0..<count.
    static func moved(_ page: Int, by step: Int, count: Int) -> Int { clamped(page + step, count: count) }

    /// Keeps a page number valid if the verses change while presenting.
    static func clamped(_ page: Int, count: Int) -> Int { min(max(page, 0), max(count - 1, 0)) }
}
