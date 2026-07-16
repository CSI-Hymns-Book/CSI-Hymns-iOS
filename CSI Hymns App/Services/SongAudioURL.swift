import Foundation

/// Builds CDN audio URLs for hymns and keerthanes (Flutter parity).
enum SongAudioURL {
    private static let base = "https://raw.githubusercontent.com/reynold29/midi-files/main"
    
    static func streamURL(for hymn: Hymn, selectedTune: String? = nil) -> String {
        if hymn.type == "keerthane" {
            return "\(base)/Keerthane/Keerthane_\(hymn.number).ogg"
        } else if hymn.type == "mt" {
            let tuneName = selectedTune ?? extractTuneOptions(for: hymn).first ?? "\(hymn.number)"
            return "\(base)/Mangalore%20Tunes/mt\(tuneName).mid"
        }
        
        // Default CSI Hymn
        let tuneName = selectedTune ?? "\(hymn.number)"
        // Fallback for regular hymns just in case they are mapped to variants (though mostly MT uses this)
        // Currently regular hymns use ogg, we assume the base number for now unless specifically overridden.
        return "\(base)/Hymns/Hymn_\(tuneName).ogg"
    }
    
    static func extractTuneOptions(for hymn: Hymn) -> [String] {
        if hymn.type == "keerthane" { return ["\(hymn.number)"] }
        
        var options: [String] = []
        let signature = hymn.signature.lowercased()
        
        if hymn.type == "mt" {
            do {
                let regex = try NSRegularExpression(pattern: "\\b\\d+[b-e]?\\b")
                let nsString = signature as NSString
                let results = regex.matches(in: signature, range: NSRange(location: 0, length: nsString.length))
                options = results.map { nsString.substring(with: $0.range) }
            } catch {}
            
            if options.isEmpty {
                options.append("\(hymn.number)")
            }
        } else {
            // For CSI Hymns, usually it's just the number, but we can parse it if needed
            options.append("\(hymn.number)")
        }
        
        // Remove duplicates while preserving order
        var uniqueOptions = [String]()
        for opt in options {
            if !uniqueOptions.contains(opt) { uniqueOptions.append(opt) }
        }
        return uniqueOptions
    }
    
    static func checkUrlExists(urlStr: String) async -> Bool {
        guard let url = URL(string: urlStr) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            return false
        }
        return false
    }
}
