import Foundation

/// A single `app_config` row. The `value` column is JSONB and may hold a string,
/// number, boolean, object, or array depending on the key.
public struct AppConfigRow: Decodable, Sendable {
    public let key: String
    public let value: AppConfigValue
}

/// Flexibly decodes an `app_config.value` that can arrive as a JSON string, number,
/// boolean, object, or array — matching Android `AppConfigService.configValueAsString`.
public struct AppConfigValue: Decodable, Sendable {
    public let stringValue: String
    public let boolValue: Bool?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            stringValue = ""
            boolValue = nil
            return
        }
        
        if let b = try? container.decode(Bool.self) {
            boolValue = b
            stringValue = b ? "true" : "false"
            return
        }
        if let i = try? container.decode(Int.self) {
            boolValue = (i != 0)
            stringValue = String(i)
            return
        }
        if let d = try? container.decode(Double.self) {
            boolValue = (d != 0)
            stringValue = String(d)
            return
        }
        if let s = try? container.decode(String.self) {
            stringValue = s
            let low = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if low == "true" || low == "1" || low == "yes" {
                boolValue = true
            } else if low == "false" || low == "0" || low == "no" {
                boolValue = false
            } else {
                boolValue = nil
            }
            return
        }
        
        // jsonb object / array (e.g. admin_emails role map)
        if let obj = try? container.decode([String: AppConfigJSON].self) {
            stringValue = AppConfigJSON.object(obj).prettyJSONString()
            boolValue = nil
            return
        }
        if let arr = try? container.decode([AppConfigJSON].self) {
            stringValue = AppConfigJSON.array(arr).prettyJSONString()
            boolValue = nil
            return
        }
        
        stringValue = ""
        boolValue = nil
    }
}

/// Recursive JSON tree for jsonb encode/decode (admin_emails role maps, etc.).
public enum AppConfigJSON: Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: AppConfigJSON])
    case array([AppConfigJSON])
    case null
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let o = try? container.decode([String: AppConfigJSON].self) {
            self = .object(o)
        } else if let a = try? container.decode([AppConfigJSON].self) {
            self = .array(a)
        } else {
            self = .null
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }
    
    public func toAny() -> Any {
        switch self {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .object(let o): return o.mapValues { $0.toAny() }
        case .array(let a): return a.map { $0.toAny() }
        case .null: return NSNull()
        }
    }
    
    public func prettyJSONString() -> String {
        let any = toAny()
        if any is NSNull { return "" }
        guard JSONSerialization.isValidJSONObject(any),
              let data = try? JSONSerialization.data(withJSONObject: any, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: data, encoding: .utf8) else {
            return "\(any)"
        }
        return str
    }
    
    /// Parse a JSON text blob into a tree (for saving admin_emails as a real jsonb object).
    public static func parse(_ raw: String) -> AppConfigJSON? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return fromAny(obj)
    }
    
    public static func fromAny(_ any: Any) -> AppConfigJSON {
        switch any {
        case let s as String: return .string(s)
        case let b as Bool: return .bool(b)
        case let i as Int: return .int(i)
        case let n as NSNumber:
            // Distinguish Bool boxed as NSNumber
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return .bool(n.boolValue)
            }
            if n.doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
                return .int(n.intValue)
            }
            return .double(n.doubleValue)
        case let d as Double: return .double(d)
        case let dict as [String: Any]:
            return .object(dict.mapValues { fromAny($0) })
        case let arr as [Any]:
            return .array(arr.map { fromAny($0) })
        default:
            return .null
        }
    }
}
