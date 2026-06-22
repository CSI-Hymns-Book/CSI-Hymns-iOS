import Foundation

#if canImport(Supabase)
import Supabase
#endif

public struct TicketResult: Sendable {
    public let success: Bool
    public let ticketKey: String?
    public let ticketUrl: String?
    public let errorMessage: String?
    
    public init(success: Bool, ticketKey: String? = nil, ticketUrl: String? = nil, errorMessage: String? = nil) {
        self.success = success
        self.ticketKey = ticketKey
        self.ticketUrl = ticketUrl
        self.errorMessage = errorMessage
    }
}

/// Actor-safe service interfacing with Atlassian Jira Cloud REST APIs
/// for submitting and tracking lyric corrections.
public actor JiraService {
    public static let shared = JiraService()
    
    private let email: String
    private let apiToken: String
    private let projectKey: String
    private let issueTypeName: String
    private let jiraURLString: String
    
    private init() {
        var emailStr = "your-jira-email@domain.com"
        var tokenStr = "your-atlassian-api-token"
        var pKey = "CSI"
        var iType = "Task"
        var urlStr = "https://your-atlassian-domain.atlassian.net"
        
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) {
            if let e = dict["JiraEmail"] as? String { emailStr = e }
            if let t = dict["JiraAPIToken"] as? String { tokenStr = t }
            if let p = dict["JiraProjectKey"] as? String { pKey = p }
            if let i = dict["JiraIssueType"] as? String { iType = i }
            if let u = dict["JiraURL"] as? String { urlStr = u }
        }
        
        self.email = emailStr
        self.apiToken = tokenStr
        self.projectKey = pKey
        self.issueTypeName = iType
        self.jiraURLString = urlStr
    }
    
    /// Submits a new support task ticket to Jira Cloud REST APIs.
    /// - Parameters:
    ///   - songType: "Hymn" or "Keerthane"
    ///   - songNumber: Index sequence number
    ///   - songTitle: Label header
    ///   - description: Optional user review explanation
    ///   - appVersion: Current native build bundle
    public func createTicket(
        songType: String,
        songNumber: Int,
        songTitle: String,
        description: String?,
        appVersion: String
    ) async -> TicketResult {
        let authString = "\(email):\(apiToken)"
        guard let authData = authString.data(using: .utf8) else {
            return TicketResult(success: false, errorMessage: "Failed to generate auth tokens.")
        }
        let base64Auth = authData.base64EncodedString()
        
        let url = URL(string: "\(jiraURLString)/rest/api/3/issue")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Assemble Atlassian Document Format (ADF) description body
        let summary = "Lyric Issue: \(songType) \(songNumber) - \(songTitle)"
        let descNode = buildDescriptionNode(songType: songType, number: songNumber, details: description, version: appVersion)
        
        let payload: [String: Any] = [
            "fields": [
                "project": ["key": projectKey],
                "summary": summary,
                "description": descNode,
                "issuetype": ["name": issueTypeName]
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return TicketResult(success: false, errorMessage: "Invalid server response.")
            }
            
            if httpResponse.statusCode == 201 {
                if let responseJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ticketKey = responseJson["key"] as? String,
                   let selfUrl = responseJson["self"] as? String {
                    let ticketUrl = selfUrl.replacingOccurrences(of: "/rest/api/3/issue/", with: "/browse/")
                    
                    // Sync this created ticket metadata to Supabase log database
                    try? await syncTicketToSupabase(key: ticketKey, url: ticketUrl, songType: songType, number: songNumber, title: songTitle, desc: description, version: appVersion)
                    
                    return TicketResult(success: true, ticketKey: ticketKey, ticketUrl: ticketUrl)
                }
            }
            
            let rawError = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            return TicketResult(success: false, errorMessage: "Jira error: \(rawError)")
        } catch {
            return TicketResult(success: false, errorMessage: "Network transport issue: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    private func buildDescriptionNode(songType: String, number: Int, details: String?, version: String) -> [String: Any] {
        var content: [[String: Any]] = [
            [
                "type": "paragraph",
                "content": [
                    ["type": "text", "text": "An issue was reported for "],
                    ["type": "text", "text": "\(songType) \(number)", "marks": [["type": "strong"]]],
                    ["type": "text", "text": "."]
                ]
            ],
            [
                "type": "paragraph",
                "content": [
                    ["type": "text", "text": "App Version: ", "marks": [["type": "strong"]]],
                    ["type": "text", "text": version]
                ]
            ]
        ]
        
        if let details = details, !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.append([
                "type": "paragraph",
                "content": [
                    ["type": "text", "text": "User Description: ", "marks": [["type": "strong"]]],
                    ["type": "text", "text": details]
                ]
            ])
        }
        
        return [
            "type": "doc",
            "version": 1,
            "content": content
        ]
    }
    
    private func syncTicketToSupabase(
        key: String,
        url: String,
        songType: String,
        number: Int,
        title: String,
        desc: String?,
        version: String
    ) async throws {
        #if canImport(Supabase)
        let (client, userId) = await MainActor.run {
            let svc = SupabaseService.instance
            let userId = svc.isAuthenticated ? svc.currentUser?.id.uuidString : nil
            return (svc.client, userId)
        }
        
        let deviceId = await MainActor.run { TicketsService.shared.getDeviceId() }
        
        struct JiraTicketRow: Encodable {
            let ticket_key: String
            let ticket_url: String
            let song_type: String
            let song_number: Int
            let song_title: String
            let description: String
            let app_version: String
            let jira_status: String
            let device_id: String
            let user_id: String?
        }
        
        let payload = JiraTicketRow(
            ticket_key: key,
            ticket_url: url,
            song_type: songType.lowercased(),
            song_number: number,
            song_title: title,
            description: desc ?? "",
            app_version: version,
            jira_status: "To Do",
            device_id: deviceId,
            user_id: userId
        )
        
        try await client.from("jira_tickets")
            .insert(payload)
            .execute()
        #endif
    }
}
