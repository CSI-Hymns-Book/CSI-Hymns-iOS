import SwiftUI

/// Core Page structure for liturgy categories matching Flutter parity exactly.
struct CommonCategoryItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let hymnNumbers: [Int]
    let keerthaneNumbers: [Int]
    let gradientColors: [Color]
}

/// A spectacular, high-fidelity categories browser for the native iOS app.
/// Migrates both static common event categories and runtime custom collections, enforcing guest quotas.
public struct CustomCategoriesView: View {
    @Binding var selectedTab: Int
    @State private var theme = ThemeManager.shared
    @State private var viewModel = CustomCategoriesViewModel()
    
    struct MtCategoryItem: Identifiable, Sendable {
        let id: String
        let name: String
        let kannadaName: String
        let hymns: [Hymn]
    }
    
    @State private var mtCategoryItems: [MtCategoryItem] = []
    @State private var mtHymns: [Hymn] = []
    
    private var maxTab: Int {
        if AppNavigationService.shared.activeSection == .mt {
            return 2
        }
        return ChristmasModeService.shared.isChristmasTime ? 3 : 4
    }
    
    // Exact Flutter common category definitions
    private let commonCategories = [
        CommonCategoryItem(name: "Birthday", icon: "birthday.cake.fill", hymnNumbers: [361], keerthaneNumbers: [215], gradientColors: [Color(hex: "FFC66A"), Color(hex: "FFD48C")]),
        CommonCategoryItem(name: "Marriage", icon: "suit.heart.fill", hymnNumbers: [358, 359, 360], keerthaneNumbers: [188, 189, 190], gradientColors: [Color(hex: "FF9E9E"), Color(hex: "FFC3C3")]),
        CommonCategoryItem(name: "House Warming", icon: "house.fill", hymnNumbers: [362], keerthaneNumbers: [227, 228, 229, 230, 231, 232, 233, 234], gradientColors: [Color(hex: "A3E4D7"), Color(hex: "D1F2EB")]),
        CommonCategoryItem(name: "Funeral", icon: "square.and.pencil.circle.fill", hymnNumbers: [310, 311, 312], keerthaneNumbers: [], gradientColors: [Color(hex: "AEB6BF"), Color(hex: "D5D8DC")]),
        CommonCategoryItem(name: "Mangala", icon: "sparkles", hymnNumbers: [], keerthaneNumbers: [227, 228, 229, 230, 231, 232, 233, 234], gradientColors: [Color(hex: "F9E79F"), Color(hex: "FCF3CF")]),
        CommonCategoryItem(name: "Children's Prayer", icon: "figure.and.child.holdinghands", hymnNumbers: Array(328...349), keerthaneNumbers: Array(200...209), gradientColors: [Color(hex: "AED6F1"), Color(hex: "EBF5FB")]),
        CommonCategoryItem(name: "Lord's Supper", icon: "wineglass.fill", hymnNumbers: [273, 274, 275, 276, 277, 278, 279], keerthaneNumbers: [184, 185, 186, 187], gradientColors: [Color(hex: "F1948A"), Color(hex: "FDEDEC")]),
        CommonCategoryItem(name: "Travelling", icon: "airplane", hymnNumbers: [363], keerthaneNumbers: [], gradientColors: [Color(hex: "A9DFBF"), Color(hex: "E8F8F5")]),
        CommonCategoryItem(name: "Sickness", icon: "cross.case.fill", hymnNumbers: [367], keerthaneNumbers: [], gradientColors: [Color(hex: "D7BDE2"), Color(hex: "F5EEF8")])
    ]
    
    public init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive backgrounds
                theme.backgroundColor
                    .ignoresSafeArea()
                
                if theme.activeTheme != .amoled {
                    theme.backgroundGradient
                        .ignoresSafeArea()
                }
                
                ScrollView {
                    VStack(spacing: 28) {
                        let activeSec = AppNavigationService.shared.activeSection ?? .csi
                        
                        // Header
                        VStack(spacing: 8) {
                            Text(activeSec == .mt ? "ವಿಷಯ ಸೂಚಿ" : "ವರ್ಗಗಳು")
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(theme.textPrimary)
                                .multilineTextAlignment(.center)
                            
                            Text(activeSec == .mt ? "Thematic Collections" : "Categories")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)
                        
                        if activeSec == .mt {
                            // MT Dynamic Categories Section
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                                ForEach(mtCategoryItems) { item in
                                    NavigationLink(destination: DynamicCategoryScreenView(categoryName: item.name, directHymnsList: item.hymns)) {
                                        mtCategoryCard(item)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16)
                        } else {
                            // CSI Static Sections
                            // Guest slots badge
                            guestSlotsView
                            
                            // SECTION 0: Liturgical seasons
                            VStack(alignment: .leading, spacing: 14) {
                                Text("LITURGICAL SEASONS")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(theme.textSecondary)
                                    .padding(.horizontal, 16)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                                    ForEach(LiturgicalCategories.all) { category in
                                        NavigationLink {
                                            DynamicCategoryScreenView(
                                                categoryName: category.title,
                                                hymnNumbers: category.hymnNumbers,
                                                keerthaneNumbers: category.keerthaneNumbers
                                            )
                                        } label: {
                                            liturgicalCategoryCard(category)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // SECTION 1: Common Categories
                            VStack(alignment: .leading, spacing: 14) {
                                Text("COMMON CATEGORIES")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(theme.textSecondary)
                                    .padding(.horizontal, 16)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                                    // Recent Songs Card
                                    recentSongsCard
                                    
                                    ForEach(commonCategories) { item in
                                        NavigationLink(destination: DynamicCategoryScreenView(categoryName: item.name, hymnNumbers: item.hymnNumbers, keerthaneNumbers: item.keerthaneNumbers)) {
                                            commonCategoryCard(item)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        // SECTION 2: Custom Collections (Visible in both sections)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("MY COLLECTIONS")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(theme.textSecondary)
                                
                                Spacer()
                                
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        viewModel.isShowingCreateDialog = true
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle")
                                        Text("Create")
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(theme.accentColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            if viewModel.categories.isEmpty {
                                emptyCollectionsCard
                                    .padding(.horizontal, 16)
                            } else {
                                customCollectionsGrid
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 36)
                    }
                }
                .swipeToNavigate(selectedTab: $selectedTab, maxTab: maxTab)
                
                // Creation Overlay Dialog
                if viewModel.isShowingCreateDialog {
                    createCategoryOverlay
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .csiGlassNavigationBar(theme: theme)
            .toolbar {
                if AppNavigationService.shared.activeSection != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                AppNavigationService.shared.activeSection = nil
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Home")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(theme.textPrimary)
                        }
                    }
                }
            }
            .alert("Guest Limit Reached", isPresented: $viewModel.limitAlert) {
                Button("OK", role: .cancel) {}
                NavigationLink("Sign In") {
                    AuthView()
                }
            } message: {
                Text("Guest accounts are limited to 5 custom folders. Please sign up or login to unlock unlimited collection syncs!")
            }
            .onAppear {
                viewModel.loadCategories()
                if AppNavigationService.shared.activeSection == .mt {
                    loadMtCategories()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var guestSlotsView: some View {
        let isAuth = SupabaseService.instance.isAuthenticated
        let activeCount = viewModel.categories.count
        let remaining = max(0, 5 - activeCount)
        
        return Group {
            if !isAuth {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .foregroundColor(theme.textSecondary)
                        .font(.system(size: 16))
                    
                    Text("Guest folders: \(remaining)/5 left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                    
                    Spacer()
                    
                    NavigationLink(destination: AuthView()) {
                        Text("Sign In")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(theme.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(theme.accentColor.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(theme.surfaceColor)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.strokeColor, lineWidth: 1))
                )
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var recentSongsCard: some View {
        NavigationLink(destination: RecentSongsView()) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("History")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black.opacity(0.6))
                }
                Spacer()
            }
            .padding(16)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "BCEBFF"), Color(hex: "D7F4FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: theme.shadowColor.opacity(0.06), radius: 6, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func liturgicalCategoryCard(_ category: LiturgicalCategory) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(category.hymnNumbers.count + category.keerthaneNumbers.count) songs")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(14)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Color(hex: "1B4332"), Color(hex: "2D6A4F")], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }
    
    private func commonCategoryCard(_ item: CommonCategoryItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 40, height: 40)
                
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                let songsCount = item.hymnNumbers.count + item.keerthaneNumbers.count
                Text("\(songsCount) songs")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))
            }
            Spacer()
        }
        .padding(16)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: item.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: theme.shadowColor.opacity(0.06), radius: 6, y: 3)
    }
    
    private var emptyCollectionsCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(theme.textSecondary.opacity(0.4))
            
            Text("No Collections Yet")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text("Create custom lists to group your favorites.")
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.cardStroke, lineWidth: 1))
        )
    }
    
    private var customCollectionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ForEach(viewModel.categories) { category in
                NavigationLink(destination: CustomCategorySongsListView(categoryId: category.id)) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(theme.surfaceColor)
                                .frame(width: 44, height: 44)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.strokeColor, lineWidth: 1))
                            
                            Image(systemName: "folder.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.yellow.opacity(0.85))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(theme.textPrimary)
                                .lineLimit(1)
                            
                            Text("\(category.songIds.count) songs")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(theme.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.cardStroke, lineWidth: 1))
                            .shadow(color: theme.shadowColor.opacity(0.04), radius: 6, y: 3)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .contextMenu {
                    Button(role: .destructive) {
                        if let idx = viewModel.categories.firstIndex(where: { $0.id == category.id }) {
                            withAnimation {
                                viewModel.deleteCategory(at: IndexSet(integer: idx))
                            }
                        }
                    } label: {
                        Label("Delete Folder", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    private var createCategoryOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.isShowingCreateDialog = false
                    }
                }
            
            VStack(spacing: 20) {
                Text("New Collection")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(theme.textPrimary)
                
                TextField("", text: $viewModel.newCategoryName, prompt: Text("Folder Name (e.g. Choir)").foregroundColor(theme.textSecondary.opacity(0.5)))
                    .foregroundColor(theme.textPrimary)
                    .accentColor(theme.textPrimary)
                    .padding(14)
                    .background(theme.surfaceColor)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.strokeColor, lineWidth: 1))
                
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.isShowingCreateDialog = false
                        }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.surfaceColor)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.strokeColor, lineWidth: 1))
                    }
                    
                    Button {
                        let ok = viewModel.createCategory()
                        if ok {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                    } label: {
                        Text("Create")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.backgroundColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.textPrimary)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(theme.secondaryBackgroundColor)
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(theme.strokeColor, lineWidth: 1))
            )
            .padding(.horizontal, 36)
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    private func mtCategoryCard(_ item: MtCategoryItem) -> some View {
        // Multi-color gradients for MT Categories
        let gradients: [[Color]] = [
            [Color.orange, Color(hex: "D35400")],
            [Color.blue, Color(hex: "2980B9")],
            [Color.purple, Color(hex: "8E44AD")],
            [Color.pink, Color(hex: "C0392B")],
            [Color.teal, Color(hex: "16A085")],
            [Color.indigo, Color(hex: "34495E")]
        ]
        
        let hash = abs(item.name.hashValue)
        let gradient = gradients[hash % gradients.count]
        
        return VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "music.quarternote.3")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(14)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if !item.kannadaName.isEmpty {
                    Text(item.kannadaName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .frame(height: 140)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(gradient: Gradient(colors: gradient), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(20)
        .shadow(color: theme.shadowColor.opacity(0.08), radius: 8, y: 4)
    }
    
    private func loadMtCategories() {
        guard mtCategoryItems.isEmpty else { return }
        
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheFileUrl = cacheDirectory.appendingPathComponent("mangalore_data_cache.json")
        
        var hymnsList: [Hymn] = []
        
        if fileManager.fileExists(atPath: cacheFileUrl.path),
           let cachedData = try? Data(contentsOf: cacheFileUrl),
           let decoded = try? JSONDecoder().decode([Hymn].self, from: cachedData) {
            hymnsList = decoded
        } else if let bundleUrl = Bundle.main.url(forResource: "mangalore_hymns_data", withExtension: "json"),
                  let bundleData = try? Data(contentsOf: bundleUrl),
                  let decoded = try? JSONDecoder().decode([Hymn].self, from: bundleData) {
            hymnsList = decoded
        }
        
        self.mtHymns = hymnsList
        
        var groups: [String: (kannada: String, hymns: [Hymn])] = [:]
        for hymn in hymnsList {
            if let cat = hymn.category?.trimmingCharacters(in: .whitespacesAndNewlines), !cat.isEmpty {
                let kan = hymn.kannadaCategory?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if groups[cat] == nil {
                    groups[cat] = (kan, [])
                }
                groups[cat]?.hymns.append(hymn)
            }
        }
        
        let items = groups.map { key, value in
            MtCategoryItem(id: key, name: key, kannadaName: value.kannada, hymns: value.hymns.sorted(by: { $0.number < $1.number }))
        }
        .sorted(by: { $0.name < $1.name })
        
        self.mtCategoryItems = items
    }
}
