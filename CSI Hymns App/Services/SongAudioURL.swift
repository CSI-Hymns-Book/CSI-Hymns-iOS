import Foundation

/// Builds CDN audio URLs for hymns and keerthanes (Flutter parity).
enum SongAudioURL {
    private static let base = "https://raw.githubusercontent.com/reynold29/midi-files/main"
    
    static func streamURL(for hymn: Hymn) -> String {
        let isKeerthane = hymn.type.lowercased() == "keerthane"
        if isKeerthane {
            return "\(base)/Keerthane/Keerthane_\(hymn.number).ogg"
        }
        return "\(base)/Hymns/Hymn_\(hymn.number).ogg"
    }
}
