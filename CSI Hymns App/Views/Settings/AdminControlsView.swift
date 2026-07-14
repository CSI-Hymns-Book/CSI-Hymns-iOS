import SwiftUI
import PhotosUI

#if canImport(Supabase)
import Supabase
#endif

public struct AdminControlsView: View {
    @State private var theme = ThemeManager.shared
    @State private var isAuthorized: Bool? = nil
    @State private var isLoadingAccess = true
    
    public init() {}
    
    public var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            
            if theme.activeTheme != .amoled {
                theme.backgroundGradient.ignoresSafeArea()
            }
            
            VStack {
                if isLoadingAccess {
                    ProgressView("Checking Authorization...")
                        .tint(theme.textPrimary)
                } else if isAuthorized == true {
                    adminMenuView
                } else {
                    accessDeniedView
                }
            }
        }
        .navigationTitle("Admin Panel")
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await checkAdminAccess()
        }
    }
    
    private var adminMenuView: some View {
        ScrollView {
            VStack(spacing: 20) {
                NavigationLink(destination: AdminLyricCorrectionView()) {
                    menuCard(
                        title: "Lyric Correction",
                        subtitle: "Directly modify stanzas, bilingual texts, and signatures.",
                        systemImage: "pencil.and.outline",
                        color: Color.blue
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: AdminAnnouncementsView()) {
                    menuCard(
                        title: "Announcements Manager",
                        subtitle: "Trigger, modify, or archive dynamic in-app announcements.",
                        systemImage: "megaphone.fill",
                        color: Color.orange
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: AdminConfigManagerView()) {
                    menuCard(
                        title: "App Configuration",
                        subtitle: "Configure global features, force updates, and system flags.",
                        systemImage: "gearshape.fill",
                        color: Color.green
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
    }
    
    private func menuCard(title: String, subtitle: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 56, height: 56)
                
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(theme.textSecondary.opacity(0.5))
        }
        .padding()
        .background(theme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
    }
    
    private var accessDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            Text("Access Denied")
                .font(.title2.bold())
                .foregroundColor(theme.textPrimary)
            
            Text("You must be signed in with an authorized developer email address to view these controls.")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
    
    private func checkAdminAccess() async {
        guard let currentUserEmail = await MainActor.run(body: { SupabaseService.instance.currentUserEmail }) else {
            isAuthorized = false
            isLoadingAccess = false
            return
        }
        
        let localAllowed = ChristmasCarolsService.adminEmails
        if localAllowed.contains(currentUserEmail.lowercased()) {
            isAuthorized = true
            isLoadingAccess = false
            return
        }
        
        #if canImport(Supabase)
        do {
            let client = SupabaseService.instance.client
            let rows: [AppConfigRow] = try await client.from("app_config")
                .select("key, value")
                .eq("key", value: "admin_emails")
                .execute()
                .value
            
            if let first = rows.first {
                let emailsStr = first.value.stringValue
                let emailsList = emailsStr.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                
                if emailsList.contains(currentUserEmail.lowercased()) {
                    isAuthorized = true
                    isLoadingAccess = false
                    return
                }
            }
        } catch {
            print("AdminControlsView: Error fetching admin emails: \(error)")
        }
        #endif
        
        isAuthorized = false
        isLoadingAccess = false
    }
}

// MARK: - Sub Panel 1: Lyric Correction
struct AdminLyricCorrectionView: View {
    @State private var theme = ThemeManager.shared
    @State private var selectedTab = 0 // 0: Hymns, 1: Keerthanes, 2: M.T. Hymns, 3: Order of Service
    @State private var searchQuery = ""
    
    // Loaded lists
    @State private var hymns: [Hymn] = []
    @State private var keerthanes: [Hymn] = []
    @State private var mtHymns: [Hymn] = []
    @State private var liturgies: [OrderPage] = []
    
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var saveSuccess = false
    @State private var errorMessage: String? = nil
    
    // Active editing targets
    @State private var editingSong: Hymn? = nil
    @State private var editingLiturgy: OrderPage? = nil
    
    let tabs = ["Hymns", "Keerthanes", "M.T. Hymns", "Order of Service"]
    
    var filteredHymns: [Hymn] {
        let list: [Hymn]
        switch selectedTab {
        case 0: list = hymns
        case 1: list = keerthanes
        case 2: list = mtHymns
        default: list = []
        }
        if searchQuery.isEmpty {
            return list.sorted(by: { $0.number < $1.number })
        }
        return list.filter {
            "\($0.number)".contains(searchQuery) ||
            $0.title.localizedCaseInsensitiveContains(searchQuery) ||
            $0.lyricsKannada.localizedCaseInsensitiveContains(searchQuery) ||
            $0.lyricsEnglish.localizedCaseInsensitiveContains(searchQuery)
        }.sorted(by: { $0.number < $1.number })
    }
    
    var filteredLiturgies: [OrderPage] {
        if searchQuery.isEmpty {
            return liturgies
        }
        return liturgies.filter {
            "\($0.pageNo)".contains(searchQuery) ||
            ($0.title ?? "").localizedCaseInsensitiveContains(searchQuery) ||
            $0.content.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            
            if theme.activeTheme != .amoled {
                theme.backgroundGradient.ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Custom Frosted Segmented Tab Picker
                Picker("Tabs", selection: $selectedTab) {
                    ForEach(0..<tabs.count, id: \.self) { idx in
                        Text(tabs[idx]).tag(idx)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(theme.textSecondary)
                    TextField("Search by number, title, or lyrics...", text: $searchQuery)
                        .font(.system(size: 15))
                        .foregroundColor(theme.textPrimary)
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(theme.cardBackground.opacity(0.6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.cardStroke, lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                if isLoading {
                    Spacer()
                    ProgressView("Syncing remote data vault...")
                        .tint(theme.accentColor)
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                } else {
                    List {
                        if selectedTab < 3 {
                            ForEach(filteredHymns) { song in
                                Button(action: {
                                    editingSong = song
                                }) {
                                    HStack(spacing: 16) {
                                        Text("\(song.number)")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(theme.accentColor)
                                            .frame(width: 44, alignment: .leading)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(song.title)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(theme.textPrimary)
                                            if !song.signature.isEmpty {
                                                Text(song.signature)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(theme.textSecondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "square.and.pencil")
                                            .foregroundColor(theme.textSecondary.opacity(0.7))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(theme.cardBackground.opacity(0.6))
                            }
                        } else {
                            ForEach(filteredLiturgies) { liturgy in
                                Button(action: {
                                    editingLiturgy = liturgy
                                }) {
                                    HStack(spacing: 16) {
                                        Text("\(liturgy.pageNo)")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(theme.accentColor)
                                            .frame(width: 44, alignment: .leading)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(liturgy.title ?? "Liturgy Page")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(theme.textPrimary)
                                            Text(liturgy.type.capitalized)
                                                .font(.system(size: 12))
                                                .foregroundColor(theme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "square.and.pencil")
                                            .foregroundColor(theme.textSecondary.opacity(0.7))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(theme.cardBackground.opacity(0.6))
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            
            // Saving Loader Overlay
            if isSaving {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Text("Pushing commit to remote GitHub vault...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(Color.black.opacity(0.75))
                .cornerRadius(16)
            }
        }
        .navigationTitle("Lyric Correction")
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        .task {
            await loadAllData()
        }
        .sheet(item: $editingSong) { song in
            SongEditorView(song: song, category: tabs[selectedTab]) { updated in
                let currentCategory = tabs[selectedTab]
                try await saveSongAction(updated: updated, category: currentCategory)
                
                await MainActor.run {
                    switch currentCategory {
                    case "Hymns":
                        if let idx = hymns.firstIndex(where: { $0.number == updated.number }) {
                            hymns[idx] = updated
                        }
                    case "Keerthanes":
                        if let idx = keerthanes.firstIndex(where: { $0.number == updated.number }) {
                            keerthanes[idx] = updated
                        }
                    default:
                        if let idx = mtHymns.firstIndex(where: { $0.number == updated.number }) {
                            mtHymns[idx] = updated
                        }
                    }
                    saveSuccess = true
                    // editingSong = nil is handled by the dismiss() inside SongEditorView
                }
            }
        }
        .sheet(item: $editingLiturgy) { liturgy in
            LiturgyEditorView(liturgy: liturgy) { updated in
                try await saveLiturgyAction(updated: updated)
                
                await MainActor.run {
                    if let idx = liturgies.firstIndex(where: { $0.pageNo == updated.pageNo }) {
                        liturgies[idx] = updated
                    }
                    saveSuccess = true
                }
            }
        }
        .alert("Status", isPresented: $saveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Vault updated successfully and pushed to remote repository.")
        }
        .overlay {
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red.opacity(0.9))
                    .cornerRadius(8)
                    .padding()
            }
        }
    }
    
    private func loadAllData() async {
        isLoading = true
        errorMessage = nil
        
        // 1. Fetch Hymns
        do {
            let url = URL(string: "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/hymns_data.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            self.hymns = try JSONDecoder().decode([Hymn].self, from: data)
        } catch {
            print("Admin: Failed fetching remote hymns, falling back to local: \(error)")
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let cacheFile = cacheDir.appendingPathComponent("hymn_data_cache.json")
            if let cachedData = try? Data(contentsOf: cacheFile),
               let decoded = try? JSONDecoder().decode([Hymn].self, from: cachedData) {
                self.hymns = decoded
            } else if let bundleUrl = Bundle.main.url(forResource: "hymns_data", withExtension: "json"),
                      let bundleData = try? Data(contentsOf: bundleUrl),
                      let decoded = try? JSONDecoder().decode([Hymn].self, from: bundleData) {
                self.hymns = decoded
            }
        }
        
        // 2. Fetch Keerthanes
        do {
            let url = URL(string: "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/keerthane_data.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            self.keerthanes = try JSONDecoder().decode([Hymn].self, from: data)
        } catch {
            print("Admin: Failed fetching remote keerthanes, falling back to local: \(error)")
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let cacheFile = cacheDir.appendingPathComponent("keerthane_data_cache.json")
            if let cachedData = try? Data(contentsOf: cacheFile),
               let decoded = try? JSONDecoder().decode([Hymn].self, from: cachedData) {
                self.keerthanes = decoded
            } else if let bundleUrl = Bundle.main.url(forResource: "keerthane_data", withExtension: "json"),
                      let bundleData = try? Data(contentsOf: bundleUrl),
                      let decoded = try? JSONDecoder().decode([Hymn].self, from: bundleData) {
                self.keerthanes = decoded
            }
        }
        
        // 3. Fetch MT Hymns
        do {
            let url = URL(string: "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/mangalore_hymns_data.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            self.mtHymns = try JSONDecoder().decode([Hymn].self, from: data)
        } catch {
            print("Admin: Failed fetching remote mt, falling back to local: \(error)")
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let cacheFile = cacheDir.appendingPathComponent("mangalore_data_cache.json")
            if let cachedData = try? Data(contentsOf: cacheFile),
               let decoded = try? JSONDecoder().decode([Hymn].self, from: cachedData) {
                self.mtHymns = decoded
            } else if let bundleUrl = Bundle.main.url(forResource: "mangalore_hymns_data", withExtension: "json"),
                      let bundleData = try? Data(contentsOf: bundleUrl),
                      let decoded = try? JSONDecoder().decode([Hymn].self, from: bundleData) {
                self.mtHymns = decoded
            }
        }
        
        // 4. Fetch Order of Service (Liturgies)
        do {
            let url = URL(string: "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/refs/heads/main/order-of-service_data.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            self.liturgies = try OrderPage.parsePages(from: data)
        } catch {
            print("Admin: Failed fetching remote liturgies, falling back to local: \(error)")
            if let cachedData = UserDefaults.standard.data(forKey: "orderOfServiceData"),
               let decoded = try? OrderPage.parsePages(from: cachedData) {
                self.liturgies = decoded
            } else if let bundleUrl = Bundle.main.url(forResource: "order-of-service_data", withExtension: "json"),
                      let bundleData = try? Data(contentsOf: bundleUrl),
                      let decoded = try? OrderPage.parsePages(from: bundleData) {
                self.liturgies = decoded
            }
        }
        
        isLoading = false
    }
    
    private func saveSongAction(updated: Hymn, category: String) async throws {
        let path: String
        let cacheName: String
        let jsonUrl: String
        
        switch category {
        case "Hymns":
            path = "hymns_data.json"
            cacheName = "hymn_data_cache.json"
            jsonUrl = "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/hymns_data.json"
        case "Keerthanes":
            path = "keerthane_data.json"
            cacheName = "keerthane_data_cache.json"
            jsonUrl = "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/keerthane_data.json"
        default:
            path = "mangalore_hymns_data.json"
            cacheName = "mangalore_data_cache.json"
            jsonUrl = "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/mangalore_hymns_data.json"
        }
        
        let url = URL(string: jsonUrl)!
        let (data, _) = try await URLSession.shared.data(from: url)
        var decoded = try JSONDecoder().decode([Hymn].self, from: data)
        
        if let index = decoded.firstIndex(where: { $0.number == updated.number }) {
            decoded[index] = updated
        } else {
            throw NSError(domain: "Admin", code: 404, userInfo: [NSLocalizedDescriptionKey: "Song not found on repository"])
        }
        
        let encodedData = try JSONEncoder().encode(decoded)
        guard let jsonString = String(data: encodedData, encoding: .utf8) else {
            throw NSError(domain: "Admin", code: 500, userInfo: [NSLocalizedDescriptionKey: "Serialization failure"])
        }
        
        var gitToken = ""
        #if canImport(Supabase)
        let client = SupabaseService.instance.client
        let rows: [AppConfigRow] = try await client.from("app_config")
            .select("key, value")
            .eq("key", value: "github_token")
            .execute()
            .value
        gitToken = rows.first?.value.stringValue ?? ""
        #endif
        
        guard !gitToken.isEmpty else {
            throw NSError(domain: "Admin", code: 403, userInfo: [NSLocalizedDescriptionKey: "github_token config missing"])
        }
        
        let commitMessage = "Correct lyrics for \(category) \(updated.number)"
        if let pushError = await GitHubSyncService.shared.pushFileToGitHub(
            token: gitToken,
            repo: "Reynold29/csi-hymns-vault",
            filePath: path,
            content: jsonString,
            commitMessage: commitMessage
        ) {
            throw NSError(domain: "Admin", code: 500, userInfo: [NSLocalizedDescriptionKey: "GitHub Sync: \(pushError)"])
        }
        
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheFileUrl = cacheDirectory.appendingPathComponent(cacheName)
        try encodedData.write(to: cacheFileUrl)
    }
    
    private func saveLiturgyAction(updated: OrderPage) async throws {
        let path = "order-of-service_data.json"
        let jsonUrl = "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/order-of-service_data.json"
        
        let url = URL(string: jsonUrl)!
        let (data, _) = try await URLSession.shared.data(from: url)
        
        var decoded = try OrderPage.parsePages(from: data)
        
        if let index = decoded.firstIndex(where: { $0.pageNo == updated.pageNo }) {
            decoded[index] = updated
        } else {
            throw NSError(domain: "Admin", code: 404, userInfo: [NSLocalizedDescriptionKey: "Liturgy not found on repository"])
        }
        
        let encodedData = try JSONEncoder().encode(decoded)
        guard let jsonString = String(data: encodedData, encoding: .utf8) else {
            throw NSError(domain: "Admin", code: 500, userInfo: [NSLocalizedDescriptionKey: "Serialization failure"])
        }
        
        var gitToken = ""
        #if canImport(Supabase)
        let client = SupabaseService.instance.client
        let rows: [AppConfigRow] = try await client.from("app_config")
            .select("key, value")
            .eq("key", value: "github_token")
            .execute()
            .value
        gitToken = rows.first?.value.stringValue ?? ""
        #endif
        
        guard !gitToken.isEmpty else {
            throw NSError(domain: "Admin", code: 403, userInfo: [NSLocalizedDescriptionKey: "github_token config missing"])
        }
        
        let commitMessage = "Correct liturgy Order of Service page \(updated.pageNo)"
        if let pushError = await GitHubSyncService.shared.pushFileToGitHub(
            token: gitToken,
            repo: "Reynold29/csi-hymns-vault",
            filePath: path,
            content: jsonString,
            commitMessage: commitMessage
        ) {
            throw NSError(domain: "Admin", code: 500, userInfo: [NSLocalizedDescriptionKey: "GitHub Sync: \(pushError)"])
        }
        
        // Persist cache locally in userdefaults (same key OrderOfServiceListView checks)
        UserDefaults.standard.set(encodedData, forKey: "orderOfServiceData")
        NotificationCenter.default.post(name: Notification.Name("csi_liturgies_refreshed"), object: nil)
    }
}

// MARK: - Sub Panel 1a: Song Editor View Modal Sheet
struct SongEditorView: View {
    let song: Hymn
    let category: String
    let onSave: (Hymn) async throws -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var theme = ThemeManager.shared
    @State private var title: String
    @State private var signature: String
    @State private var lyricsKannada: String
    @State private var lyricsEnglish: String
    
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    
    init(song: Hymn, category: String, onSave: @escaping (Hymn) async throws -> Void) {
        self.song = song
        self.category = category
        self.onSave = onSave
        _title = State(initialValue: song.title)
        _signature = State(initialValue: song.signature)
        _lyricsKannada = State(initialValue: song.lyricsKannada)
        _lyricsEnglish = State(initialValue: song.lyricsEnglish)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .listRowBackground(theme.cardBackground)
                    }
                    
                    Section(header: Text("Details").foregroundColor(theme.textSecondary)) {
                        LabeledContent("Song Number", value: "\(song.number)")
                        TextField("Title", text: $title)
                        TextField("Signature", text: $signature)
                    }
                    .listRowBackground(theme.cardBackground)
                    
                    Section(header: Text("Lyrics (Kannada)").foregroundColor(theme.textSecondary)) {
                        TextEditor(text: $lyricsKannada)
                            .frame(minHeight: 180)
                            .font(.system(size: 15, design: .rounded))
                    }
                    .listRowBackground(theme.cardBackground)
                    
                    Section(header: Text("Lyrics (English)").foregroundColor(theme.textSecondary)) {
                        TextEditor(text: $lyricsEnglish)
                            .frame(minHeight: 180)
                            .font(.system(size: 15, design: .rounded))
                    }
                    .listRowBackground(theme.cardBackground)
                }
                .foregroundColor(theme.textPrimary)
                .scrollContentBackground(.hidden)
                .background(theme.backgroundColor)
                .disabled(isSaving)
                
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("Saving details to vault...")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                }
            }
            .navigationTitle("Edit \(category) #\(song.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentColor)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        errorMessage = nil
                        
                        let updated = Hymn(
                            number: song.number,
                            title: title,
                            signature: signature,
                            lyricsKannada: lyricsKannada,
                            lyricsEnglish: lyricsEnglish,
                            type: song.type,
                            category: song.category,
                            kannadaCategory: song.kannadaCategory
                        )
                        
                        Task {
                            do {
                                try await onSave(updated)
                                await MainActor.run {
                                    isSaving = false
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    isSaving = false
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }
                    .foregroundColor(theme.accentColor)
                    .bold()
                    .disabled(isSaving)
                }
            }
        }
    }
}

// MARK: - Sub Panel 1b: Liturgy Editor View Modal Sheet
struct LiturgyEditorView: View {
    let liturgy: OrderPage
    let onSave: (OrderPage) async throws -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var theme = ThemeManager.shared
    @State private var title: String
    @State private var content: String
    @State private var type: String
    
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    
    init(liturgy: OrderPage, onSave: @escaping (OrderPage) async throws -> Void) {
        self.liturgy = liturgy
        self.onSave = onSave
        _title = State(initialValue: liturgy.title ?? "")
        _content = State(initialValue: liturgy.content)
        _type = State(initialValue: liturgy.type)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .listRowBackground(theme.cardBackground)
                    }
                    
                    Section(header: Text("Details").foregroundColor(theme.textSecondary)) {
                        LabeledContent("Page Number", value: "\(liturgy.pageNo)")
                        TextField("Title", text: $title)
                        Picker("Type", selection: $type) {
                            Text("Regular").tag("regular")
                            Text("Festival").tag("festival")
                        }
                    }
                    .listRowBackground(theme.cardBackground)
                    
                    Section(header: Text("Content").foregroundColor(theme.textSecondary)) {
                        TextEditor(text: $content)
                            .frame(minHeight: 300)
                            .font(.system(size: 14, design: .rounded))
                    }
                    .listRowBackground(theme.cardBackground)
                }
                .foregroundColor(theme.textPrimary)
                .scrollContentBackground(.hidden)
                .background(theme.backgroundColor)
                .disabled(isSaving)
                
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("Saving liturgy to vault...")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                }
            }
            .navigationTitle("Edit Liturgy #\(liturgy.pageNo)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(theme.accentColor)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        errorMessage = nil
                        
                        let updated = OrderPage(
                            pageNo: liturgy.pageNo,
                            title: title.isEmpty ? nil : title,
                            content: content,
                            type: type
                        )
                        
                        Task {
                            do {
                                try await onSave(updated)
                                await MainActor.run {
                                    isSaving = false
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    isSaving = false
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }
                    .foregroundColor(theme.accentColor)
                    .bold()
                    .disabled(isSaving)
                }
            }
        }
    }
}

// MARK: - Sub Panel 2: Announcements Manager
struct AdminAnnouncementsView: View {
    @State private var theme = ThemeManager.shared
    @State private var announcements: [InAppMessage] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            
            if theme.activeTheme != .amoled {
                theme.backgroundGradient.ignoresSafeArea()
            }
            
            VStack {
                if isLoading {
                    ProgressView().tint(theme.textPrimary)
                } else if announcements.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "megaphone")
                            .font(.system(size: 48))
                            .foregroundColor(theme.textSecondary)
                        Text("No Announcements")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                    }
                } else {
                    List {
                        ForEach(announcements) { ann in
                            NavigationLink(destination: EditAnnouncementView(announcement: ann)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(ann.title)
                                            .font(.headline)
                                            .foregroundColor(theme.textPrimary)
                                        Spacer()
                                        if ann.isActive {
                                            Text("Active")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.12))
                                                .cornerRadius(4)
                                        }
                                    }
                                    Text(ann.displayMessage)
                                        .font(.subheadline)
                                        .foregroundColor(theme.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                            .listRowBackground(theme.cardBackground)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Announcements")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: EditAnnouncementView(announcement: nil)) {
                    Image(systemName: "plus")
                        .foregroundColor(theme.textPrimary)
                }
            }
        }
        .task {
            announcements = await AnnouncementsService.shared.getAllBroadcasts()
            isLoading = false
        }
    }
}

struct EditAnnouncementView: View {
    @State private var theme = ThemeManager.shared
    let announcement: InAppMessage?
    
    @State private var title = ""
    @State private var messageContent = ""
    @State private var actionText = ""
    @State private var actionUrl = ""
    @State private var isActive = true
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var successMsg = ""
    
    // Image selection state
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isUploadingImage = false
    @State private var uploadedImageUrl: String? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section(header: Text("Announcement Fields")) {
                TextField("Title", text: $title)
                
                VStack(alignment: .leading) {
                    Text("Message Content")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextEditor(text: $messageContent)
                        .frame(height: 100)
                }
                
                TextField("Action Button Text (Optional)", text: $actionText)
                TextField("Action Button URL (Optional)", text: $actionUrl)
                Toggle("Is Active", isOn: $isActive)
            }
            
            Section(header: Text("Attachment Image")) {
                if let url = uploadedImageUrl {
                    AsyncImage(url: URL(string: url)) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    } placeholder: {
                        ProgressView()
                    }
                    
                    Button("Remove Attachment", role: .destructive) {
                        uploadedImageUrl = nil
                    }
                } else {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text(isUploadingImage ? "Uploading..." : "Select Attachment Image")
                        }
                    }
                    .disabled(isUploadingImage)
                    .onChange(of: selectedItem) { _, newItem in
                        if let newItem {
                            Task {
                                await uploadImage(newItem)
                            }
                        }
                    }
                }
            }
            
            Section {
                Button(action: saveAnnouncement) {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(announcement == nil ? "Create Announcement" : "Save Changes")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .disabled(isSaving || title.isEmpty || messageContent.isEmpty)
                .listRowBackground(theme.accentColor)
                .foregroundColor(.white)
                
                if announcement != nil {
                    Button("Delete Announcement", role: .destructive) {
                        Task {
                            await deleteAnnouncement()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle(announcement == nil ? "New Broadcast" : "Edit Broadcast")
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text(successMsg)
        }
        .onAppear {
            if let ann = announcement {
                title = ann.title
                messageContent = ann.displayMessage
                actionText = ann.actionText ?? ""
                actionUrl = ann.actionUrl ?? ""
                isActive = ann.isActive
                uploadedImageUrl = ann.imageUrl
            }
        }
    }
    
    private func uploadImage(_ item: PhotosPickerItem) async {
        isUploadingImage = true
        defer { isUploadingImage = false }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                let name = "img_\(UUID().uuidString.prefix(8)).jpg"
                let url = try await AnnouncementsService.shared.uploadAnnouncementImage(fileName: name, data: data)
                await MainActor.run {
                    self.uploadedImageUrl = url
                }
            }
        } catch {
            print("Error uploading image: \(error)")
        }
    }
    
    private func saveAnnouncement() {
        isSaving = true
        var finalMessage = messageContent
        if let img = uploadedImageUrl {
            finalMessage = "\(messageContent) ||image_url=\(img)"
        }
        
        let id = announcement?.id ?? UUID().uuidString.lowercased()
        let msg = InAppMessage(
            id: id,
            title: title,
            message: finalMessage,
            actionText: actionText.isEmpty ? nil : actionText,
            actionUrl: actionUrl.isEmpty ? nil : actionUrl,
            isActive: isActive,
            createdAt: announcement?.createdAt ?? Date()
        )
        
        Task {
            let err: String?
            if announcement == nil {
                err = await AnnouncementsService.shared.createBroadcast(message: msg)
            } else {
                err = await AnnouncementsService.shared.updateBroadcast(message: msg)
            }
            
            await MainActor.run {
                self.isSaving = false
                if let err = err {
                    print("Error saving announcement: \(err)")
                } else {
                    self.successMsg = announcement == nil ? "Created announcement alert successfully." : "Updated announcement details."
                    self.showSuccess = true
                }
            }
        }
    }
    
    private func deleteAnnouncement() async {
        guard let ann = announcement else { return }
        isSaving = true
        defer { isSaving = false }
        
        if let img = ann.imageUrl {
            await AnnouncementsService.shared.deleteAnnouncementImage(imageUrl: img)
        }
        
        let err = await AnnouncementsService.shared.deleteBroadcast(id: ann.id)
        if err == nil {
            await MainActor.run {
                self.successMsg = "Announcement deleted."
                self.showSuccess = true
            }
        }
    }
}

// MARK: - Sub Panel 3: App Configuration Manager
struct AdminConfigManagerView: View {
    @State private var theme = ThemeManager.shared
    @State private var localOverride = UserDefaults.standard.bool(forKey: "admin_local_override")
    @State private var isSaving = false
    @State private var saveSuccess = false
    @State private var loadError = false
    
    // Configuration Fields
    @State private var isChristmasTime = false
    @State private var isMangaloreHymnsEnabled = true
    @State private var pageFlipVisible = true
    @State private var castEnabled = false
    @State private var castAppId = ""
    @State private var castReceiverUrl = ""
    @State private var forceUpdateEnabled = false
    @State private var forceUpdateMinVersion = ""
    @State private var forceUpdateMinBuildNumber = "0"
    @State private var forceUpdateAndroidStoreUrl = ""
    @State private var forceUpdateMessage = ""
    @State private var adminEmails = ""
    @State private var githubToken = ""
    
    var body: some View {
        Form {
            Section(header: Text("Overrides")) {
                Toggle("Local Override Mode", isOn: $localOverride)
                    .onChange(of: localOverride) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "admin_local_override")
                    }
                Text("When enabled, saves config changes only to this device.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Section(header: Text("Feature Flags")) {
                Toggle("Christmas Time Mode", isOn: $isChristmasTime)
                Toggle("Mangalore Hymns Enabled", isOn: $isMangaloreHymnsEnabled)
                Toggle("Page Flip View Visible", isOn: $pageFlipVisible)
                Toggle("Google Cast Support", isOn: $castEnabled)
                TextField("Google Cast App ID", text: $castAppId)
                TextField("Google Cast Receiver URL", text: $castReceiverUrl)
            }
            
            Section(header: Text("Force Update Policies")) {
                Toggle("Enforce Mandatory Updates", isOn: $forceUpdateEnabled)
                TextField("Min Version Required (e.g. 5.1.0)", text: $forceUpdateMinVersion)
                TextField("Min Build Number Required", text: $forceUpdateMinBuildNumber)
                    .keyboardType(.numberPad)
                TextField("Store Download URL", text: $forceUpdateAndroidStoreUrl)
                TextField("Notice Banner Message", text: $forceUpdateMessage)
            }
            
            Section(header: Text("Administration")) {
                TextField("Admin emails (comma-separated)", text: $adminEmails)
                SecureField("GitHub Repo Write Token", text: $githubToken)
            }
            
            Section {
                Button(action: saveConfig) {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Push Config Update")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .disabled(isSaving)
                .listRowBackground(theme.accentColor)
                .foregroundColor(.white)
            }
        }
        .navigationTitle("Configuration Manager")
        .alert("Saved", isPresented: $saveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(localOverride ? "Config saved locally to UserDefaults." : "Config successfully synced to Supabase database.")
        }
        .task {
            await loadConfig()
        }
    }
    
    private func loadConfig() async {
        if localOverride, let data = UserDefaults.standard.data(forKey: "admin_local_config") {
            // Decode local map
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                applyConfigDict(dict)
                return
            }
        }
        
        // Fetch remote config from Supabase
        #if canImport(Supabase)
        do {
            let client = SupabaseService.instance.client
            let rows: [AppConfigRow] = try await client.from("app_config")
                .select("key, value")
                .execute()
                .value
            
            var dict: [String: Any] = [:]
            for row in rows {
                if let b = row.value.boolValue {
                    dict[row.key] = b
                } else {
                    dict[row.key] = row.value.stringValue
                }
            }
            applyConfigDict(dict)
        } catch {
            print("AdminConfigManagerView: Load config failed: \(error)")
            loadError = true
        }
        #endif
    }
    
    private func applyConfigDict(_ dict: [String: Any]) {
        isChristmasTime = dict["is_christmas_time"] as? Bool ?? false
        isMangaloreHymnsEnabled = dict["is_mangalore_hymns_enabled"] as? Bool ?? true
        pageFlipVisible = dict["page_flip_visible"] as? Bool ?? true
        castEnabled = dict["cast_enabled"] as? Bool ?? false
        castAppId = dict["cast_app_id"] as? String ?? ""
        castReceiverUrl = dict["cast_receiver_url"] as? String ?? ""
        forceUpdateEnabled = dict["force_update_enabled"] as? Bool ?? false
        forceUpdateMinVersion = dict["force_update_min_version"] as? String ?? ""
        forceUpdateMinBuildNumber = String(dict["force_update_min_build_number"] as? Int ?? 0)
        forceUpdateAndroidStoreUrl = dict["force_update_android_store_url"] as? String ?? ""
        forceUpdateMessage = dict["force_update_message"] as? String ?? ""
        adminEmails = dict["admin_emails"] as? String ?? ""
        githubToken = dict["github_token"] as? String ?? ""
    }
    
    private func saveConfig() {
        isSaving = true
        
        let dict: [String: Any] = [
            "is_christmas_time": isChristmasTime,
            "is_mangalore_hymns_enabled": isMangaloreHymnsEnabled,
            "page_flip_visible": pageFlipVisible,
            "cast_enabled": castEnabled,
            "cast_app_id": castAppId,
            "cast_receiver_url": castReceiverUrl,
            "force_update_enabled": forceUpdateEnabled,
            "force_update_min_version": forceUpdateMinVersion,
            "force_update_min_build_number": Int(forceUpdateMinBuildNumber) ?? 0,
            "force_update_android_store_url": forceUpdateAndroidStoreUrl,
            "force_update_message": forceUpdateMessage,
            "admin_emails": adminEmails,
            "github_token": githubToken
        ]
        
        Task {
            if localOverride {
                if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
                    UserDefaults.standard.set(data, forKey: "admin_local_config")
                }
            } else {
                #if canImport(Supabase)
                let client = SupabaseService.instance.client
                do {
                    for (k, v) in dict {
                        let valObj: ConfigVal
                        if let b = v as? Bool {
                            valObj = .bool(b)
                        } else if let i = v as? Int {
                            valObj = .int(i)
                        } else {
                            valObj = .string(v as? String ?? "")
                        }
                        
                        try await client.from("app_config")
                            .update(["value": valObj])
                            .eq("key", value: k)
                            .execute()
                    }
                    UserDefaults.standard.removeObject(forKey: "admin_local_config")
                } catch {
                    print("AdminConfigManagerView: Error saving remote config: \(error)")
                }
                #endif
            }
            
            await MainActor.run {
                self.isSaving = false
                self.saveSuccess = true
            }
        }
    }
}

enum ConfigVal: Encodable {
    case bool(Bool)
    case int(Int)
    case string(String)
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let b):
            try container.encode(b)
        case .int(let i):
            try container.encode(i)
        case .string(let s):
            try container.encode(s)
        }
    }
}
