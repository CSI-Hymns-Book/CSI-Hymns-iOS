import Foundation
import Combine
import Observation
import AuthenticationServices
#if os(iOS)
import UIKit
#endif

#if canImport(Supabase)
import Supabase
#endif

/// Thread-safe client service managing Supabase authentication, database synchronization,
/// and user profile interactions.
@MainActor
@Observable
public final class SupabaseService {
    public static let instance = SupabaseService()
    
    // MARK: - Properties
    public var currentUserEmail: String? { currentUser?.email }
    public var isAuthenticated: Bool { currentUser != nil }
    public private(set) var isInitializing = true
    
    // In-memory cache or mocks if Supabase package is not fully resolved in test scaffolds
    #if canImport(Supabase)
    public let client: SupabaseClient
    #endif
    
    // Simulated currentUser for pure compile-safety fallback
    public struct AppUser: Codable, Sendable {
        public let id: UUID
        public let email: String?
        public let fullName: String?
        public let privacyPolicyAccepted: Bool
    }
    
    public var currentUser: AppUser? = nil {
        didSet {
            if let user = currentUser {
                if ConsentManager.shared.analyticsConsent {
                    PostHogService.shared.identify(userId: user.id.uuidString)
                }
            } else {
                PostHogService.shared.reset()
            }
        }
    }
    /// Resolved display name for Settings and the profile screen.
    public private(set) var displayName: String = "CSI Devotional User"
    
    private init() {
        // Initialize client configuration securely
        var supabaseUrl: URL? = nil
        var supabaseKey: String? = nil
        
        // 1. Attempt to load from Bundle.main
        var path = Bundle.main.path(forResource: "Secrets", ofType: "plist")
        
        // 2. Simulator/development backup: load directly from absolute workspace path if Bundle lookup fails.
        // Restricted to DEBUG so release builds rely solely on the bundled Secrets.plist.
        #if DEBUG
        if path == nil {
            let localDevPath = "/Users/reyzie/Documents/Personal Projects/CSI-IOS-Native/CSI-Hymns-Native/CSI Hymns App/CSI Hymns App/Secrets.plist"
            if FileManager.default.fileExists(atPath: localDevPath) {
                path = localDevPath
                print("SupabaseService: 🛠️ Found Secrets.plist via absolute developer backup path!")
            }
        }
        #endif
        
        if let plistPath = path {
            if let dict = NSDictionary(contentsOfFile: plistPath) {
                let urlString = (dict["SupabaseURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let key = (dict["SupabaseAnonKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                if let url = URL(string: urlString), !urlString.isEmpty, !key.isEmpty {
                    supabaseUrl = url
                    supabaseKey = key
                    print("SupabaseService: Successfully initialized from '\(plistPath)'")
                    print("SupabaseService: Loaded URL -> \(urlString)")
                    print("SupabaseService: Loaded Key Prefix -> \(String(key.prefix(10)))...")
                } else {
                    print("⚠️ ERROR: Secrets.plist found at '\(plistPath)', but SupabaseURL or SupabaseAnonKey is empty or malformed!")
                }
            } else {
                print("⚠️ ERROR: Secrets.plist found at '\(plistPath)', but failed to parse as NSDictionary! Check XML format.")
            }
        } else {
            print("⚠️ ERROR: Secrets.plist NOT FOUND in Bundle.main and fallback developer path is missing!")
        }
        
        // Fallback placeholders only if plist failed entirely
        if supabaseUrl == nil || supabaseKey == nil {
            print("⚠️ WARNING: [SupabaseService] Falling back to dummy credentials. Login/Signup will be broken!")
            supabaseUrl = URL(string: "https://your-project-ref.supabase.co")!
            supabaseKey = "your-anon-key"
        }
        
        #if canImport(Supabase)
        self.client = SupabaseClient(
            supabaseURL: supabaseUrl!,
            supabaseKey: supabaseKey!,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
        #endif
        
        Task { @MainActor in
            await initializeSession()
        }
    }
    
    private func initializeSession() async {
        // Hydrate authentication states
        #if canImport(Supabase)
        
        // 1. One-time seamless session migration from legacy Flutter app SharedPreferences (UserDefaults on iOS)
        let keysToTry = ["flutter.supabase.auth.token", "flutter.SUPABASE_PERSIST_SESSION_KEY"]
        for legacyKey in keysToTry {
            if let sessionString = UserDefaults.standard.string(forKey: legacyKey),
               let data = sessionString.data(using: .utf8) {
                do {
                    if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        var sessionDict = dict
                        if let nested = dict["currentSession"] as? [String: Any] {
                            sessionDict = nested
                        } else if let nested = dict["session"] as? [String: Any] {
                            sessionDict = nested
                        }
                        
                        let accessToken = (sessionDict["access_token"] as? String) ?? (sessionDict["accessToken"] as? String)
                        let refreshToken = (sessionDict["refresh_token"] as? String) ?? (sessionDict["refreshToken"] as? String)
                        
                        if let access = accessToken, let refresh = refreshToken {
                            print("[AuthMigration] Found legacy Flutter user session under key '\(legacyKey)'! Restoring session state...")
                            try await client.auth.setSession(accessToken: access, refreshToken: refresh)
                            
                            // Clear all migration keys immediately upon success to prevent infinite migration runs
                            for k in keysToTry {
                                UserDefaults.standard.removeObject(forKey: k)
                            }
                            print("[AuthMigration] Migration successful! Flutter session migrated to native securely.")
                            break
                        }
                    }
                } catch {
                    print("[AuthMigration] Session restoration failed for key '\(legacyKey)': \(error)")
                }
            }
        }
        
        // 2. Fetch the current active/recovered user details
        do {
            let session = try await client.auth.session
            if session.isExpired {
                print("SupabaseService: Stored session expired — starting signed out.")
            } else {
                let user = session.user
                if await isAccountDeleted(authUid: user.id) {
                    try? await client.auth.signOut()
                    self.currentUser = nil
                    await refreshDisplayName()
                    print("SupabaseService: Deactivated account session cleared.")
                } else {
                    let accepted = await fetchPrivacyAcceptance(authUid: user.id)
                    self.currentUser = AppUser(
                        id: user.id,
                        email: user.email,
                        fullName: Self.stringFromUserMetadata(user.userMetadata["full_name"])
                            ?? Self.stringFromUserMetadata(user.userMetadata["name"]),
                        privacyPolicyAccepted: accepted
                    )
                    await refreshDisplayName()
                }
            }
        } catch AuthError.sessionMissing {
            // Expected when no user is signed in (fresh install / signed-out state).
            print("SupabaseService: No stored session — starting signed out.")
        } catch {
            print("SupabaseService: Session hydration error: \(error)")
        }
        #endif
        self.isInitializing = false
    }
    
    // MARK: - Auth Operations
    
    /// Signs in a user using email and password.
    public func signIn(email: String, password: String) async throws {
        #if canImport(Supabase)
        let response = try await client.auth.signIn(email: email, password: password)
        let user = response.user
        try await ensureAccountIsActive(authUid: user.id)
        let accepted = await fetchPrivacyAcceptance(authUid: user.id)
        
        await MainActor.run {
            self.currentUser = AppUser(
                id: user.id,
                email: user.email,
                fullName: Self.stringFromUserMetadata(user.userMetadata["full_name"])
                    ?? Self.stringFromUserMetadata(user.userMetadata["name"]),
                privacyPolicyAccepted: accepted
            )
        }
        await refreshDisplayName()
        #else
        // Mock success for UI compilation
        try await Task.sleep(for: .seconds(1))
        self.currentUser = AppUser(id: UUID(), email: email, fullName: "Test User", privacyPolicyAccepted: true)
        await refreshDisplayName()
        #endif
    }
    
    /// Registers a new user with profile metadata.
    public func signUp(email: String, password: String, fullName: String) async throws {
        #if canImport(Supabase)
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(fullName)]
        )
        let user = response.user
        
        // Write record to users table with privacy acceptance (non-blocking in case email verification is active or RLS prevents immediate insert)
        struct UserRow: Encodable {
            let auth_uid: String
            let full_name: String
            let privacy_policy_accepted: Int
        }
        try? await client.from("users").insert(
            UserRow(auth_uid: user.id.uuidString, full_name: fullName, privacy_policy_accepted: 1)
        ).execute()
        
        // If email confirmation is required and session is nil, throw specific instruction
        if response.session == nil {
            throw NSError(
                domain: "SupabaseService",
                code: 201,
                userInfo: [NSLocalizedDescriptionKey: "Registration successful! A confirmation email has been sent to \(email). Please verify your email before signing in."]
            )
        }
        
        await MainActor.run {
            self.currentUser = AppUser(
                id: user.id,
                email: user.email,
                fullName: fullName,
                privacyPolicyAccepted: true
            )
        }
        await refreshDisplayName()
        #else
        try await Task.sleep(for: .seconds(1.2))
        self.currentUser = AppUser(id: UUID(), email: email, fullName: fullName, privacyPolicyAccepted: true)
        await refreshDisplayName()
        #endif
    }
    
    /// Loads the same display name shown on the Profile screen for Settings and other UI.
    public func refreshDisplayName() async {
        guard isAuthenticated else {
            displayName = "Guest Account"
            return
        }
        if let profileName = await getProfileName() {
            let trimmed = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                displayName = trimmed
                return
            }
        }
        if let authName = currentUser?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !authName.isEmpty {
            displayName = authName
            return
        }
        if let email = currentUserEmail?.components(separatedBy: "@").first, !email.isEmpty {
            displayName = email
            return
        }
        displayName = "CSI Devotional User"
    }
    
    private static func stringFromUserMetadata(_ value: Any?) -> String? {
        if let s = value as? String, !s.isEmpty { return s }
        #if canImport(Supabase)
        if let json = value as? AnyJSON, case .string(let s) = json, !s.isEmpty { return s }
        #endif
        return nil
    }
    
    /// Signs out the active user.
    public func signOut() async throws {
        #if canImport(Supabase)
        try await client.auth.signOut()
        #endif
        await MainActor.run {
            self.currentUser = nil
        }
        await refreshDisplayName()
    }
    
    /// Soft-deletes the account (profile flagged deleted; auth login is kept but blocked in-app).
    public func deleteUserAccount() async throws {
        guard currentUser != nil else { return }
        
        #if canImport(Supabase)
        do {
            try await client.rpc("delete_user_account").execute()
        } catch {
            if !Self.isPostDeleteAuthError(error) {
                throw error
            }
        }
        try? await client.auth.signOut()
        #else
        try await Task.sleep(for: .seconds(1.5))
        #endif
        
        await MainActor.run {
            self.currentUser = nil
        }
        await refreshDisplayName()
    }
    
    /// Detects auth errors that are expected after a successful account deletion,
    /// where the access token now points to a user that no longer exists.
    private static func isPostDeleteAuthError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("user_not_found")
            || message.contains("user not found")
            || message.contains("403")
            || message.contains("forbidden")
    }
    
    public func isAccountDeleted(authUid: UUID) async -> Bool {
        #if canImport(Supabase)
        do {
            let deleted: Bool = try await client.rpc("is_my_account_deleted").execute().value
            return deleted
        } catch {
            struct Row: Codable { let deleted: Bool? }
            do {
                let row: Row = try await client.from("users")
                    .select("deleted")
                    .eq("auth_uid", value: authUid.uuidString)
                    .single()
                    .execute()
                    .value
                return row.deleted == true
            } catch {
                return false
            }
        }
        #else
        return false
        #endif
    }
    
    /// Fetches this signed-in user's stored data (server-enforced: own rows only, 15-minute rate limit).
    public func exportMyDataJSON() async throws -> Data {
        #if canImport(Supabase)
        let response = try await client.rpc("export_my_data").execute()
        return response.data
        #else
        throw NSError(domain: "SupabaseService", code: 501, userInfo: [NSLocalizedDescriptionKey: "Export is unavailable in this build."])
        #endif
    }
    
    public func exportMyDataZipURL() async throws -> URL {
        let raw = try await exportMyDataJSON()
        let json = Self.prettyJSON(raw)
        let readme = Data("""
        CSI Hymns — your information

        This zip contains the data we store about your account, including user id, name, email, favourites, custom lists, support tickets, and consent records.

        Profile picture: none is stored in the database.

        """.utf8)
        let zip = SimpleZipArchive.make(files: [
            ("my-data.json", json),
            ("README.txt", readme)
        ])
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("csi-hymns-my-information-\(stamp).zip")
        try zip.write(to: url)
        return url
    }
    
    public static func isDataExportRateLimited(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("export_rate_limited")
            || message.contains("rate_limited")
            || message.contains("p0001")
    }
    
    private func ensureAccountIsActive(authUid: UUID) async throws {
        if await isAccountDeleted(authUid: authUid) {
            #if canImport(Supabase)
            try? await client.auth.signOut()
            #endif
            currentUser = nil
            await refreshDisplayName()
            throw NSError(
                domain: "SupabaseService",
                code: 410,
                userInfo: [NSLocalizedDescriptionKey: "This account has been deactivated. Contact support if you need help."]
            )
        }
    }
    
    private static func prettyJSON(_ data: Data) -> Data {
        var payload = data
        if let object = try? JSONSerialization.jsonObject(with: payload) {
            if let encoded = object as? String, let inner = encoded.data(using: .utf8) {
                payload = inner
            }
        }
        guard let object = try? JSONSerialization.jsonObject(with: payload),
              JSONSerialization.isValidJSONObject(object),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            return payload
        }
        return pretty
    }
    
    // MARK: - Synchronizations & Queries
    
    private func fetchPrivacyAcceptance(authUid: UUID) async -> Bool {
        #if canImport(Supabase)
        struct Profile: Codable {
            let privacyPolicyAccepted: Int?
            enum CodingKeys: String, CodingKey {
                case privacyPolicyAccepted = "privacy_policy_accepted"
            }
        }
        do {
            let profile: Profile = try await client.from("users")
                .select("privacy_policy_accepted")
                .eq("auth_uid", value: authUid.uuidString)
                .single()
                .execute()
                .value
            return (profile.privacyPolicyAccepted ?? 0) == 1
        } catch {
            print("SupabaseService: fetchPrivacyAcceptance failed or profile missing: \(error). Falling back to local consent.")
            return ConsentManager.shared.hasValidRequiredConsent
        }
        #else
        return ConsentManager.shared.hasValidRequiredConsent
        #endif
    }
    
    /// Sends a password reset email via Supabase Auth.
    public func sendPasswordResetEmail(_ email: String) async throws {
        #if canImport(Supabase)
        try await client.auth.resetPasswordForEmail(
            email,
            redirectTo: URL(string: "com.reyzie.hymns://callback")
        )
        #endif
    }
    
    /// Upserts the user's display name in `public.users`.
    public func upsertProfile(fullName: String) async throws {
        guard let user = currentUser else { return }
        #if canImport(Supabase)
        struct UserRow: Encodable {
            let auth_uid: String
            let full_name: String
        }
        try await client.from("users").upsert(
            UserRow(auth_uid: user.id.uuidString, full_name: fullName),
            onConflict: "auth_uid"
        ).execute()
        await MainActor.run {
            self.currentUser = AppUser(
                id: user.id,
                email: user.email,
                fullName: fullName,
                privacyPolicyAccepted: user.privacyPolicyAccepted
            )
        }
        await refreshDisplayName()
        #endif
    }
    
    /// Reads the profile display name from `public.users`.
    public func getProfileName() async -> String? {
        guard let user = currentUser else { return nil }
        #if canImport(Supabase)
        struct Profile: Codable { let full_name: String? }
        do {
            let row: Profile = try await client.from("users")
                .select("full_name")
                .eq("auth_uid", value: user.id.uuidString)
                .single()
                .execute()
                .value
            return row.full_name
        } catch {
            return user.fullName
        }
        #else
        return user.fullName
        #endif
    }
    
    /// Persists privacy consent (`0` or `1`) on the user profile row.
    public func setPrivacyPolicyAcceptedInProfile(_ accepted: Bool) async {
        guard let user = currentUser else { return }
        #if canImport(Supabase)
        let value = accepted ? 1 : 0
        struct ProfileCheck: Codable { let auth_uid: String? }
        struct InsertRow: Encodable {
            let auth_uid: String
            let full_name: String
            let privacy_policy_accepted: Int
        }
        struct UpdateRow: Encodable { let privacy_policy_accepted: Int }
        do {
            let existing: ProfileCheck? = try? await client.from("users")
                .select("auth_uid")
                .eq("auth_uid", value: user.id.uuidString)
                .single()
                .execute()
                .value
            if existing?.auth_uid == nil {
                try await client.from("users").insert(
                    InsertRow(auth_uid: user.id.uuidString, full_name: user.fullName ?? "", privacy_policy_accepted: value)
                ).execute()
            } else {
                try await client.from("users").update(UpdateRow(privacy_policy_accepted: value))
                    .eq("auth_uid", value: user.id.uuidString)
                    .execute()
            }
            await MainActor.run {
                self.currentUser = AppUser(
                    id: user.id,
                    email: user.email,
                    fullName: user.fullName,
                    privacyPolicyAccepted: accepted
                )
            }
        } catch {
            print("SupabaseService: setPrivacyPolicyAcceptedInProfile failed: \(error)")
        }
        #endif
    }
    
    /// Persists the DPDP consent artefact on the user profile row.
    public func syncConsentArtefact(
        requiredAccepted: Bool,
        analytics: Bool,
        push: Bool,
        version: String?,
        recordedAt: Date?,
        artefact: [String: Any]
    ) async {
        guard currentUser != nil else { return }
        await setPrivacyPolicyAcceptedInProfile(requiredAccepted)
        #if canImport(Supabase)
        guard let user = currentUser else { return }
        struct ConsentPayload: Encodable {
            let policy_version: String
            let recorded_at: String
            let language: String
            let privacy_accepted: Bool
            let terms_accepted: Bool
            let age_confirmed: Bool
            let analytics: Bool
            let push_notifications: Bool
            let notice: String
        }
        struct ConsentUpdate: Encodable {
            let terms_accepted: Int
            let analytics_consent: Bool
            let push_consent: Bool
            let consent_version: String?
            let consent_recorded_at: String?
            let consent_artefact: ConsentPayload
        }
        let iso = recordedAt.map { ISO8601DateFormatter().string(from: $0) } ?? ISO8601DateFormatter().string(from: Date())
        let payload = ConsentPayload(
            policy_version: version ?? ConsentManager.currentPolicyVersion,
            recorded_at: iso,
            language: (artefact["language"] as? String) ?? "en",
            privacy_accepted: requiredAccepted,
            terms_accepted: requiredAccepted,
            age_confirmed: requiredAccepted,
            analytics: analytics,
            push_notifications: push,
            notice: (artefact["notice"] as? String) ?? ""
        )
        do {
            try await client.from("users").update(ConsentUpdate(
                terms_accepted: requiredAccepted ? 1 : 0,
                analytics_consent: analytics,
                push_consent: push,
                consent_version: version,
                consent_recorded_at: iso,
                consent_artefact: payload
            ))
            .eq("auth_uid", value: user.id.uuidString)
            .execute()
        } catch {
            print("SupabaseService: syncConsentArtefact failed: \(error)")
        }
        #endif
    }
    
    /// After sign-in, push locally stored consent to Supabase.
    public func syncConsentFromLocalPrefs() async {
        await ConsentManager.shared.syncToProfile()
    }
    
    /// Legacy name used by older call sites.
    public func syncPrivacyPolicyFromLocalPrefs() async {
        await syncConsentFromLocalPrefs()
    }
    
    /// Syncs local bookmarks to Supabase on request.
    public func addFavorite(itemNumber: Int, itemType: String) async throws {
        guard let userId = currentUser?.id else { return }
        
        #if canImport(Supabase)
        struct FavoriteRow: Encodable {
            let user_id: String
            let item_number: Int
            let item_type: String
        }
        try await client.from("favorites").insert(
            FavoriteRow(user_id: userId.uuidString, item_number: itemNumber, item_type: itemType)
        ).execute()
        #endif
    }
    
    /// Removes bookmarks from remote servers.
    public func removeFavorite(itemNumber: Int, itemType: String) async throws -> Bool {
        guard let userId = currentUser?.id else { return true }
        
        #if canImport(Supabase)
        try await client.from("favorites")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("item_number", value: itemNumber)
            .eq("item_type", value: itemType)
            .execute()
        #endif
        return true
    }
    
    public struct RemoteFavorite: Codable, Sendable {
        public let itemNumber: Int
        public let itemType: String
        
        enum CodingKeys: String, CodingKey {
            case itemNumber = "item_number"
            case itemType = "item_type"
        }
    }
    
    /// Pulls all saved bookmarks for this user from remote database.
    public func fetchFavorites() async throws -> [RemoteFavorite] {
        guard let userId = currentUser?.id else { return [] }
        
        #if canImport(Supabase)
        let response: [RemoteFavorite] = try await client.from("favorites")
            .select("item_number, item_type")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return response
        #else
        return []
        #endif
    }
    
    // MARK: - Custom Categories Sync
    
    public struct RemoteCustomCategory: Codable, Sendable {
        public let id: Int
        public let name: String
    }
    
    private struct RemoteCustomCategorySong: Codable, Sendable {
        let songId: Int
        let songType: String
        enum CodingKeys: String, CodingKey {
            case songId = "song_id"
            case songType = "song_type"
        }
    }
    
    /// Splits a native song key ("hymn_5" / "keerthane_3") into its numeric id and type.
    static func parseSongKey(_ key: String) -> (id: Int, type: String)? {
        if key.hasPrefix("hymn_"), let n = Int(key.dropFirst("hymn_".count)) {
            return (n, "hymn")
        } else if key.hasPrefix("keerthane_"), let n = Int(key.dropFirst("keerthane_".count)) {
            return (n, "keerthane")
        }
        return nil
    }
    
    /// Fetches all non-deleted custom categories for the current user, merging their
    /// songs into the native `CustomCategory` shape (songIds like "hymn_5").
    public func fetchCustomCategoriesWithSongs() async throws -> [CustomCategory] {
        guard let userId = currentUser?.id else { return [] }
        #if canImport(Supabase)
        let categoryRows: [RemoteCustomCategory] = try await client.from("custom_categories")
            .select("id,name")
            .eq("user_id", value: userId.uuidString)
            .eq("deleted", value: 0)
            .order("updated_at", ascending: false)
            .execute()
            .value
        
        var result: [CustomCategory] = []
        for row in categoryRows {
            let songRows: [RemoteCustomCategorySong] = try await client.from("custom_category_songs")
                .select("song_id,song_type")
                .eq("user_id", value: userId.uuidString)
                .eq("category_id", value: row.id)
                .eq("deleted", value: 0)
                .order("created_at", ascending: false)
                .execute()
                .value
            let songIds = songRows.map { "\($0.songType)_\($0.songId)" }
            result.append(CustomCategory(id: String(row.id), name: row.name, songIds: songIds))
        }
        return result
        #else
        return []
        #endif
    }
    
    public func createCustomCategoryRemote(name: String) async throws -> Int? {
        guard let userId = currentUser?.id else { return nil }
        #if canImport(Supabase)
        struct InsertRow: Encodable { let user_id: String; let name: String }
        struct IdRow: Decodable { let id: Int }
        let inserted: IdRow = try await client.from("custom_categories")
            .insert(InsertRow(user_id: userId.uuidString, name: name))
            .select("id")
            .single()
            .execute()
            .value
        return inserted.id
        #else
        return nil
        #endif
    }
    
    public func renameCustomCategoryRemote(id: Int, name: String) async throws {
        guard let userId = currentUser?.id else { return }
        #if canImport(Supabase)
        struct UpdateRow: Encodable { let name: String }
        try await client.from("custom_categories")
            .update(UpdateRow(name: name))
            .eq("id", value: id)
            .eq("user_id", value: userId.uuidString)
            .execute()
        #endif
    }
    
    public func softDeleteCustomCategoryRemote(id: Int) async throws {
        guard let userId = currentUser?.id else { return }
        #if canImport(Supabase)
        struct UpdateRow: Encodable { let deleted: Int }
        try await client.from("custom_categories")
            .update(UpdateRow(deleted: 1))
            .eq("id", value: id)
            .eq("user_id", value: userId.uuidString)
            .execute()
        #endif
    }
    
    public func addSongToCustomCategoryRemote(categoryId: Int, songId: Int, songType: String) async throws {
        guard let userId = currentUser?.id else { return }
        #if canImport(Supabase)
        struct InsertRow: Encodable {
            let category_id: Int
            let user_id: String
            let song_id: Int
            let song_type: String
        }
        try await client.from("custom_category_songs")
            .insert(InsertRow(category_id: categoryId, user_id: userId.uuidString, song_id: songId, song_type: songType))
            .execute()
        #endif
    }
    
    public func removeSongFromCustomCategoryRemote(categoryId: Int, songId: Int, songType: String) async throws {
        guard let userId = currentUser?.id else { return }
        #if canImport(Supabase)
        struct UpdateRow: Encodable { let deleted: Int }
        try await client.from("custom_category_songs")
            .update(UpdateRow(deleted: 1))
            .eq("user_id", value: userId.uuidString)
            .eq("category_id", value: categoryId)
            .eq("song_id", value: songId)
            .eq("song_type", value: songType)
            .execute()
        #endif
    }
    
    /// Pushes local-only categories to Supabase after sign-in (skipping names that
    /// already exist remotely), then returns the authoritative remote set.
    public func migrateAndFetchCustomCategories(localCategories: [CustomCategory]) async throws -> [CustomCategory] {
        guard currentUser != nil else { return localCategories }
        #if canImport(Supabase)
        let existing = try await fetchCustomCategoriesWithSongs()
        let existingNames = Set(existing.map { $0.name.lowercased() })
        for local in localCategories {
            if existingNames.contains(local.name.lowercased()) { continue }
            guard let newId = try await createCustomCategoryRemote(name: local.name) else { continue }
            for key in local.songIds {
                guard let parsed = Self.parseSongKey(key) else { continue }
                try? await addSongToCustomCategoryRemote(categoryId: newId, songId: parsed.id, songType: parsed.type)
            }
        }
        return try await fetchCustomCategoriesWithSongs()
        #else
        return localCategories
        #endif
    }
    
    // MARK: - Native Apple & Google OAuth Actions
    
    @MainActor
    public func signInWithProvider(_ providerName: String) async throws {
        #if canImport(Supabase)
        let provider: Provider
        if providerName.lowercased() == "google" {
            provider = .google
        } else if providerName.lowercased() == "apple" {
            provider = .apple
        } else {
            throw NSError(domain: "Auth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unsupported OAuth provider: \(providerName)"])
        }
        
        let redirectURL = URL(string: "com.reyzie.hymns://callback")!
        let authorizationURL = try await client.auth.getOAuthSignInURL(
            provider: provider,
            redirectTo: redirectURL
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: "com.reyzie.hymns"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid callback URL."]))
                    return
                }
                
                Task {
                    do {
                        // Extract and set session from callback URL
                        try await self.client.auth.session(from: callbackURL)
                        
                        // Hydrate user profile details
                        let user = try await self.client.auth.session.user
                        try await self.ensureAccountIsActive(authUid: user.id)
                        let accepted = await self.fetchPrivacyAcceptance(authUid: user.id)
                        self.currentUser = AppUser(
                            id: user.id,
                            email: user.email,
                            fullName: Self.stringFromUserMetadata(user.userMetadata["full_name"])
                                ?? Self.stringFromUserMetadata(user.userMetadata["name"]),
                            privacyPolicyAccepted: accepted
                        )
                        await self.refreshDisplayName()
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            #if os(iOS)
            session.presentationContextProvider = PresentationAnchorProvider.shared
            #endif
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
        #else
        // Mock success in offline / simulator non-Supabase builds
        try await Task.sleep(for: .seconds(1.2))
        self.currentUser = AppUser(id: UUID(), email: "oauth@domain.com", fullName: "\(providerName) User", privacyPolicyAccepted: true)
        #endif
    }
    
    // MARK: - Native Sign In with Apple (FaceID/TouchID/System Dialog)
    
    @MainActor
    public func signInWithAppleNative() async throws {
        #if canImport(Supabase)
        print("SupabaseService: Initiating native Sign In with Apple authorization controller...")
        let appleResult = try await AppleSignInHelper.shared.startSignIn()
        
        print("SupabaseService: Received identity token from Apple. Exchanging with Supabase...")
        let response = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: appleResult.identityToken)
        )
        
        let user = response.user
        try await ensureAccountIsActive(authUid: user.id)
        let accepted = await fetchPrivacyAcceptance(authUid: user.id)
        let metadataName = Self.stringFromUserMetadata(user.userMetadata["full_name"])
            ?? Self.stringFromUserMetadata(user.userMetadata["name"])
        let resolvedName = metadataName ?? appleResult.fullName
        
        await MainActor.run {
            self.currentUser = AppUser(
                id: user.id,
                email: user.email,
                fullName: resolvedName,
                privacyPolicyAccepted: accepted
            )
        }
        
        if let appleName = appleResult.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !appleName.isEmpty {
            let existing = await getProfileName()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if existing.isEmpty {
                try? await upsertProfile(fullName: appleName)
            }
        }
        await refreshDisplayName()
        print("SupabaseService: Native Apple Sign In successful! User hydrated: \(user.email ?? "no email")")
        #else
        try await Task.sleep(for: .seconds(1.2))
        self.currentUser = AppUser(id: UUID(), email: "apple.native@domain.com", fullName: "Apple User", privacyPolicyAccepted: true)
        #endif
    }
}

#if os(iOS)
public final class PresentationAnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding, Sendable {
    public static let shared = PresentationAnchorProvider()
    
    @MainActor
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Native iOS Apple Sign In Delegate Helper
@MainActor
public final class AppleSignInHelper: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding, Sendable {
    public static let shared = AppleSignInHelper()
    
    private let continuationWrapper = ContinuationWrapper()
    
    public struct SignInResult: Sendable {
        public let identityToken: String
        public let fullName: String?
    }
    
    private final class ContinuationWrapper: @unchecked Sendable {
        var continuation: CheckedContinuation<SignInResult, Error>?
    }
    
    public func startSignIn() async throws -> SignInResult {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuationWrapper.continuation = continuation
            
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                continuationWrapper.continuation?.resume(throwing: NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse identity token from Apple."]))
                continuationWrapper.continuation = nil
                return
            }
            
            var fullName: String?
            if let personName = appleIDCredential.fullName {
                let parts = [personName.givenName, personName.familyName].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                if !parts.isEmpty { fullName = parts.joined(separator: " ") }
            }
            
            continuationWrapper.continuation?.resume(returning: SignInResult(identityToken: tokenString, fullName: fullName))
            continuationWrapper.continuation = nil
        } else {
            continuationWrapper.continuation?.resume(throwing: NSError(domain: "AppleSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unsupported credential type."]))
            continuationWrapper.continuation = nil
        }
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Authorization failed: \(error)")
        continuationWrapper.continuation?.resume(throwing: Self.friendlyError(from: error))
        continuationWrapper.continuation = nil
    }
    
    private static func friendlyError(from error: Error) -> Error {
        let nsError = error as NSError
        
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            return error
        }
        
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.unknown.rawValue {
            return NSError(
                domain: "AppleSignIn",
                code: nsError.code,
                userInfo: [NSLocalizedDescriptionKey: "Sign in with Apple couldn't start. Rebuild the app after enabling the Apple Sign In capability, or try Google sign-in. A physical device works best on iOS betas."]
            )
        }
        
        if nsError.domain == "AKAuthenticationError", nsError.code == -7026 {
            return NSError(
                domain: "AppleSignIn",
                code: -7026,
                userInfo: [NSLocalizedDescriptionKey: "Apple Sign In isn't available in this environment. Use a physical device or try Google sign-in."]
            )
        }
        
        return error
    }
    
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return UIWindow()
        }
        return window
    }
}
#endif
