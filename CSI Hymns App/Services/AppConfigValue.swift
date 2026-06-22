import Foundation

/// A single `app_config` row. The `value` column is JSONB and may hold a string,
/// number, or boolean depending on the key, so it is decoded flexibly.
public struct AppConfigRow: Decodable, Sendable {
    public let key: String
    public let value: AppConfigValue
}

/// Flexibly decodes an `app_config.value` that can arrive as a JSON string, number,
/// or boolean, normalizing access via `stringValue` / `boolValue`.
public struct AppConfigValue: Decodable, Sendable {
    public let stringValue: String
    public let boolValue: Bool?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let b = try? container.decode(Bool.self) {
            boolValue = b
            stringValue = b ? "true" : "false"
        } else if let i = try? container.decode(Int.self) {
            boolValue = (i != 0)
            stringValue = String(i)
        } else if let d = try? container.decode(Double.self) {
            boolValue = (d != 0)
            stringValue = String(d)
        } else if let s = try? container.decode(String.self) {
            stringValue = s
            let low = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if low == "true" || low == "1" || low == "yes" {
                boolValue = true
            } else if low == "false" || low == "0" || low == "no" {
                boolValue = false
            } else {
                boolValue = nil
            }
        } else {
            stringValue = ""
            boolValue = nil
        }
    }
}
