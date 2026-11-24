import Foundation

/// Which lyrics a presentation uses. Ported from the Android app's `LyricsLanguageMode`.
enum LyricsLanguageMode: String, CaseIterable, Identifiable {
    case kannada
    case english
    case bilingual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kannada: return "ಕನ್ನಡ"
        case .english: return "English"
        case .bilingual: return "Bilingual"
        }
    }
}

struct PresentationSlide: Equatable {
    let group: String
    let content: String
}

/// Turns a song into slides for FreeShow (church presentation software): the same slide splitting,
/// Quick Lyrics text and `.project` file contents as the Android app's `FreeShowFormatter`.
enum FreeShowFormatter {
    private static let endMarker = try! NSRegularExpression(
        pattern: #"^\s*(\.\.\.end\.\.\.|--end--|\.\.\.end|--end|\*\*\*|---|___)\s*$"#,
        options: [.caseInsensitive]
    )
    private static let numberedStanza = try! NSRegularExpression(pattern: #"^\s*(\d+)[\.\)]+\s*"#)
    private static let blankLineGap = try! NSRegularExpression(pattern: #"\n\s*\n+"#)

    private static let credit = "CSI Hymns Book App"
    private static let defaultLogoName = "app_icon.png"

    // MARK: - Slides

    /// Strips trailing end markers and surrounding blank space.
    static func cleanLyrics(_ rawLyrics: String) -> String {
        rawLyrics
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return endMarker.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) == nil
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Splits cleaned lyrics at blank lines into stanzas.
    static func splitIntoParagraphs(_ cleanedLyrics: String) -> [String] {
        let separator = "\u{0}"
        let marked = blankLineGap.stringByReplacingMatches(
            in: cleanedLyrics,
            range: NSRange(cleanedLyrics.startIndex..., in: cleanedLyrics),
            withTemplate: separator
        )
        return marked
            .components(separatedBy: separator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func stanzaNumber(of paragraph: String) -> Int? {
        let firstLine = paragraph.components(separatedBy: "\n").first ?? ""
        guard let match = numberedStanza.firstMatch(in: firstLine, range: NSRange(firstLine.startIndex..., in: firstLine)),
              let range = Range(match.range(at: 1), in: firstLine) else { return nil }
        return Int(firstLine[range])
    }

    /// Splits a song into slides labelled Chorus, Verse 1, Verse 2 and so on.
    static func parseSlides(
        number: Int,
        title: String,
        isKeerthane: Bool,
        kannadaLyrics: String?,
        englishLyrics: String,
        mode: LyricsLanguageMode = .kannada
    ) -> [PresentationSlide] {
        let kannadaClean = kannadaLyrics.map { cleanLyrics($0) } ?? ""
        let englishClean = cleanLyrics(englishLyrics)
        let kannadaParagraphs = kannadaClean.isEmpty ? [] : splitIntoParagraphs(kannadaClean)
        let englishParagraphs = englishClean.isEmpty ? [] : splitIntoParagraphs(englishClean)

        let selected: [String]
        let secondary: [String]?
        switch mode {
        case .kannada:
            selected = kannadaParagraphs.isEmpty ? englishParagraphs : kannadaParagraphs
            secondary = nil
        case .english:
            selected = englishParagraphs.isEmpty ? kannadaParagraphs : englishParagraphs
            secondary = nil
        case .bilingual:
            selected = kannadaParagraphs.isEmpty ? englishParagraphs : kannadaParagraphs
            secondary = kannadaParagraphs.isEmpty ? nil : englishParagraphs
        }

        return isKeerthane
            ? keerthaneSlides(selected: selected, secondary: secondary)
            : hymnSlides(selected: selected, secondary: secondary)
    }

    private static func keerthaneSlides(selected: [String], secondary: [String]?) -> [PresentationSlide] {
        let firstNumbered = selected.firstIndex { stanzaNumber(of: $0) != nil }

        let chorus: [String]
        let verses: [String]
        if let index = firstNumbered, index > 0 {
            chorus = Array(selected.prefix(index))
            verses = Array(selected.dropFirst(index))
        } else if firstNumbered == 0 {
            chorus = []
            verses = selected
        } else if selected.count > 1 {
            // No numbered stanzas: the first paragraph is the chorus, the rest are verses.
            chorus = [selected[0]]
            verses = Array(selected.dropFirst())
        } else {
            chorus = selected
            verses = []
        }

        var slides: [PresentationSlide] = []
        if !chorus.isEmpty {
            let chorusText = chorus.joined(separator: "\n\n")
            if let secondary {
                let secondaryChorus = secondary.prefix(max(firstNumbered ?? 1, 1)).joined(separator: "\n\n")
                slides.append(PresentationSlide(group: "Chorus", content: combineBilingual(chorusText, secondaryChorus)))
            } else {
                slides.append(PresentationSlide(group: "Chorus", content: chorusText))
            }
        }

        // The secondary (English) list has the same layout as the primary one, so verse `index` sits
        // after the chorus paragraphs that came before the first numbered stanza.
        let secondaryVerseOffset = chorus.count
        for (index, stanza) in verses.enumerated() {
            let verseNumber = stanzaNumber(of: stanza) ?? (index + 1)
            let secondaryIndex = secondaryVerseOffset + index
            let content: String
            if let secondary, secondaryIndex < secondary.count {
                content = combineBilingual(stanza, secondary[secondaryIndex])
            } else {
                content = stanza
            }
            slides.append(PresentationSlide(group: "Verse \(verseNumber)", content: content))
        }
        return slides
    }

    private static func hymnSlides(selected: [String], secondary: [String]?) -> [PresentationSlide] {
        selected.enumerated().map { index, stanza in
            let firstLine = stanza.components(separatedBy: "\n").first ?? ""
            let isChorus = ["chorus", "refrain", "ಪಲ್ಲವಿ"].contains { firstLine.range(of: $0, options: .caseInsensitive) != nil }
            let group = isChorus ? "Chorus" : "Verse \(stanzaNumber(of: stanza) ?? (index + 1))"
            let content: String
            if let secondary, index < secondary.count {
                content = combineBilingual(stanza, secondary[index])
            } else {
                content = stanza
            }
            return PresentationSlide(group: group, content: content)
        }
    }

    private static func combineBilingual(_ primary: String, _ secondary: String) -> String {
        "\(primary.trimmingCharacters(in: .whitespacesAndNewlines))\n\n—\n\(secondary.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    // MARK: - Quick Lyrics text

    /// FreeShow "Quick Lyrics" text (paste with Cmd/Ctrl + Alt + I).
    static func formatQuickLyricsText(number: Int, title: String, isKeerthane: Bool, slides: [PresentationSlide]) -> String {
        let label = isKeerthane ? "CSI Keerthane \(number)" : "CSI Hymn \(number)"
        var lines = [
            "Title=\(label) - \(title)",
            "Author=\(credit)",
            "Copyright=By \(credit)",
            "Number=\(number)",
            "",
        ]
        for slide in slides {
            lines.append("[\(slide.group)]")
            lines.append(slide.content.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - FreeShow show and project data

    private static func textItem(_ value: String, style: String, align: String) -> [String: Any] {
        ["align": align, "text": [["value": value, "style": style]]]
    }

    private static func lyricsItem(for slide: PresentationSlide) -> [String: Any] {
        let lines = slide.content.components(separatedBy: "\n").map { line -> [String: Any] in
            ["align": "text-align: center;", "text": [["value": line, "style": "font-size: 60px;"]]]
        }
        return ["style": "top: 60px; left: 80px; width: 1760px; height: 860px;", "align": "", "lines": lines]
    }

    private static func creditItems(includeLogo: Bool, logoSource: String) -> [[String: Any]] {
        let creditStyle = "font-size: 34px; color: rgb(255 255 255 / 0.65); white-space: nowrap;"
        guard includeLogo else {
            return [[
                "style": "top: 930px; left: 80px; width: 1760px; height: 70px; white-space: nowrap; overflow: visible;",
                "align": "",
                "lines": [textItem("By \(credit)", style: creditStyle, align: "text-align: right; white-space: nowrap;")],
                "decoration": true,
            ]]
        }
        return [
            [
                "style": "top: 930px; left: 1195px; width: 65px; height: 70px; white-space: nowrap; overflow: visible;",
                "align": "",
                "lines": [textItem("By", style: creditStyle, align: "text-align: right; white-space: nowrap;")],
                "decoration": true,
            ],
            [
                "type": "media",
                "style": "top: 943px; left: 1272px; width: 44px; height: 44px; border-radius: 10px;",
                "src": logoSource,
                "fit": "contain",
                "decoration": true,
            ],
            [
                "style": "top: 930px; left: 1330px; width: 520px; height: 70px; white-space: nowrap; overflow: visible;",
                "align": "",
                "lines": [textItem(credit, style: creditStyle, align: "text-align: left; white-space: nowrap;")],
                "decoration": true,
            ],
        ]
    }

    /// One FreeShow show: its id and its data. Keys with no value are left out, as the Android export does.
    static func createShow(
        number: Int,
        title: String,
        isKeerthane: Bool,
        slides: [PresentationSlide],
        includeLogoMedia: Bool = false,
        logoSource: String? = nil
    ) -> (id: String, data: [String: Any]) {
        let prefix = isKeerthane ? "Keerthane" : "Hymn"
        let showId = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(11))
        let layoutId = "default"
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        var slideMap: [String: Any] = [:]
        var layoutSlides: [[String: String]] = []
        for (index, slide) in slides.enumerated() {
            let slideId = "slide_\(index)_" + String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(6))
            var slideObject: [String: Any] = [
                "group": slide.group,
                "settings": [String: Any](),
                "notes": "",
                "items": [lyricsItem(for: slide)] + creditItems(includeLogo: includeLogoMedia, logoSource: logoSource ?? defaultLogoName),
            ]
            if slide.group.lowercased().hasPrefix("chorus") { slideObject["color"] = "#e0a300" }
            slideMap[slideId] = slideObject
            layoutSlides.append(["id": slideId])
        }

        let data: [String: Any] = [
            "name": "\(prefix) \(number) - \(title)",
            "category": isKeerthane ? "keerthanes" : "hymns",
            "settings": ["activeLayout": layoutId],
            "timestamps": ["created": now, "modified": now],
            "quickAccess": [String: Any](),
            "meta": ["title": title, "author": credit, "copyright": "By \(credit)", "number": String(number)],
            "slides": slideMap,
            "layouts": [layoutId: ["name": "Default", "notes": "", "slides": layoutSlides]],
            "media": [String: Any](),
        ]
        return (showId, data)
    }

    /// A show ready to be sent straight to FreeShow over the network, with the logo embedded as a data URI.
    static func showForBeam(
        number: Int,
        title: String,
        isKeerthane: Bool,
        slides: [PresentationSlide],
        logoDataURI: String?
    ) -> (id: String, json: String)? {
        let show = createShow(
            number: number,
            title: title,
            isKeerthane: isKeerthane,
            slides: slides,
            includeLogoMedia: true,
            logoSource: logoDataURI
        )
        guard let json = jsonString(show.data, pretty: false) else { return nil }
        return (show.id, json)
    }

    /// The contents of a FreeShow `.project` file.
    static func projectData(number: Int, title: String, isKeerthane: Bool, slides: [PresentationSlide]) -> [String: Any] {
        let show = createShow(number: number, title: title, isKeerthane: isKeerthane, slides: slides, includeLogoMedia: true)
        let prefix = isKeerthane ? "Keerthane" : "Hymn"
        return [
            "project": [
                "name": "\(prefix) \(number) - \(title)",
                "created": Int64(Date().timeIntervalSince1970 * 1000),
                "shows": [["id": show.id]],
            ],
            "parentFolder": "",
            "shows": [show.id: show.data],
            "files": [defaultLogoName],
        ]
    }

    /// A `.project` file (a ZIP of data.json, project.json and the logo) for FreeShow's "Import project".
    static func projectFile(
        number: Int,
        title: String,
        isKeerthane: Bool,
        slides: [PresentationSlide],
        logoPNG: Data?
    ) -> (fileName: String, data: Data)? {
        guard let json = jsonString(projectData(number: number, title: title, isKeerthane: isKeerthane, slides: slides), pretty: true),
              let jsonData = json.data(using: .utf8) else { return nil }
        var files: [(name: String, data: Data)] = [("data.json", jsonData), ("project.json", jsonData)]
        if let logoPNG { files.append((defaultLogoName, logoPNG)) }

        let prefix = isKeerthane ? "Keerthane" : "Hymn"
        let safeTitle = String(title.unicodeScalars.map { scalar -> Character in
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
            return allowed.contains(scalar) ? Character(scalar) : "_"
        }.prefix(30))
        return ("\(prefix)_\(number)_\(safeTitle).project", SimpleZipArchive.make(files: files))
    }

    static func jsonString(_ object: Any, pretty: Bool) -> String? {
        guard JSONSerialization.isValidJSONObject(object) else { return nil }
        let options: JSONSerialization.WritingOptions = pretty
            ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            : [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: options) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
