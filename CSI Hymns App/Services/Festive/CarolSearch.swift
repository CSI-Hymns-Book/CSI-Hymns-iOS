import Foundation

// Bilingual carol search. Typing English finds Kannada songs (and the other way round) by
// matching a rough roman spelling of the Kannada text. Pure Foundation, so it is checked in
// `scripts/festive-logic-check`.

/// Lyrics that carry an English translation after a divider.
enum CarolBilingual {
    static let divider = "\n\n---\n\nEnglish Translation:\n"

    /// Splits stored lyrics into the Kannada text and the English translation, if there is one.
    static func split(_ lyrics: String) -> (kannada: String, english: String?) {
        for separator in [divider, "\n\n---\n\nEnglish:\n", "\n\n---\n\n"] {
            let parts = lyrics.components(separatedBy: separator)
            if parts.count > 1 { return (parts[0].trimmingCharacters(in: .whitespacesAndNewlines), parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
        return (lyrics, nil)
    }

    /// The reverse of `split`: the single string a song stores.
    static func join(kannada: String, english: String) -> String {
        let k = kannada.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = english.trimmingCharacters(in: .whitespacesAndNewlines)
        return e.isEmpty ? k : "\(k)\(divider)\(e)"
    }
}

/// A rough roman spelling of Kannada text, good enough to compare with how people type it.
enum KannadaRoman {
    private static let vowels: [UInt32: String] = [
        0x0C85: "a", 0x0C86: "aa", 0x0C87: "i", 0x0C88: "ii", 0x0C89: "u", 0x0C8A: "uu", 0x0C8B: "ru",
        0x0C8E: "e", 0x0C8F: "ee", 0x0C90: "ai", 0x0C92: "o", 0x0C93: "oo", 0x0C94: "au"
    ]
    private static let signs: [UInt32: String] = [
        0x0CBE: "aa", 0x0CBF: "i", 0x0CC0: "ii", 0x0CC1: "u", 0x0CC2: "uu", 0x0CC3: "ru",
        0x0CC6: "e", 0x0CC7: "ee", 0x0CC8: "ai", 0x0CCA: "o", 0x0CCB: "oo", 0x0CCC: "au"
    ]
    private static let consonants: [UInt32: String] = [
        0x0C95: "k", 0x0C96: "kh", 0x0C97: "g", 0x0C98: "gh", 0x0C99: "ng", 0x0C9A: "ch", 0x0C9B: "chh",
        0x0C9C: "j", 0x0C9D: "jh", 0x0C9E: "ny", 0x0C9F: "t", 0x0CA0: "th", 0x0CA1: "d", 0x0CA2: "dh",
        0x0CA3: "n", 0x0CA4: "t", 0x0CA5: "th", 0x0CA6: "d", 0x0CA7: "dh", 0x0CA8: "n", 0x0CAA: "p",
        0x0CAB: "ph", 0x0CAC: "b", 0x0CAD: "bh", 0x0CAE: "m", 0x0CAF: "y", 0x0CB0: "r", 0x0CB1: "r",
        0x0CB2: "l", 0x0CB3: "l", 0x0CB5: "v", 0x0CB6: "sh", 0x0CB7: "sh", 0x0CB8: "s", 0x0CB9: "h"
    ]
    private static let virama: UInt32 = 0x0CCD, anusvara: UInt32 = 0x0C82, visarga: UInt32 = 0x0C83

    /// Kannada letters become roman letters and Kannada digits become 0-9; everything else is kept.
    static func transliterate(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var out = ""
        var i = 0
        while i < scalars.count {
            let v = scalars[i].value
            if let base = consonants[v] {
                out += base
                let next = i + 1 < scalars.count ? scalars[i + 1].value : 0
                if let sign = signs[next] { out += sign; i += 2 } else if next == virama { i += 2 } else { out += "a"; i += 1 }
                continue
            }
            if let vowel = vowels[v] { out += vowel }
            else if v == anusvara { out += "m" }
            else if v == visarga { out += "h" }
            else if (0x0CE6...0x0CEF).contains(v) { out += String(v - 0x0CE6) }
            else if v == 0x200C || v == 0x200D { /* joiners carry no sound */ }
            else { out.unicodeScalars.append(scalars[i]) }
            i += 1
        }
        return out
    }
}

enum CarolSearch {
    /// Lower case, no accents or width differences, single spaces, Kannada digits as 0-9.
    static func plain(_ text: String) -> String {
        var mapped = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if (0x0CE6...0x0CEF).contains(scalar.value), let digit = Unicode.Scalar(0x30 + scalar.value - 0x0CE6) {
                mapped.append(digit)
            } else {
                mapped.append(scalar)
            }
        }
        // Only Latin accents are removed: stripping every combining mark would eat Kannada vowel signs.
        let decomposed = String(mapped).lowercased().decomposedStringWithCanonicalMapping
        let unaccented = String(String.UnicodeScalarView(decomposed.unicodeScalars.filter { !(0x0300...0x036F).contains($0.value) }))
        return unaccented.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// One word as a sound-alike key: Kannada becomes roman, then spelling variants are folded
    /// together (Jesus = Yesu, "aa" = "a", "bh" = "b", "ch" = "k") and repeats collapse.
    static func phoneticKey(_ word: String) -> String {
        var s = KannadaRoman.transliterate(word)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        s = String(s.unicodeScalars.filter { $0.isASCII && CharacterSet.alphanumerics.contains($0) }.map(Character.init))
        for (from, to) in [("chh", "k"), ("sh", "s"), ("ch", "k"), ("kh", "k"), ("gh", "g"), ("th", "t"), ("dh", "d"), ("bh", "b"), ("ph", "p"), ("jh", "y"), ("ks", "x")] {
            s = s.replacingOccurrences(of: from, with: to)
        }
        let mapped = s.map { ch -> Character in
            switch ch {
            case "c", "q": return "k"
            case "w": return "v"
            case "z", "j": return "y"
            default: return ch
            }
        }
        var out = ""
        for ch in mapped where ch != out.last { out.append(ch) }
        return out
    }

    private static func phoneticWords(_ text: String) -> String {
        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber && !$0.unicodeScalars.contains { (0x0C80...0x0CFF).contains($0.value) } })
        return words.map { phoneticKey(String($0)) }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    private struct Entry {
        let plainAll: String
        let phoneticAll: String
        let plainHeading: String   // title, number and scale: what a number search may match
        let number: String
    }

    private static func entry(for song: CarolSong) -> Entry {
        let parts = CarolBilingual.split(song.lyrics)
        let heading = [song.title, song.songNumber ?? "", song.scale].joined(separator: " ")
        let all = [heading, parts.kannada, parts.english ?? ""].joined(separator: "\n")
        return Entry(plainAll: plain(all), phoneticAll: phoneticWords(all), plainHeading: plain(heading), number: plain(song.songNumber ?? ""))
    }

    private static func tokens(_ query: String) -> [String] {
        plain(query).split(separator: " ").map(String.init)
    }

    private static func matches(_ token: String, in entry: Entry) -> Bool {
        if token.allSatisfy({ $0.isNumber }) {
            // A number looks at the song number and title only, never the verse numbers in lyrics.
            return entry.number.hasPrefix(token) || entry.plainHeading.contains(token)
        }
        if entry.plainAll.contains(token) { return true }
        let key = phoneticKey(token)
        return key.count >= 2 && entry.phoneticAll.contains(key)
    }

    /// True when every word of `query` is found in the song's title, number, scale or lyrics,
    /// either as typed or by sound across English and Kannada. An empty query matches everything.
    static func matches(song: CarolSong, query: String) -> Bool {
        let words = tokens(query)
        guard !words.isEmpty else { return true }
        let e = entry(for: song)
        return words.allSatisfy { matches($0, in: e) }
    }

    static func filter(_ songs: [CarolSong], query: String) -> [CarolSong] {
        guard !tokens(query).isEmpty else { return songs }
        return songs.filter { matches(song: $0, query: query) }
    }

    /// The same matching for a plain piece of text, such as a church's name and description.
    static func matches(text: String, query: String) -> Bool {
        let words = tokens(query)
        guard !words.isEmpty else { return true }
        let e = Entry(plainAll: plain(text), phoneticAll: phoneticWords(text), plainHeading: plain(text), number: "")
        return words.allSatisfy { matches($0, in: e) }
    }
}
