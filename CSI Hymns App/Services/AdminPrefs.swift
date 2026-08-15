import Foundation

/// Admin role gates and sudo unlock (Android `AdminPrefs` parity).
public enum AdminPrefs {
    public static let sudoAdminKey = "is_sudo_admin_mode_enabled"
    
    public enum AdminRole: String, CaseIterable, Sendable {
        case admin
        case lyrics
        case prManager = "pr_manager"
        case appConfig = "app_config"
        case tuneMeterView = "tune_meter_view"
        
        public var label: String {
            switch self {
            case .admin: return "Super Admin"
            case .lyrics: return "Lyric Corrections"
            case .prManager: return "Announcements Manager"
            case .appConfig: return "App Config Manager"
            case .tuneMeterView: return "Tune Meters View"
            }
        }
        
        public static func fromKey(_ key: String) -> AdminRole? {
            AdminRole(rawValue: key.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    
    public static var isSudoAdminEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: sudoAdminKey) }
        set { UserDefaults.standard.set(newValue, forKey: sudoAdminKey) }
    }
    
    public static func verifyPasscode(_ input: String) async -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        await AppConfigService.shared.refresh()
        if let remote = AppConfigService.shared.config.masterRootPasscode,
           !remote.isEmpty,
           trimmed == remote {
            return true
        }
        
        if let cached = UserDefaults.standard.string(forKey: "cached_master_root_passcode")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !cached.isEmpty,
           trimmed == cached {
            return true
        }
        return false
    }
    
    public static func normalizeAdminEmailsRaw(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return s }
        
        if s.hasPrefix("\""), s.hasSuffix("\""), s.count >= 2 {
            s = String(s.dropFirst().dropLast())
                .replacingOccurrences(of: "\\\"", with: "\"")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if s.contains("\\n"), !s.contains("\n") {
            s = s.replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\\"", with: "\"")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public static func parseAdminRoles(_ adminEmailsConfig: String?) -> [String: Set<AdminRole>] {
        guard let adminEmailsConfig, !adminEmailsConfig.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [:]
        }
        let raw = normalizeAdminEmailsRaw(adminEmailsConfig)
        var result: [String: Set<AdminRole>] = [:]
        
        if raw.hasPrefix("{"),
           let data = raw.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (originalEmail, value) in obj {
                let email = originalEmail.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                var roleSet = Set<AdminRole>()
                if let arr = value as? [Any] {
                    for item in arr {
                        guard let roleStr = item as? String else { continue }
                        let normalized = roleStr.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        if normalized == "admin" || normalized == "all" {
                            roleSet.insert(.admin)
                        } else if let role = AdminRole.fromKey(normalized) {
                            roleSet.insert(role)
                        }
                    }
                } else if let roleStr = value as? String {
                    let normalized = roleStr.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    if normalized == "admin" || normalized == "all" {
                        roleSet.insert(.admin)
                    } else if let role = AdminRole.fromKey(normalized) {
                        roleSet.insert(role)
                    }
                }
                if !roleSet.isEmpty {
                    result[email] = roleSet
                }
            }
            return result
        }
        
        let cleaned = raw
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
        for email in cleaned.split(separator: ",") {
            let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !normalized.isEmpty {
                result[normalized] = [.admin]
            }
        }
        return result
    }
    
    public static func prettifyAdminEmailsConfig(_ raw: String?) -> String {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        let normalized = normalizeAdminEmailsRaw(raw)
        guard let data = normalized.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else {
            return normalized
        }
        return str
    }
    
    public static func hasRole(
        currentUserEmail: String?,
        adminEmailsConfig: String?,
        requiredRole: AdminRole
    ) -> Bool {
        if isSudoAdminEnabled { return true }
        guard let currentUserEmail, !currentUserEmail.isEmpty else { return false }
        let email = currentUserEmail.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let roles = parseAdminRoles(adminEmailsConfig)[email] ?? []
        return roles.contains(.admin) || roles.contains(requiredRole)
    }
    
    public static func hasAnyAdminRole(
        currentUserEmail: String?,
        adminEmailsConfig: String?
    ) -> Bool {
        if isSudoAdminEnabled { return true }
        guard let currentUserEmail, !currentUserEmail.isEmpty else { return false }
        let email = currentUserEmail.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return !(parseAdminRoles(adminEmailsConfig)[email] ?? []).isEmpty
    }
    
    /// Hardcoded fallback emails used when remote config is unavailable.
    public static let localFallbackEmails: Set<String> = [
        "reynoldclare29022902@gmail.com",
        "reynoldclare02@gmail.com",
        "reyziecrafts@gmail.com",
        "reynold.clare29022902@gmail.com"
    ]
}
