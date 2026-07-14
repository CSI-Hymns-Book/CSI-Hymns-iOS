import SwiftUI

/// A spectacular Liquid Glass landing portal active during festive seasons.
public struct ChristmasLandingView: View {
    @Binding var selectedTab: Int
    @State private var theme = ThemeManager.shared
    @State private var isShowingToast = false
    @State private var toastOffset: CGFloat = 100.0
    @State private var toastOpacity: Double = 0.0
    
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
                    // Dark mystical Christmas night sky overlay
                    LinearGradient(
                        colors: [Color(hex: "0D1B2A"), Color(hex: "132237"), Color(hex: "0D1B2A")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
                
                // ProMotion snowflake particle canvas handled app-wide via FestiveSnowfallOverlay
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header greetings
                        headerTitleRow
                            .padding(.top, 24)
                        
                        // Grouped Sections
                        VStack(spacing: 24) {
                            // Section 1: CSI Hymns & Keerthanes
                            VStack(alignment: .leading, spacing: 12) {
                                Text("CSI Hymns & Keerthanes")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(theme.accentColor)
                                    .padding(.horizontal, 4)
                                
                                Button {
                                    withAnimation {
                                        AppNavigationService.shared.activeSection = .csi
                                        selectedTab = 0
                                    }
                                } label: {
                                    CategoryGlassCard(
                                        title: "Hymns",
                                        subtitle: "ಕನ್ನಡ ಸಂಗೀತಗಳು",
                                        imageName: "hymn",
                                        gradients: [Color(hex: "2E7D32"), Color(hex: "1B5E20")],
                                        isHighlighted: false
                                    )
                                }
                                .buttonStyle(CategoryCardButtonStyle())
                                
                                Button {
                                    withAnimation {
                                        AppNavigationService.shared.activeSection = .csi
                                        selectedTab = 1
                                    }
                                } label: {
                                    CategoryGlassCard(
                                        title: "Keerthanes",
                                        subtitle: "ಕನ್ನಡ ಸಂಕೀರ್ತನೆಗಳು",
                                        imageName: "keerthane",
                                        gradients: [Color(hex: "1976D2"), Color(hex: "0D47A1")],
                                        isHighlighted: false
                                    )
                                }
                                .buttonStyle(CategoryCardButtonStyle())
                                
                                Button {
                                    withAnimation {
                                        AppNavigationService.shared.activeSection = .csi
                                        selectedTab = 2
                                    }
                                } label: {
                                    CategoryGlassCard(
                                        title: "Order of Service",
                                        subtitle: "ಸಿ.ಎಸ್.ಐ. ಆರಾಧನಾ ಕ್ರಮ",
                                        imageName: "order_of_service_book",
                                        gradients: [Color(hex: "C62828"), Color(hex: "8E0000")],
                                        isHighlighted: false
                                    )
                                }
                                .buttonStyle(CategoryCardButtonStyle())
                            }
                            
                            // Section 2: Mangalore Hymns
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Mangalore Hymns")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 4)
                                
                                Button {
                                    withAnimation {
                                        AppNavigationService.shared.activeSection = .mt
                                        selectedTab = 0
                                    }
                                } label: {
                                    CategoryGlassCard(
                                        title: "M.T. Hymns",
                                        subtitle: "ಮಂಗಳೂರು ಕನ್ನಡ ಸಂಗೀತಗಳು",
                                        imageName: "hymn",
                                        gradients: [Color(hex: "E67E22"), Color(hex: "D35400")],
                                        isHighlighted: true
                                    )
                                }
                                .buttonStyle(CategoryCardButtonStyle())
                            }
                            
                            // Section 3: Festive specials
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Christmas Specials")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(hex: "B22222"))
                                    .padding(.horizontal, 4)
                                
                                NavigationLink(destination: ChristmasCarolsListView()) {
                                    CategoryGlassCard(
                                        title: "Christmas Carols",
                                        subtitle: "Celebrate the season with festive songs",
                                        imageName: "hymn",
                                        gradients: [Color(hex: "C62828"), Color(hex: "8E0000")],
                                        isHighlighted: true
                                    )
                                }
                                .buttonStyle(CategoryCardButtonStyle())
                            }
                        }
                        
                        // Easter egg footer
                        footerButton
                            .padding(.top, 36)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal)
                }
                .scrollContentBackground(.hidden)
                .contentShape(Rectangle())
                .swipeToNavigate(selectedTab: $selectedTab, maxTab: 3)
                
                // Toast alert overlay
                if isShowingToast {
                    peaceToastOverlay
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .csiGlassNavigationBar(theme: theme)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerTitleRow: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "B22222").opacity(0.2))
                    .frame(width: 58, height: 58)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "B22222").opacity(0.35), lineWidth: 1))
                
                Text("🎄")
                    .font(.system(size: 28))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Merry Christmas!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Glory to God in the highest")
                    .font(.system(size: 14, weight: .medium).italic())
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Text("⭐")
                .font(.system(size: 24))
        }
    }
    
    private var footerButton: some View {
        Button {
            triggerPeaceToast()
        } label: {
            HStack(spacing: 8) {
                Text("❄️")
                Text("Peace on Earth")
                    .font(.system(size: 13, weight: .semibold).italic())
                Text("❄️")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
            .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var peaceToastOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Text("🕊️")
                    .font(.system(size: 18))
                
                Text("Goodwill to all men")
                    .font(.system(size: 14, weight: .semibold).italic())
                    .foregroundColor(.white)
                
                Text("✨")
                    .font(.system(size: 15))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(hex: "1B5E20").opacity(0.95))
                    .shadow(color: Color(hex: "2E7D32").opacity(0.5), radius: 12, x: 0, y: 0)
            )
            .offset(y: toastOffset)
            .opacity(toastOpacity)
            .padding(.bottom, 120)
        }
    }
    
    private func triggerPeaceToast() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            isShowingToast = true
            toastOffset = 0.0
            toastOpacity = 1.0
        }
        
        // Auto-dismiss in 3s
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.35)) {
                    toastOffset = 100.0
                    toastOpacity = 0.0
                }
            }
            try? await Task.sleep(for: .seconds(0.4))
            await MainActor.run {
                isShowingToast = false
            }
        }
    }
}

// MARK: - Reusable Category Card Widget
struct CategoryGlassCard: View {
    let title: String
    let subtitle: String
    let imageName: String
    let gradients: [Color]
    let isHighlighted: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon plate
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 52, height: 52)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.35), lineWidth: 1))
                
                Image(imageName)
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    if isHighlighted {
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white)
                            .cornerRadius(6)
                            .foregroundColor(gradients.first ?? .green)
                    }
                }
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            Spacer()
            
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.white)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: gradients, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: (gradients.first ?? .clear).opacity(0.4), radius: isHighlighted ? 12 : 6, x: 0, y: 4)
        )
    }
}

/// Press-scale style for NavigationLink cards without stealing tap gestures.
private struct CategoryCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
