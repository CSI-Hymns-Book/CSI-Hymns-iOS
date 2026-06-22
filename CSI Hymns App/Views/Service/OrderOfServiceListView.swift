import SwiftUI

/// Core Page structure for liturgies downloaded from remote JSON.
public struct OrderPage: Codable, Identifiable, Hashable, Sendable {
    public var id: Int { pageNo }
    public let pageNo: Int
    public let title: String?
    public let content: String
    public let type: String // 'regular' or 'festival'
    
    public init(pageNo: Int, title: String?, content: String, type: String) {
        self.pageNo = pageNo
        self.title = title
        self.content = content
        self.type = type
    }
    
    /// Parses JSON input containing either Flat List, Grouped Map, or Legacy Backwards Map structures.
    public static func parsePages(from data: Data) throws -> [OrderPage] {
        var decodedPages: [OrderPage] = []
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        
        if let list = jsonObject as? [[String: Any]] {
            for item in list {
                let pageNo: Int
                if let no = item["page_no"] as? Int {
                    pageNo = no
                } else if let noStr = item["page_no"] as? String, let no = Int(noStr) {
                    pageNo = no
                } else {
                    continue
                }
                
                let title = item["title"] as? String
                let content = (item["content"] ?? "") as? String ?? ""
                let type = (item["type"] ?? "regular") as? String ?? "regular"
                
                decodedPages.append(OrderPage(pageNo: pageNo, title: title, content: content, type: type))
            }
        } else if let dict = jsonObject as? [String: Any] {
            if dict.keys.contains("regular") || dict.keys.contains("festival") {
                for key in ["regular", "festival"] {
                    if let block = dict[key] as? [[String: Any]] {
                        for item in block {
                            let pageNo: Int
                            if let no = item["page_no"] as? Int {
                                pageNo = no
                            } else if let noStr = item["page_no"] as? String, let no = Int(noStr) {
                                pageNo = no
                            } else {
                                continue
                            }
                            
                            let title = item["title"] as? String
                            let content = (item["content"] ?? "") as? String ?? ""
                            
                            decodedPages.append(OrderPage(pageNo: pageNo, title: title, content: content, type: key))
                        }
                    }
                }
            } else {
                for (k, v) in dict {
                    let pageNo = Int(k) ?? 0
                    let content = String(describing: v)
                    decodedPages.append(OrderPage(pageNo: pageNo, title: nil, content: content, type: "regular"))
                }
            }
        } else {
            throw NSError(domain: "LiturgyParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])
        }
        
        return decodedPages.sorted(by: { $0.pageNo < $1.pageNo })
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
            ZStack {
                // Adaptive theme backgrounds
                theme.backgroundColor
                    .ignoresSafeArea()
                
                if theme.activeTheme != .amoled {
                    theme.backgroundGradient
                        .ignoresSafeArea()
                }
                
                VStack(spacing: 0) {
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
                            .padding(.horizontal, 8)
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
                .padding(.horizontal, 20)
                .swipeToNavigate(selectedTab: $selectedTab, maxTab: maxTab)
            }
            .navigationTitle("ಆರಾಧನಾ ಕ್ರಮ / Liturgies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.secondaryBackgroundColor, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
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
        let last = UserDefaults.standard.double(forKey: "lastOrderOfServiceUpdate")
        let now = Date().timeIntervalSince1970 * 1000 // millisecond epoch
        let interval: Double = 3 * 24 * 60 * 60 * 1000 // 3 days
        
        print("[OrderOfService] Startup check: last=\(last) now=\(now) delta=\(now - last) interval=\(interval)")
        
        if now - last < interval {
            print("[OrderOfService] Within 3-day cache window, skipping remote fetch.")
            return
        }
        
        print("[OrderOfService] Cache expired or missing, starting background remote fetch.")
        do {
            isRefreshing = true
            let url = URL(string: "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/refs/heads/main/order-of-service_data.json")!
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Pre-decode check to ensure structure safety
                _ = try OrderPage.parsePages(from: data)
                
                // Persist cache and save timestamp
                UserDefaults.standard.set(data, forKey: "orderOfServiceData")
                UserDefaults.standard.set(now, forKey: "lastOrderOfServiceUpdate")
                print("[OrderOfService] Startup update succeeded.")
            }
        } catch {
            print("[OrderOfService] Startup update failed: \(error)")
        }
        isRefreshing = false
    }
    
    /// Triggered by manual refresh button: bypasses the cache window, fetches fresh JSON, and triggers notifications.
    private func refreshLiturgyCaches() async {
        isRefreshing = true
        let url = URL(string: "https://raw.githubusercontent.com/Reynold29/csi-hymns-vault/refs/heads/main/order-of-service_data.json")!
        let now = Date().timeIntervalSince1970 * 1000
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Pre-decode check to ensure structure safety
                _ = try OrderPage.parsePages(from: data)
                
                // Persist cache and save timestamp
                UserDefaults.standard.set(data, forKey: "orderOfServiceData")
                UserDefaults.standard.set(now, forKey: "lastOrderOfServiceUpdate")
                
                // Feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Notify reader view to reload pages dynamically
                NotificationCenter.default.post(name: Notification.Name("csi_liturgies_refreshed"), object: nil)
                print("[OrderOfService] Manual refresh succeeded.")
            } else {
                throw NSError(domain: "OrderOfServiceListView", code: 2, userInfo: [NSLocalizedDescriptionKey: "HTTP non-200 response"])
            }
        } catch {
            print("OrderOfServiceListView: Remote updates failed: \(error)")
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        isRefreshing = false
    }
}
