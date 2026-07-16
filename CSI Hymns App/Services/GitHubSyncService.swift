import Foundation

public final class GitHubSyncService: Sendable {
    public static let shared = GitHubSyncService()
    
    private init() {}
    
    /// Pushes file content to a GitHub repository contents endpoint.
    /// Returns nil on success, or error message on failure.
    public func pushFileToGitHub(
        token: String,
        repo: String,
        filePath: String,
        content: String,
        commitMessage: String
    ) async -> String? {
        let cleanToken = token.replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        guard let utf8Data = content.data(using: .utf8) else {
            return "Failed to convert content to UTF-8 data."
        }
        let base64Content = utf8Data.base64EncodedString()
        
        let urlString = "https://api.github.com/repos/\(repo)/contents/\(filePath)"
        guard let url = URL(string: urlString) else {
            return "Invalid GitHub repository URL."
        }
        
        // 1. Get the existing file's SHA if it exists
        var getRequest = URLRequest(url: url)
        getRequest.httpMethod = "GET"
        getRequest.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
        getRequest.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        getRequest.setValue("CSI-Hymns-App-iOS", forHTTPHeaderField: "User-Agent")
        
        var sha: String? = nil
        if let (data, response) = try? await URLSession.shared.data(for: getRequest),
           let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let existingSha = json["sha"] as? String {
                sha = existingSha
            }
        }
        
        // 2. Put the new contents
        var putRequest = URLRequest(url: url)
        putRequest.httpMethod = "PUT"
        putRequest.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
        putRequest.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        putRequest.setValue("CSI-Hymns-App-iOS", forHTTPHeaderField: "User-Agent")
        putRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = [
            "message": commitMessage,
            "content": base64Content
        ]
        if let sha = sha {
            payload["sha"] = sha
        }
        
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: payload, options: [])
            putRequest.httpBody = bodyData
            
            let (data, response) = try await URLSession.shared.data(for: putRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                return "No response from GitHub servers."
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                return nil
            } else {
                let errorDetails = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                return "Failed to push: \(errorDetails)"
            }
        } catch {
            return error.localizedDescription
        }
    }
}
