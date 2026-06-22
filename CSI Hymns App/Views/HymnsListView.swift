import SwiftUI
import Observation
import UIKit

/// View model driving the search queries, sorting preferences, and list rendering of Hymns.
@Observable
public final class HymnsListViewModel {
    public var searchQuery = ""
    public var selectedOrder: OrderMode = .number
    public var hymns: [Hymn] = []
    public var isLoading = false
    public var isKeerthanes = false
    
    public enum OrderMode: String, CaseIterable, Identifiable {
        case number = "Number"
        case meter = "Meter"
        case alphabetical = "Order"
        public var id: String { self.rawValue }
    }
    
    public var availableOrderModes: [OrderMode] {
        if isKeerthanes {
            return [.number, .alphabetical]
        } else {
            return [.number, .meter]
        }
    }
    
    public init(isKeerthanes: Bool = false) {
        self.isKeerthanes = isKeerthanes
        Task {
            await loadSongs()
        }
    }
    
    /// Asynchronously fetches songs from remote GitHub JSON endpoints with local cache persistence.
    public func loadSongs() async {
        await MainActor.run {
            self.isLoading = true
        }
        
        let urlString = isKeerthanes
            ? "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/keerthane_data.json"
            : "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/hymns_data.json"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run {
                self.isLoading = false
            }
            return
        }
        
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheFileUrl = cacheDirectory.appendingPathComponent(isKeerthanes ? "keerthane_data_cache.json" : "hymn_data_cache.json")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoded = try JSONDecoder().decode([Hymn].self, from: data)
                let typeStr = isKeerthanes ? "keerthane" : "hymn"
                let mapped = decoded.map { hymn in
                    var u = hymn
                    u.type = typeStr
                    return u
                }
                
                // Persist cache locally
                try? data.write(to: cacheFileUrl)
                
                await MainActor.run {
                    self.hymns = mapped
                    self.isLoading = false
                }
                print("HymnsListViewModel: Successfully fetched and cached remote songs from GitHub.")
                return
            }
        } catch {
            print("HymnsListViewModel: Network fetch failed, trying local cache: \(error)")
        }
        
        // Offline Cache Fallback
        if fileManager.fileExists(atPath: cacheFileUrl.path),
           let cachedData = try? Data(contentsOf: cacheFileUrl),
           let decoded = try? JSONDecoder().decode([Hymn].self, from: cachedData) {
            let typeStr = isKeerthanes ? "keerthane" : "hymn"
            let mapped = decoded.map { hymn in
                var u = hymn
                u.type = typeStr
                return u
            }
            await MainActor.run {
                self.hymns = mapped
                self.isLoading = false
            }
            print("HymnsListViewModel: Loaded songs from offline cache.")
            return
        }
        
        // 2. Offline Compiled Asset Fallback (Premium, real production data!)
        let assetName = isKeerthanes ? "keerthane_data" : "hymns_data"
        if let asset = NSDataAsset(name: assetName),
           let decoded = try? JSONDecoder().decode([Hymn].self, from: asset.data) {
            let typeStr = isKeerthanes ? "keerthane" : "hymn"
            let mapped = decoded.map { hymn in
                var u = hymn
                u.type = typeStr
                return u
            }
            await MainActor.run {
                self.hymns = mapped
                self.isLoading = false
            }
            print("HymnsListViewModel: Loaded songs from bundled NSDataAsset '\(assetName)'.")
            return
        }
        
        // 3. Emergency empty state fallback
        await MainActor.run {
            self.hymns = []
            self.isLoading = false
        }
    }
    
    /// Auto-refreshes lyrics from GitHub if last update was more than 3 days ago (Flutter parity).
    public func checkAndUpdateOnOpenIfNeeded() async {
        let key = isKeerthanes ? "last_keerthane_update" : "last_lyrics_update"
        let last = UserDefaults.standard.object(forKey: key) as? TimeInterval ?? 0
        let interval: TimeInterval = 3 * 24 * 60 * 60
        guard Date().timeIntervalSince1970 - last >= interval else { return }
        if await refreshSongs() {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
        }
    }
    
    /// Forces a remote refresh from the GitHub repository, updating the local cache.
    /// Returns true if successful.
    public func refreshSongs() async -> Bool {
        let urlString = isKeerthanes
            ? "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/keerthane_data.json"
            : "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/main/hymns_data.json"
        
        guard let url = URL(string: urlString) else { return false }
        
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheFileUrl = cacheDirectory.appendingPathComponent(isKeerthanes ? "keerthane_data_cache.json" : "hymn_data_cache.json")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoded = try JSONDecoder().decode([Hymn].self, from: data)
                let typeStr = isKeerthanes ? "keerthane" : "hymn"
                let mapped = decoded.map { hymn in
                    var u = hymn
                    u.type = typeStr
                    return u
                }
                
                // Persist cache locally
                try? data.write(to: cacheFileUrl)
                
                await MainActor.run {
                    self.hymns = mapped
                }
                return true
            }
        } catch {
            print("HymnsListViewModel: Remote refresh failed: \(error)")
        }
        return false
    }
    
    /// Filters and sorts hymns based on user selections.
    public var filteredHymns: [Hymn] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let source = hymns
        
        var results = source
        if !query.isEmpty {
            results = source.filter { hymn in
                hymn.title.lowercased().contains(query) ||
                String(hymn.number).contains(query) ||
                hymn.signature.lowercased().contains(query)
            }
        }
        
        switch selectedOrder {
        case .number:
            return results.sorted { $0.number < $1.number }
        case .meter:
            return results.sorted { $0.signature < $1.signature }
        case .alphabetical:
            return results.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        }
    }
    
    /// Groups hymns by their time signature meter keys, splitting multi-meter signatures.
    public var groupedHymns: [String: [Hymn]] {
        var groups = [String: [Hymn]]()
        
        for hymn in filteredHymns {
            let parts = hymn.signature
                .components(separatedBy: " / ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            let realMeters = parts.filter { !isTuneReference($0) }
            let groupKeys = !realMeters.isEmpty ? realMeters : [hymn.signature.isEmpty ? "No Meter" : hymn.signature]
            
            for key in groupKeys {
                groups[key, default: []].append(hymn)
            }
        }
        
        return groups
    }
    
    private func isTuneReference(_ part: String) -> Bool {
        let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") {
            return true
        }
        
        // Match standard tune indices like 'Mang.T.B.' or 'M.T.' followed by digits
        let pattern = "^(Mang\\.T\\.B\\.|M\\.T\\.)\\d"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func loadMockHymns() {
        self.hymns = []
    }
}

/// A premium, glassmorphic view rendering the list of hymns, search filters, and sorting.
public struct HymnsListView: View {
    @Binding var selectedTab: Int
    @State private var theme = ThemeManager.shared
    @State private var viewModel: HymnsListViewModel
    @State private var isShowingJumpSheet = false
    
    // Remote refresh alerts and HUD state
    @State private var isShowingRefreshConfirmAlert = false
    @State private var isRefreshingSongs = false
    @State private var isShowingSuccessAlert = false
    @State private var isShowingErrorAlert = false
    
    enum RefreshStatus {
        case idle
        case syncing
        case success
        case error
    }
    
    @State private var refreshStatus: RefreshStatus = .idle
    
    private let title: String
    
    private var maxTab: Int {
        ChristmasModeService.shared.isChristmasTime ? 3 : 4
    }
    
    public init(title: String = "CSI Hymns", isKeerthanes: Bool = false, selectedTab: Binding<Int>) {
        self.title = title
        self._selectedTab = selectedTab
        self._viewModel = State(initialValue: HymnsListViewModel(isKeerthanes: isKeerthanes))
    }
    
    public var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ZStack {
                    // Deep gradient background conforming to dynamic aesthetics
                    theme.backgroundColor
                        .ignoresSafeArea()
                    
                    if theme.activeTheme != .amoled {
                        theme.backgroundGradient
                            .ignoresSafeArea()
                    }
                    
                    VStack(spacing: 16) {
                        // Custom Glass Search Container
                        customSearchBar
                        
                        // Filters & Sorting Chips
                        filterChipsRow
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(theme.textPrimary)
                                .frame(maxHeight: .infinity)
                        } else {
                            hymnsScrollView(scrollProxy: scrollProxy)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Glassmorphic forced non-blocking top HUD status toast
                    toastHUDView
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .csiGlassNavigationBar(theme: theme)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                                .foregroundColor(theme.textPrimary)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 14) {
                            NavigationLink(destination: RecentSongsView()) {
                                Image(systemName: "clock")
                                    .foregroundColor(theme.textPrimary)
                            }
                            
                            if viewModel.selectedOrder == .meter {
                                Button {
                                    isShowingJumpSheet = true
                                } label: {
                                    Image(systemName: "list.bullet.indent")
                                        .foregroundColor(theme.textPrimary)
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $isShowingJumpSheet) {
                    jumpToMeterSheet(scrollProxy: scrollProxy)
                }
                .alert("Refresh lyrics?", isPresented: $isShowingRefreshConfirmAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Refresh") {
                        Task {
                            await performManualRefresh()
                        }
                    }
                } message: {
                    Text("We'll fetch any updated and corrected lyrics from the cloud.")
                }
            }
        }
        .task {
            await viewModel.checkAndUpdateOnOpenIfNeeded()
        }
    }
    
    private func performManualRefresh() async {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isRefreshingSongs = true
            refreshStatus = .syncing
        }
        
        let success = await viewModel.refreshSongs()
        
        let generator = UINotificationFeedbackGenerator()
        if success {
            generator.notificationOccurred(.success)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                refreshStatus = .success
                isRefreshingSongs = false
            }
        } else {
            generator.notificationOccurred(.error)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                refreshStatus = .error
                isRefreshingSongs = false
            }
        }
        
        // Auto-dismiss HUD after 2.5 seconds
        try? await Task.sleep(for: .seconds(2.5))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            refreshStatus = .idle
        }
    }
    
    // MARK: - Subviews
    
    private var customSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.textSecondary)
            
            TextField("Search (Number, Title, Meter)...", text: $viewModel.searchQuery)
                .foregroundColor(theme.textPrimary)
                .accentColor(theme.textPrimary)
            
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .padding(12)
        .csiGlassCard(cornerRadius: 16)
    }
    
    private var filterChipsRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                ForEach(viewModel.availableOrderModes) { mode in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.selectedOrder = mode
                        }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedOrder == mode ? theme.textPrimary.opacity(0.12) : theme.surfaceColor)
                                    .overlay(
                                        Capsule()
                                            .stroke(viewModel.selectedOrder == mode ? theme.textPrimary.opacity(0.3) : theme.strokeColor, lineWidth: 1)
                                    )
                            )
                            .foregroundColor(theme.textPrimary)
                    }
                }
            }
            
            Spacer()
            
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                isShowingRefreshConfirmAlert = true
            } label: {
                HStack(spacing: 6) {
                    if isRefreshingSongs {
                        ProgressView()
                            .tint(theme.textPrimary)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                    }
                    Text(isRefreshingSongs ? "Syncing..." : "Refresh")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(theme.surfaceColor)
                        .overlay(
                            Capsule()
                                .stroke(theme.strokeColor, lineWidth: 1)
                        )
                )
            }
            .disabled(isRefreshingSongs)
        }
        .padding(.vertical, 4)
    }
    
    private func hymnsScrollView(scrollProxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                if viewModel.selectedOrder == .meter {
                    // Render Meter sections
                    ForEach(viewModel.groupedHymns.keys.sorted(), id: \.self) { meter in
                        Section(header: meterHeader(meter)) {
                            ForEach(viewModel.groupedHymns[meter] ?? []) { hymn in
                                hymnCell(hymn)
                            }
                        }
                        .id(meter)
                    }
                } else {
                    // Standard Number list
                    ForEach(viewModel.filteredHymns) { hymn in
                        hymnCell(hymn)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .swipeToNavigate(selectedTab: $selectedTab, maxTab: maxTab)
    }
    
    private func meterHeader(_ meter: String) -> some View {
        Text(meter)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(theme.secondaryBackgroundColor.opacity(0.95))
                    .overlay(Capsule().stroke(theme.strokeColor, lineWidth: 1))
            )
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formattedSignature(_ signature: String) -> String {
        signature
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
    
    private func hymnCell(_ hymn: Hymn) -> some View {
        NavigationLink(destination: HymnDetailView(hymn: hymn)) { // detail view
            HStack(alignment: .top, spacing: 16) {
                // Premium hierarchical song category notation icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.accentColor.opacity(0.12))
                        .frame(width: 46, height: 46)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.accentColor.opacity(0.25), lineWidth: 1))
                    
                    Image(viewModel.isKeerthanes ? "keerthane" : "hymn")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(hymn.number): \(hymn.title)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !hymn.signature.isEmpty {
                        Text(formattedSignature(hymn.signature))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(theme.surfaceColor)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textSecondary.opacity(0.7))
                    .padding(.top, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .csiGlassCard(cornerRadius: 16)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private func jumpToMeterSheet(scrollProxy: ScrollViewProxy) -> some View {
        NavigationStack {
            List(viewModel.groupedHymns.keys.sorted(), id: \.self) { meter in
                Button {
                    isShowingJumpSheet = false
                    withAnimation(.easeInOut(duration: 0.45)) {
                        scrollProxy.scrollTo(meter, anchor: .top)
                    }
                } label: {
                    HStack {
                        Text(meter)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        Text("\(viewModel.groupedHymns[meter]?.count ?? 0) songs")
                            .font(.system(size: 13))
                            .foregroundColor(theme.textSecondary)
                    }
                }
                .listRowBackground(theme.cardBackground)
            }
            .navigationTitle("Jump to Meter")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(theme.backgroundColor)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isShowingJumpSheet = false
                    }
                    .foregroundColor(theme.textPrimary)
                }
            }
        }
    }
    
    private var toastHUDView: some View {
        Group {
            if refreshStatus != .idle {
                VStack {
                    HStack(spacing: 12) {
                        switch refreshStatus {
                        case .syncing:
                            ProgressView()
                                .tint(theme.accentColor)
                                .scaleEffect(0.9)
                            Text("Syncing latest lyrics...")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.textPrimary)
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.green)
                            Text("Lyrics updated! ✨")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(theme.textPrimary)
                        case .error:
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                            Text("Sync failed. Using cache.")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.textPrimary)
                        case .idle:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .csiGlassCard(cornerRadius: 999)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                    .padding(.top, 16)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}
