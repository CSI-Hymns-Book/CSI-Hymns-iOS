import SwiftUI

/// Core Page structure for liturgies downloaded from remote JSON.
public struct OrderPage: Codable, Identifiable, Hashable, Sendable {
    public var id: String { "\(type)-\(pageNo)" }
    public var pageNo: Int
    public var title: String?
    public var content: String
    public var type: String // 'regular' or 'festival'
    
    enum CodingKeys: String, CodingKey {
        case pageNo = "page_no"
        case title
        case content
        case type
    }
    
    public init(pageNo: Int, title: String?, content: String, type: String) {
        self.pageNo = pageNo
        self.title = title
        self.content = content
        self.type = type
    }
    
    /// Parses JSON input containing Flat List, Grouped Map (+ index), or Legacy map structures.
    public static func parsePages(from data: Data) throws -> [OrderPage] {
        try OrderOfServiceStore.parseDocument(from: data).pages
    }
}

/// A premium, glassmorphic liturgy browser listing Regular Sunday and Festival service guides.
public struct OrderOfServiceListView: View {
    @Binding var selectedTab: Int
    @State private var theme = ThemeManager.shared
    @State private var showEnglishPrimary = true
    @State private var isRefreshing = false
    
    private var maxTab: Int {
        ChristmasModeService.shared.isChristmasTime ? 3 : 4
    }
    
    public init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }
    
    public var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                
                ZStack {
                    // Adaptive theme backgrounds
                    theme.backgroundColor
                        .ignoresSafeArea()
                    
                    if theme.activeTheme != .amoled {
                        theme.backgroundGradient
                            .ignoresSafeArea()
                    }
                    
                    VStack(spacing: 0) {
                        if isLandscape {
                            HStack(spacing: 32) {
                                // Left Column: Headers & Refresh
                                VStack(alignment: .leading, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("ಆರಾಧನಾ ಕ್ರಮ")
                                            .font(.system(size: 26, weight: .black))
                                            .foregroundColor(theme.textPrimary)
                                        
                                        Text("Order of Service")
                                            .font(.system(size: 19, weight: .bold))
                                            .foregroundColor(theme.textSecondary)
                                    }
                                    
                                    Text("Select a liturgy to read or follow along with the church service.")
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.textSecondary.opacity(0.75))
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                    
                                    Button {
                                        Task {
                                            await refreshLiturgyCaches()
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            if isRefreshing {
                                                ProgressView()
                                                    .tint(theme.backgroundColor)
                                            } else {
                                                Image(systemName: "arrow.clockwise")
                                                    .foregroundColor(theme.backgroundColor)
                                                Text("Refresh Liturgies")
                                                    .foregroundColor(theme.backgroundColor)
                                            }
                                        }
                                        .font(.system(size: 14, weight: .bold))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(theme.textPrimary)
                                        .cornerRadius(24)
                                    }
                                    .disabled(isRefreshing)
                                    .padding(.bottom, 12)
                                }
                                .frame(width: 240, alignment: .leading)
                                .padding(.vertical, 20)
                                
                                // Right Column: Cards Stacked Vertically
                                ScrollView(showsIndicators: false) {
                                    VStack(spacing: 16) {
                                        orderCard(
                                            englishTitle: "Regular Sunday",
                                            kannadaTitle: "ಭಾನುವಾರದ ದೇವರಾರಾಧನೆ",
                                            englishHeader: "Regular Sunday Order of Service",
                                            subtitle: "Weekly Sunday Worship Liturgy",
                                            icon: "sun.max.fill",
                                            gradientColors: [Color(hex: "FFC66A"), Color(hex: "FFD48C")],
                                            readerType: "regular"
                                        )
                                        
                                        orderCard(
                                            englishTitle: "Festival Services",
                                            kannadaTitle: "ಹಬ್ಬದ ಆರಾಧನೆ",
                                            englishHeader: "Festival Order of Service",
                                            subtitle: "Special Feasts & Festivals Liturgy",
                                            icon: "sparkles",
                                            gradientColors: [Color(hex: "BCEBFF"), Color(hex: "D7F4FF")],
                                            readerType: "festival"
                                        )
                                    }
                                    .padding(.vertical, 20)
                                }
                            }
                            .padding(.horizontal, 24)
                        } else {
                            ScrollView {
                                VStack(spacing: 36) {
                                    // Centered Group Header
                                    VStack(spacing: 12) {
                                        Text("ಆರಾಧನಾ ಕ್ರಮ")
                                            .font(.system(size: 32, weight: .black))
                                            .foregroundColor(theme.textPrimary)
                                            .multilineTextAlignment(.center)
                                        
                                        Text("Order of Service")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(theme.textSecondary)
                                            .multilineTextAlignment(.center)
                                        
                                        Text("Select a liturgy to read or follow along with the church service.")
                                            .font(.system(size: 14))
                                            .foregroundColor(theme.textSecondary.opacity(0.7))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 24)
                                    }
                                    .padding(.top, 40)
                                    
                                    // Grouped Action Cards
                                    VStack(spacing: 20) {
                                        // Regular Sunday card
                                        orderCard(
                                            englishTitle: "Regular Sunday",
                                            kannadaTitle: "ಭಾನುವಾರದ ದೇವರಾರಾಧನೆ",
                                            englishHeader: "Regular Sunday Order of Service",
                                            subtitle: "Weekly Sunday Worship Liturgy",
                                            icon: "sun.max.fill",
                                            gradientColors: [Color(hex: "FFC66A"), Color(hex: "FFD48C")],
                                            readerType: "regular"
                                        )
                                        
                                        // Festival card
                                        orderCard(
                                            englishTitle: "Festival Services",
                                            kannadaTitle: "ಹಬ್ಬದ ಆರಾಧನೆ",
                                            englishHeader: "Festival Order of Service",
                                            subtitle: "Special Feasts & Festivals Liturgy",
                                            icon: "sparkles",
                                            gradientColors: [Color(hex: "BCEBFF"), Color(hex: "D7F4FF")],
                                            readerType: "festival"
                                        )
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .padding(.bottom, 24)
                            }
                            
                            // Explicit Centered Manual Refresh Button
                            Button {
                                Task {
                                    await refreshLiturgyCaches()
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    if isRefreshing {
                                        ProgressView()
                                            .tint(theme.backgroundColor)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .foregroundColor(theme.backgroundColor)
                                        Text("Refresh Liturgies")
                                            .foregroundColor(theme.backgroundColor)
                                    }
                                }
                                .font(.system(size: 15, weight: .heavy))
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(theme.textPrimary)
                                .cornerRadius(32)
                                .shadow(color: theme.shadowColor.opacity(0.12), radius: 12, y: 6)
                            }
                            .disabled(isRefreshing)
                            .padding(.bottom, 28)
                        }
                    }
                    .frame(maxWidth: isLandscape ? 640 : .infinity)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .swipeToNavigate(selectedTab: $selectedTab, maxTab: maxTab)
                }
            }
            .navigationTitle("ಆರಾಧನಾ ಕ್ರಮ / Liturgies")
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
            .onAppear {
                startTitleAlternatingTimer()
                Task {
                    await checkAndUpdateOrderOfServiceOnOpen()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private func orderCard(
        englishTitle: String,
        kannadaTitle: String,
        englishHeader: String,
        subtitle: String,
        icon: String,
        gradientColors: [Color],
        readerType: String
    ) -> some View {
        NavigationLink(destination: OrderOfServiceReaderView(
            type: readerType,
            englishHeader: englishHeader,
            kannadaHeader: kannadaTitle
        )) {
            HStack(spacing: 20) {
                // Large circular symbol container
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(showEnglishPrimary ? englishTitle : kannadaTitle)
                        .font(.system(size: 19, weight: .black))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Native disclosure bubble
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: theme.shadowColor.opacity(0.12), radius: 10, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Timer & Caches
    
    private func startTitleAlternatingTimer() {
        Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
            withAnimation {
                showEnglishPrimary.toggle()
            }
        }
    }
    
    /// Startup routine to automatically fetch and cache remote liturgies if elapsed time exceeds 3 days.
    private func checkAndUpdateOrderOfServiceOnOpen() async {
        await OrderOfServiceStore.ensureSeededAndRefreshIfStale()
    }
    
    /// Triggered by manual refresh button: bypasses the cache window, fetches fresh JSON, and triggers notifications.
    private func refreshLiturgyCaches() async {
        isRefreshing = true
        let ok = await OrderOfServiceStore.refreshFromNetwork(force: true)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(ok ? .success : .error)
        isRefreshing = false
    }
}
