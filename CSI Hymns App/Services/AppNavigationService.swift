import Foundation
import Observation

#if canImport(Supabase)
import Supabase
#endif

public enum BookSection: String, Codable, Sendable {
    case csi
    case mt
}

@Observable
public final class AppNavigationService: Sendable {
    public static let shared = AppNavigationService()
    
    public var activeSection: BookSection? = nil
    public var isMangaloreHymnsEnabled: Bool = true
    
    private init() {
        Task {
            await fetchMangaloreHymnsEnabled()
        }
    }
    
    public func fetchMangaloreHymnsEnabled() async {
        #if canImport(Supabase)
        do {
            let client = SupabaseService.instance.client
            let rows: [AppConfigRow] = try await client.from("app_config")
                .select("key, value")
                .eq("key", value: "is_mangalore_hymns_enabled")
                .execute()
                .value
            
            if let first = rows.first {
                let enabled = first.value.boolValue ?? true
                await MainActor.run {
                    self.isMangaloreHymnsEnabled = enabled
                }
            }
        } catch {
            print("AppNavigationService: Fetch is_mangalore_hymns_enabled failed: \(error)")
        }
        #endif
    }
}
