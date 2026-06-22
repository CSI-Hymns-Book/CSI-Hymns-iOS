import Foundation
import Observation

#if canImport(Supabase)
import Supabase
#endif

/// Reads `page_flip_visible` from Supabase `app_config` and caches locally.
@MainActor
@Observable
public final class PageFlipVisibilityService {
    public static let shared = PageFlipVisibilityService()
    
    private static let cacheKey = "page_flip_visible_cached"
    private static let configKey = "page_flip_visible"
    
    public private(set) var isVisible = true
    
    private init() {
        if UserDefaults.standard.object(forKey: Self.cacheKey) != nil {
            isVisible = UserDefaults.standard.bool(forKey: Self.cacheKey)
        }
        Task { await refresh() }
    }
    
    public func refresh() async {
        #if canImport(Supabase)
        do {
            let rows: [AppConfigRow] = try await SupabaseService.instance.client
                .from("app_config")
                .select("key, value")
                .eq("key", value: Self.configKey)
                .execute()
                .value
            if let value = rows.first?.value.boolValue {
                isVisible = value
                UserDefaults.standard.set(value, forKey: Self.cacheKey)
            }
        } catch {
            print("PageFlipVisibilityService: fetch failed: \(error)")
        }
        #endif
    }
}
