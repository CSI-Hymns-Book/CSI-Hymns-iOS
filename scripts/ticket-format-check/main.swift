import Foundation

// Compile and run with: scripts/check-lyrics-ticket-format.sh
// Checks that iOS lyrics tickets can be read by the Android repo's triage workflow.

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if !condition { failures += 1; print("FAIL  \(message)") } else { print("ok    \(message)") }
}

/// The three patterns the workflow's "Parse ticket" node applies.
func firstGroup(_ pattern: String, in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          match.numberOfRanges > 1,
          let range = Range(match.range(at: 1), in: text) else { return nil }
    return String(text[range])
}

check(LyricsTicketType.forSong(kind: "hymn") == "Hymn", "hymn maps to Hymn")
check(LyricsTicketType.forSong(kind: "keerthane") == "Keerthane", "keerthane maps to Keerthane")
check(LyricsTicketType.forSong(kind: "mt") == "M.T. Hymn", "mt maps to M.T. Hymn, not Hymn")
check(LyricsTicketType.forSong(kind: "anything-else") == "Hymn", "unknown kind falls back to Hymn")
check(LyricsTicketType.forOrderOfService(type: "regular") == "Order of Service Regular", "regular order of service")
check(LyricsTicketType.forOrderOfService(type: "festival") == "Order of Service Festival", "festival order of service")
check(LyricsTicketType.orderOfServiceLabel(type: "festival", pageNo: 7) == "Order of Service (Festival) page 7", "order of service label")

for (type, number) in [("Hymn", 3), ("M.T. Hymn", 12), ("Keerthane", 214), ("Order of Service Regular", 5)] {
    let summary = LyricsTicketType.summary(songType: type, number: number, isAudioContribution: false)
    check(summary == "\(type) \(number) Lyrics Issue", "summary for \(type) \(number)")
    check(firstGroup(#"^(.*?)\s+(\d+)\s+Lyrics Issue$"#, in: summary) == type, "workflow reads the book from '\(summary)'")
}
check(LyricsTicketType.summary(songType: "Hymn", number: 3, isAudioContribution: true) == "Hymn 3 Audio Contribution", "audio contribution summary")

let blank = LyricsTicketType.description(songType: "M.T. Hymn", number: 3, title: "Shuddha, shuddha, shuddha", version: "5.2.0", details: nil)
check(firstGroup(#"\*\s*Title:\s*(.+)"#, in: blank) == "Shuddha, shuddha, shuddha", "workflow reads the title")
check(firstGroup(#"\*Issue Description:\*\s*([\s\S]*?)\s*\*Reported via:\*"#, in: blank) == "No description provided", "blank report reads as 'No description provided'")
let spaces = LyricsTicketType.description(songType: "Hymn", number: 1, title: "T", version: "5.2.0", details: "   \n ")
check(firstGroup(#"\*Issue Description:\*\s*([\s\S]*?)\s*\*Reported via:\*"#, in: spaces) == "No description provided", "whitespace-only report counts as blank")
let written = LyricsTicketType.description(songType: "Hymn", number: 1, title: "T", version: "5.2.0", details: "Line 3 has a wrong word")
check(firstGroup(#"\*Issue Description:\*\s*([\s\S]*?)\s*\*Reported via:\*"#, in: written) == "Line 3 has a wrong word", "reporter text is kept so the workflow sends it to a person")

print(failures == 0 ? "\nall passed" : "\n\(failures) failed")
exit(failures == 0 ? 0 : 1)
