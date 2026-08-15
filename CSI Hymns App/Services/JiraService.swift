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
    public func createTicket(
        songType: String,
        songNumber: Int,
        songTitle: String,
        description: String?,
        appVersion: String,
        isAudioContribution: Bool = false
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
        
        let summary = isAudioContribution
            ? "\(songType) \(songNumber) Audio Contribution"
            : "Lyric Issue: \(songType) \(songNumber) - \(songTitle)"
        let descNode = buildDescriptionNode(
            songType: songType,
            number: songNumber,
            title: songTitle,
            details: description,
            version: appVersion,
            isAudioContribution: isAudioContribution
        )
        
        let labels = isAudioContribution
            ? ["audio-contribution", "app-reported", "ios-app"]
            : ["lyrics-issue", "app-reported", "ios-app"]
        
        let payload: [String: Any] = [
            "fields": [
                "project": ["key": projectKey],
                "summary": summary,
                "description": descNode,
                "issuetype": ["name": issueTypeName],
                "labels": labels
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
    
    /// Uploads a file attachment to an existing Jira issue (audio contribution).
    public func uploadAttachment(ticketKey: String, fileData: Data, fileName: String) async -> Bool {
        let authString = "\(email):\(apiToken)"
        guard let authData = authString.data(using: .utf8) else { return false }
        let base64Auth = authData.base64EncodedString()
        
        guard let url = URL(string: "\(jiraURLString)/rest/api/3/issue/\(ticketKey)/attachments") else {
            return false
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        request.setValue("no-check", forHTTPHeaderField: "X-Atlassian-Token")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            return code == 200 || code == 201
        } catch {
            print("JiraService: uploadAttachment failed for \(ticketKey): \(error)")
            return false
        }
    }
    
    // MARK: - Helpers
    
    private func buildDescriptionNode(
        songType: String,
        number: Int,
        title: String,
        details: String?,
        version: String,
        isAudioContribution: Bool
    ) -> [String: Any] {
        var content: [[String: Any]] = [
            [
                "type": "paragraph",
                "content": [
                    ["type": "text", "text": isAudioContribution ? "Audio contribution for " : "An issue was reported for "],
                    ["type": "text", "text": "\(songType) \(number) — \(title)", "marks": [["type": "strong"]]],
                    ["type": "text", "text": "."]
                ]
            ],
            [
                "type": "paragraph",
                "content": [
                    ["type": "text", "text": "App Version: ", "marks": [["type": "strong"]]],
                    ["type": "text", "text": version]
                ]
            ],
            [
                "type": "paragraph",
                "content": [
                    ["type": "text", "text": "Reported via: ", "marks": [["type": "strong"]]],
                    ["type": "text", "text": "CSI Hymns App iOS"]
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
    
    /// Syncs the status of a Jira ticket from Jira Cloud API to Supabase
    public func syncTicketStatus(ticketKey: String) async {
        let authString = "\(email):\(apiToken)"
        guard let authData = authString.data(using: .utf8) else { return }
        let base64Auth = authData.base64EncodedString()
        
        guard let url = URL(string: "\(jiraURLString)/rest/api/3/issue/\(ticketKey)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any],
               let status = fields["status"] as? [String: Any],
               let statusName = status["name"] as? String {
                let statusId = status["id"] as? String
                
                #if canImport(Supabase)
                let (client, isAuthed, deviceId) = await MainActor.run {
                    let svc = SupabaseService.instance
                    return (svc.client, svc.isAuthenticated, TicketsService.shared.getDeviceId())
                }
                
                struct StatusUpdate: Encodable {
                    let jira_status: String
                    let jira_status_id: String?
                }
                
                if isAuthed {
                    try await client.from("jira_tickets")
                        .update(StatusUpdate(jira_status: statusName, jira_status_id: statusId))
                        .eq("ticket_key", value: ticketKey)
                        .execute()
                } else {
                    try await client.rpc(
                        "update_guest_ticket_status",
                        params: [
                            "p_device_id": deviceId,
                            "p_ticket_key": ticketKey,
                            "p_jira_status": statusName,
                            "p_jira_status_id": statusId ?? ""
                        ]
                    ).execute()
                }
                #endif
            }
        } catch {
            print("JiraService: syncTicketStatus failed for \(ticketKey): \(error)")
        }
    }
    
    /// Adds a comment to a Jira ticket
    public func addComment(ticketKey: String, commentText: String) async -> Bool {
        let authString = "\(email):\(apiToken)"
        guard let authData = authString.data(using: .utf8) else { return false }
        let base64Auth = authData.base64EncodedString()
        
        guard let url = URL(string: "\(jiraURLString)/rest/api/3/issue/\(ticketKey)/comment") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let commentWithTag = "\(commentText)\n\n[via CSI iOS App]"
        
        let payload: [String: Any] = [
            "body": [
                "type": "doc",
                "version": 1,
                "content": [
                    [
                        "type": "paragraph",
                        "content": [
                            [
                                "type": "text",
                                "text": commentWithTag
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == 201
        } catch {
            print("JiraService: addComment failed for \(ticketKey): \(error)")
            return false
        }
    }
    
    /// Syncs comments from a Jira ticket to Supabase ticket_messages
    public func syncTicketComments(ticketId: String, ticketKey: String) async {
        let authString = "\(email):\(apiToken)"
        guard let authData = authString.data(using: .utf8) else { return }
        let base64Auth = authData.base64EncodedString()
        
        guard let url = URL(string: "\(jiraURLString)/rest/api/3/issue/\(ticketKey)/comment") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let comments = json["comments"] as? [[String: Any]] {
                
                #if canImport(Supabase)
                let (client, isAuthed, deviceId) = await MainActor.run {
                    let svc = SupabaseService.instance
                    return (svc.client, svc.isAuthenticated, TicketsService.shared.getDeviceId())
                }
                
                for comment in comments {
                    guard let bodyObj = comment["body"] as? [String: Any] else { continue }
                    let text = parseJiraDocText(bodyObj)
                    if text.isEmpty { continue }
                    
                    if text.contains("[via CSI iOS App]") || text.contains("[via CSI Android App]") {
                        continue
                    }
                    
                    let existing: [TicketMessage]
                    if isAuthed {
                        existing = try await client.from("ticket_messages")
                            .select()
                            .eq("ticket_key", value: ticketKey)
                            .eq("sender", value: "admin")
                            .eq("message", value: text)
                            .execute()
                            .value
                    } else {
                        let all: [TicketMessage] = try await client.rpc(
                            "get_guest_ticket_messages",
                            params: [
                                "p_device_id": deviceId,
                                "p_ticket_key": ticketKey
                            ]
                        )
                        .execute()
                        .value
                        existing = all.filter { $0.sender == "admin" && $0.message == text }
                    }
                    
                    if existing.isEmpty {
                        struct InsertMessage: Encodable {
                            let ticket_id: String
                            let ticket_key: String
                            let sender: String
                            let message: String
                        }
                        
                        let msg = InsertMessage(
                            ticket_id: ticketId,
                            ticket_key: ticketKey,
                            sender: "admin",
                            message: text
                        )
                        
                        try await client.from("ticket_messages")
                            .insert(msg)
                            .execute()
                    }
                }
                #endif
            }
        } catch {
            print("JiraService: syncTicketComments failed for \(ticketKey): \(error)")
        }
    }
    
    private func parseJiraDocText(_ bodyObj: [String: Any]) -> String {
        var result = ""
        if let contentArray = bodyObj["content"] as? [[String: Any]] {
            for block in contentArray {
                if let innerContent = block["content"] as? [[String: Any]] {
                    for leaf in innerContent {
                        if let text = leaf["text"] as? String {
                            result += text
                        }
                    }
                    result += "\n"
                }
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
