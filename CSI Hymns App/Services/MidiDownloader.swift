import Foundation

enum MidiDownloadError: LocalizedError, Equatable {
    case notFound
    case forbidden
    case timeout
    case offline
    case decode
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound: return "Audio file not found on the server."
        case .forbidden: return "Audio server denied access. Try again later."
        case .timeout: return "Audio download timed out."
        case .offline: return "You're offline. Connect to the internet to play audio."
        case .decode: return "Couldn't decode this audio file."
        case .unknown(let msg): return msg
        }
    }
}

/// Downloads MIDI bytes with disk cache, GitHub token auth, and backup URL retry.
enum MidiDownloader {
    static func download(urlString: String) async throws -> Data {
        let fingerprint = MidiFileCache.currentFingerprint()
        if let cached = MidiFileCache.shared.getIfFresh(url: urlString, fingerprint: fingerprint) {
            return cached.bytes
        }
        
        do {
            let data = try await fetchBytes(urlString: urlString)
            MidiFileCache.shared.put(url: urlString, bytes: data, fingerprint: fingerprint)
            return data
        } catch {
            if let backup = SongAudioURL.backupURL(for: urlString), backup != urlString {
                let data = try await fetchBytes(urlString: backup)
                MidiFileCache.shared.put(url: urlString, bytes: data, fingerprint: fingerprint)
                return data
            }
            throw error
        }
    }
    
    private static func fetchBytes(urlString: String) async throws -> Data {
        let token = cleanToken(UserDefaults.standard.string(forKey: "github_midi_token_cached"))
        let isVault = urlString.localizedCaseInsensitiveContains("midi-vault")
        let useAPI = isVault && !(token ?? "").isEmpty
        
        var finalURLString = urlString
        if useAPI {
            finalURLString = githubContentsURL(from: urlString) ?? urlString
        }
        
        guard let url = URL(string: finalURLString) else {
            throw MidiDownloadError.unknown("Invalid audio URL")
        }
        
        if useAPI, let token {
            if let data = try? await execute(url: url, auth: "Bearer \(token)") {
                return data
            }
            if let data = try? await execute(url: url, auth: "token \(token)") {
                return data
            }
            throw MidiDownloadError.forbidden
        }
        
        return try await execute(url: url, auth: nil)
    }
    
    private static func execute(url: URL, auth: String?) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("CSI-Hymns-iOS", forHTTPHeaderField: "User-Agent")
        request.httpMethod = "GET"
        if let auth {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw MidiDownloadError.decode
            }
            
            // Follow redirects manually when needed
            if (300...399).contains(http.statusCode),
               let location = http.value(forHTTPHeaderField: "Location"),
               let redirectURL = URL(string: location) {
                var redirect = URLRequest(url: redirectURL)
                redirect.timeoutInterval = 12
                redirect.setValue("CSI-Hymns-iOS", forHTTPHeaderField: "User-Agent")
                let (redirectData, redirectResponse) = try await URLSession.shared.data(for: redirect)
                guard let redirectHTTP = redirectResponse as? HTTPURLResponse,
                      (200...299).contains(redirectHTTP.statusCode) else {
                    throw mapStatus((redirectResponse as? HTTPURLResponse)?.statusCode ?? 500)
                }
                return redirectData
            }
            
            guard (200...299).contains(http.statusCode) else {
                throw mapStatus(http.statusCode)
            }
            guard !data.isEmpty else { throw MidiDownloadError.decode }
            return data
        } catch let error as MidiDownloadError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw MidiDownloadError.offline
            case .timedOut:
                throw MidiDownloadError.timeout
            default:
                throw MidiDownloadError.unknown(error.localizedDescription)
            }
        } catch {
            throw MidiDownloadError.unknown(error.localizedDescription)
        }
    }
    
    private static func mapStatus(_ code: Int) -> MidiDownloadError {
        switch code {
        case 404: return .notFound
        case 401, 403: return .forbidden
        case 408, 504: return .timeout
        default: return .unknown("Server request failed (HTTP \(code))")
        }
    }
    
    private static func githubContentsURL(from rawURL: String) -> String? {
        let rawPath: String
        if let range = rawURL.range(of: "/midi-vault/main/", options: .caseInsensitive) {
            rawPath = String(rawURL[range.upperBound...])
        } else if let range = rawURL.range(of: "/contents/") {
            rawPath = String(rawURL[range.upperBound...])
        } else {
            return nil
        }
        let decoded = rawPath.removingPercentEncoding ?? rawPath
        let encoded = decoded
            .split(separator: "/")
            .map { component in
                String(component).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?
                    .replacingOccurrences(of: "+", with: "%20") ?? String(component)
            }
            .joined(separator: "/")
        return "https://api.github.com/repos/Reynold29/midi-vault/contents/\(encoded)"
    }
    
    private static func cleanToken(_ raw: String?) -> String? {
        guard var token = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty,
              token != "null" else { return nil }
        token = token
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }
}
