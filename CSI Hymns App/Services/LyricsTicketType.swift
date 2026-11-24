import Foundation

/// The book name and layout of a Jira lyrics ticket.
///
/// The lyrics-triage automation (automation/n8n in the Android repo) parses the ticket title
/// `"<type> <id> Lyrics Issue"` and the description layout below to find the song, pick the vault
/// file and tell whether the reporter wrote anything. Changing a value here needs the same change
/// there, and the Android app (`LyricsTicketType.kt`) sends exactly the same values.
nonisolated enum LyricsTicketType {
    static let hymn = "Hymn"
    static let keerthane = "Keerthane"
    static let mtHymn = "M.T. Hymn"
    static let orderRegular = "Order of Service Regular"
    static let orderFestival = "Order of Service Festival"

    /// `kind` is `Hymn.type`: "hymn", "keerthane" or "mt".
    static func forSong(kind: String) -> String {
        switch kind.lowercased() {
        case "keerthane": return keerthane
        case "mt": return mtHymn
        default: return hymn
        }
    }

    /// `type` is the Order of Service book: "regular" or "festival".
    static func forOrderOfService(type: String) -> String {
        type == "festival" ? orderFestival : orderRegular
    }

    static func orderOfServiceLabel(type: String, pageNo: Int) -> String {
        let name = type == "festival" ? "Festival" : "Regular"
        return "Order of Service (\(name)) page \(pageNo)"
    }

    /// Jira ticket title.
    static func summary(songType: String, number: Int, isAudioContribution: Bool) -> String {
        isAudioContribution
            ? "\(songType) \(number) Audio Contribution"
            : "\(songType) \(number) Lyrics Issue"
    }

    /// Jira ticket description, one block of text in the layout the automation reads.
    static func description(
        songType: String,
        number: Int,
        title: String,
        version: String,
        details: String?
    ) -> String {
        let reporterText = details?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let issue = reporterText.isEmpty ? "No description provided" : reporterText
        return """
        *Song Information:*
        * Type: \(songType)
        * Number: \(number)
        * Title: \(title)

        *App Information:*
        * Version: \(version)

        *Issue Description:*
        \(issue)

        *Reported via:* CSI Hymns App iOS
        """
    }
}
