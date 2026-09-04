import Foundation
import Observation

#if canImport(Supabase)
import Supabase
#endif

/// Carol churches repository — churches first, then songs (lyrics) or PDFs inside each church.
@MainActor
@Observable
public final class ChristmasCarolsService {
    public static let shared = ChristmasCarolsService()
    
    public var churches: [CarolChurch] = []
    public var songs: [CarolSong] = []
    public var pdfs: [CarolPdf] = []
    /// Legacy flat rows (GitHub seed / old table) until fully migrated.
    public var legacyCarols: [ChristmasCarol] = []
    
    public var isLoading = false
    public var lastErrorMessage: String?
    public var lastSuccessMessage: String?
    
    private static let pdfBucket = "carol-pdfs"
    private static let cacheFileName = "carol_library_cache.json"
    private static let remoteJSONURL = "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/carols_data.json"
    
    public static let adminEmails: Set<String> = [
        "reynoldclare29022902@gmail.com",
        "reynoldclare02@gmail.com",
        "reyziecrafts@gmail.com",
        "reynold.clare29022902@gmail.com"
    ]
    
    private struct LibraryCache: Codable {
        let churches: [CarolChurch]
        let songs: [CarolSong]
        let pdfs: [CarolPdf]
        let legacyCarols: [ChristmasCarol]
    }
    
    private init() {
        loadCache()
    }
    
    public var isAdmin: Bool {
        if AdminPrefs.isSudoAdminEnabled { return true }
        guard let email = SupabaseService.instance.currentUserEmail?.lowercased() else { return false }
        if Self.adminEmails.contains(email) { return true }
        return AdminPrefs.hasAnyAdminRole(
            currentUserEmail: email,
            adminEmailsConfig: AppConfigService.shared.config.adminEmails
        )
    }
    
    public func canDeleteChurch(_ church: CarolChurch) -> Bool {
        if isAdmin { return true }
        guard let uid = SupabaseService.instance.currentUser?.id else { return false }
        return church.createdByUserId == uid
    }
    
    public func canDeleteSong(_ song: CarolSong) -> Bool {
        if isAdmin { return true }
        guard let uid = SupabaseService.instance.currentUser?.id else { return false }
        return song.createdByUserId == uid
    }
    
    public func canDeletePdf(_ pdf: CarolPdf) -> Bool {
        if isAdmin { return true }
        guard let uid = SupabaseService.instance.currentUser?.id else { return false }
        return pdf.createdByUserId == uid
    }
    
    public func songs(for churchId: UUID) -> [CarolSong] {
        songs.filter { $0.churchId == churchId }
            .sorted { lhs, rhs in
                let a = Int(lhs.songNumber ?? "") ?? Int.max
                let b = Int(rhs.songNumber ?? "") ?? Int.max
                if a != b { return a < b }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }
    
    public func pdfs(for churchId: UUID) -> [CarolPdf] {
        pdfs.filter { $0.churchId == churchId }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    
    public func church(byId id: UUID) -> CarolChurch? {
        churches.first { $0.id == id }
    }
    
    public func legacyCarols(forChurchName name: String) -> [ChristmasCarol] {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return legacyCarols.filter {
            $0.churchName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key
        }
    }
    
    // MARK: - Fetch
    
    public func fetchParishCarols(forceGitHub: Bool = false) async throws {
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }
        
        legacyCarols = await loadLegacySources(forceGitHub: forceGitHub)
        
        let remoteChurches = await loadChurchesFromSupabase()
        let remoteSongs = await loadSongsFromSupabase()
        let remotePdfs = await loadPdfsFromSupabase()
        
        if !remoteChurches.isEmpty || !remoteSongs.isEmpty || !remotePdfs.isEmpty {
            churches = remoteChurches
            songs = remoteSongs
            pdfs = remotePdfs
        } else if churches.isEmpty {
            churches = buildLegacyChurches(from: legacyCarols)
        }
        
        saveCache()
        print("ChristmasCarolsService: \(churches.count) churches, \(songs.count) songs, \(pdfs.count) PDFs, \(legacyCarols.count) legacy")
    }
    
    public func syncAfterSignIn() async {
        try? await fetchParishCarols(forceGitHub: true)
    }
    
    // MARK: - Create
    
    public func createChurch(name: String, description: String? = nil) async throws -> CarolChurch {
        guard let userId = SupabaseService.instance.currentUser?.id else {
            throw CarolsServiceError.notAuthenticated
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CarolsServiceError.invalidInput("Church name is required.") }
        
        let church = CarolChurch(
            name: trimmed,
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            createdByUserId: userId
        )
        
        #if canImport(Supabase)
        try await SupabaseService.instance.client
            .from("carol_churches")
            .insert(church)
            .execute()
        #endif
        
        churches.insert(church, at: 0)
        saveCache()
        lastSuccessMessage = "Church created."
        return church
    }
    
    public func addSong(
        churchId: UUID,
        title: String,
        songNumber: String?,
        lyricsKannada: String,
        lyricsEnglish: String,
        scale: String = "C Major"
    ) async throws -> CarolSong {
        guard let userId = SupabaseService.instance.currentUser?.id else {
            throw CarolsServiceError.notAuthenticated
        }
        
        let joinedLyrics = lyricsEnglish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? lyricsKannada
            : "\(lyricsKannada)\n\n---\n\nEnglish Translation:\n\(lyricsEnglish)"
        
        guard !joinedLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CarolsServiceError.invalidInput("Lyrics are required for a song.")
        }
        
        let song = CarolSong(
            churchId: churchId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            songNumber: songNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
            lyrics: joinedLyrics,
            scale: scale,
            createdByUserId: userId
        )
        
        #if canImport(Supabase)
        try await SupabaseService.instance.client
            .from("carol_songs")
            .insert(song)
            .execute()
        #endif
        
        songs.insert(song, at: 0)
        saveCache()
        lastSuccessMessage = "Song added."
        return song
    }
    
    public func addPdf(
        churchId: UUID,
        title: String,
        songNumber: String?,
        pdfData: Data
    ) async throws -> CarolPdf {
        guard let userId = SupabaseService.instance.currentUser?.id else {
            throw CarolsServiceError.notAuthenticated
        }
        
        let pdfId = UUID()
        let pdfUrl = try await uploadCarolPDF(data: pdfData, fileId: pdfId.uuidString.lowercased())
        
        let pdf = CarolPdf(
            id: pdfId,
            churchId: churchId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            songNumber: songNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
            pdfUrl: pdfUrl,
            createdByUserId: userId
        )
        
        #if canImport(Supabase)
        try await SupabaseService.instance.client
            .from("carol_pdfs")
            .insert(pdf)
            .execute()
        #endif
        
        pdfs.insert(pdf, at: 0)
        saveCache()
        lastSuccessMessage = "PDF uploaded."
        return pdf
    }
    
    // MARK: - Delete
    
    public func deleteChurch(id: UUID) async throws {
        guard let church = churches.first(where: { $0.id == id }), canDeleteChurch(church) else {
            throw CarolsServiceError.notAuthorized
        }
        #if canImport(Supabase)
        try await SupabaseService.instance.client
            .from("carol_churches")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        #endif
        churches.removeAll { $0.id == id }
        songs.removeAll { $0.churchId == id }
        pdfs.removeAll { $0.churchId == id }
        saveCache()
        lastSuccessMessage = "Church deleted."
    }
    
    public func deleteSong(id: UUID) async throws {
        guard let song = songs.first(where: { $0.id == id }), canDeleteSong(song) else {
            throw CarolsServiceError.notAuthorized
        }
        #if canImport(Supabase)
        try await SupabaseService.instance.client
            .from("carol_songs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        #endif
        songs.removeAll { $0.id == id }
        saveCache()
        lastSuccessMessage = "Song deleted."
    }
    
    public func deletePdf(id: UUID) async throws {
        guard let pdf = pdfs.first(where: { $0.id == id }), canDeletePdf(pdf) else {
            throw CarolsServiceError.notAuthorized
        }
        #if canImport(Supabase)
        try await SupabaseService.instance.client
            .from("carol_pdfs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        #endif
        pdfs.removeAll { $0.id == id }
        saveCache()
        lastSuccessMessage = "PDF deleted."
    }
    
    // MARK: - Storage
    
    public func uploadCarolPDF(data: Data, fileId: String) async throws -> String {
        #if canImport(Supabase)
        let path = "\(fileId).pdf"
        let storage = SupabaseService.instance.client.storage.from(Self.pdfBucket)
        try await storage.upload(path, data: data, options: FileOptions(contentType: "application/pdf", upsert: true))
        return try storage.getPublicURL(path: path).absoluteString
        #else
        return ""
        #endif
    }
    
    // MARK: - Supabase loaders
    
    private func loadChurchesFromSupabase() async -> [CarolChurch] {
        #if canImport(Supabase)
        do {
            let rows: [CarolChurch] = try await SupabaseService.instance.client
                .from("carol_churches")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows
        } catch {
            print("ChristmasCarolsService: carol_churches load failed: \(error)")
            if churches.isEmpty { lastErrorMessage = "Couldn't load churches. Pull to retry." }
            return churches
        }
        #else
        return []
        #endif
    }
    
    private func loadSongsFromSupabase() async -> [CarolSong] {
        #if canImport(Supabase)
        do {
            let rows: [CarolSong] = try await SupabaseService.instance.client
                .from("carol_songs")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows
        } catch {
            print("ChristmasCarolsService: carol_songs load failed: \(error)")
            return songs
        }
        #else
        return []
        #endif
    }
    
    private func loadPdfsFromSupabase() async -> [CarolPdf] {
        #if canImport(Supabase)
        do {
            let rows: [CarolPdf] = try await SupabaseService.instance.client
                .from("carol_pdfs")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows
        } catch {
            print("ChristmasCarolsService: carol_pdfs load failed: \(error)")
            return pdfs
        }
        #else
        return []
        #endif
    }
    
    private func loadLegacySources(forceGitHub: Bool) async -> [ChristmasCarol] {
        var all: [ChristmasCarol] = []
        all.append(contentsOf: ChristmasCarol.parseJSONArray(Data()))
        if let url = URL(string: Self.remoteJSONURL) {
            do {
                let (data, resp) = try await URLSession.shared.data(from: url)
                if (resp as? HTTPURLResponse)?.statusCode == 200 {
                    all.append(contentsOf: ChristmasCarol.parseJSONArray(data))
                }
            } catch {
                print("ChristmasCarolsService: GitHub JSON failed: \(error)")
            }
        }
        #if canImport(Supabase)
        do {
            let response = try await SupabaseService.instance.client
                .from("christmas_carols")
                .select()
                .execute()
            all.append(contentsOf: ChristmasCarol.parseJSONArray(response.data))
        } catch {
            print("ChristmasCarolsService: legacy christmas_carols load failed: \(error)")
        }
        #endif
        return dedupeLegacy(all)
    }
    
    private func buildLegacyChurches(from legacy: [ChristmasCarol]) -> [CarolChurch] {
        var map: [String: CarolChurch] = [:]
        for carol in legacy {
            let key = carol.churchName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, map[key] == nil else { continue }
            let owner = UUID(uuidString: carol.createdByUserId ?? "") ?? UUID()
            map[key] = CarolChurch(
                id: UUID(uuidString: carol.id) ?? UUID(),
                name: carol.churchName.trimmingCharacters(in: .whitespacesAndNewlines),
                createdByUserId: owner,
                createdAt: carol.createdAt
            )
        }
        return map.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private func dedupeLegacy(_ carols: [ChristmasCarol]) -> [ChristmasCarol] {
        var map: [String: ChristmasCarol] = [:]
        for carol in carols {
            let key = carol.id.lowercased()
            if let existing = map[key] {
                let d0 = existing.updatedAt ?? existing.createdAt
                let d1 = carol.updatedAt ?? carol.createdAt
                if d1 >= d0 { map[key] = carol }
            } else {
                map[key] = carol
            }
        }
        return Array(map.values)
    }
    
    // MARK: - Cache
    
    private func loadCache() {
        guard let url = cacheFileURL(),
              let data = try? Data(contentsOf: url),
              let cached = try? JSONDecoder().decode(LibraryCache.self, from: data) else { return }
        churches = cached.churches
        songs = cached.songs
        pdfs = cached.pdfs
        legacyCarols = cached.legacyCarols
    }
    
    private func saveCache() {
        let payload = LibraryCache(churches: churches, songs: songs, pdfs: pdfs, legacyCarols: legacyCarols)
        guard let url = cacheFileURL(),
              let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: url, options: .atomic)
    }
    
    private func cacheFileURL() -> URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(Self.cacheFileName)
    }
}

public enum CarolsServiceError: LocalizedError {
    case notAuthenticated
    case notAuthorized
    case invalidInput(String)
    case pdfReadFailed
    case pdfUploadFailed(String)
    case metadataInsertFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Please sign in to continue."
        case .notAuthorized: return "You can only delete items you uploaded. Admins can delete anything."
        case .invalidInput(let msg): return msg
        case .pdfReadFailed: return "Couldn't read the selected PDF file."
        case .pdfUploadFailed(let detail): return "PDF upload failed: \(detail)"
        case .metadataInsertFailed(let detail): return "Couldn't save: \(detail)"
        }
    }
}
