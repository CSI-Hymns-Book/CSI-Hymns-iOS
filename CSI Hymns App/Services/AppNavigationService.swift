import Foundation
import Observation

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
        Task { @MainActor in
            await syncMangaloreFromConfig()
        }
    }

    @MainActor
    public func syncMangaloreFromConfig() async {
        await AppConfigService.shared.refresh()
        isMangaloreHymnsEnabled = AppConfigService.shared.isMangaloreEnabled
    }

    @MainActor
    public func fetchMangaloreHymnsEnabled() async {
        await syncMangaloreFromConfig()
    }
}
