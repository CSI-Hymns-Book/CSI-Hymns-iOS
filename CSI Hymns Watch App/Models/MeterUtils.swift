import Foundation

/// Meter / signature helpers (Android `MeterUtils` parity).
public enum MeterUtils {
    /// Example: `"C.M."` → `"c.m"`, `"7. 6. 7. 6. D."` → `"7.6.7.6.d"`
    public static func normalizedMeter(_ signature: String?) -> String {
        guard let signature, !signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "default"
        }
        var clean = signature
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        while clean.hasSuffix(".") {
            clean = String(clean.dropLast())
        }
        return clean
    }
    
    /// URL-safe MIDI filename stem (without `.mid`). Example: `"C.M."` → `"C.M"` encoded.
    public static func meterMidiFileName(_ signature: String?) -> String {
        guard let signature, !signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "default"
        }
        var clean = signature
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        while clean.hasSuffix(".") {
            clean = String(clean.dropLast())
        }
        return clean.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? clean
    }
    
    /// Human label for a tune option / MIDI stem.
    public static func displayTuneName(_ option: String) -> String {
        let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.contains("m.t.") || lower.contains("mang.t.b.") || lower.hasPrefix("mt") {
            // Match Android: show M.T. + digits/suffix (Mang.T.B.50 → "M.T. 50")
            let token = String(trimmed.filter { $0.isNumber || $0 == "b" || $0 == "c" || $0 == "d" || $0 == "e" })
            return token.isEmpty ? "M.T." : "M.T. \(token)"
        }
        
        var cleanOption = trimmed
        if cleanOption.lowercased().hasPrefix("hymn_") {
            let suffix = String(cleanOption.dropFirst(5))
            if !suffix.contains("_") {
                return "Hymn \(suffix)"
            }
            cleanOption = suffix
        }
        if cleanOption.first?.isNumber == true, cleanOption.contains("_") {
            cleanOption = String(cleanOption.split(separator: "_", maxSplits: 1).last ?? Substring(cleanOption))
        }
        
        let targetText: String
        if cleanOption.contains("_"), option.contains("_") {
            if option.lowercased().hasPrefix("hymn_") || option.first?.isNumber == true {
                targetText = cleanOption
            } else {
                targetText = String(option.split(separator: "_", maxSplits: 1).last ?? Substring(cleanOption))
            }
        } else {
            targetText = cleanOption
        }
        
        if targetText.lowercased().range(of: #"^v\d+$"#, options: .regularExpression) != nil {
            return "Version \(targetText.dropFirst())"
        }
        
        if !targetText.contains("_") {
            return targetText.prefix(1).uppercased() + targetText.dropFirst().lowercased()
        }
        
        return targetText
            .split(separator: "_")
            .filter { !$0.isEmpty }
            .map { word in
                let lower = word.lowercased()
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
            .joined(separator: " ")
    }
}
