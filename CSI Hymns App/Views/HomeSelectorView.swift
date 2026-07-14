import SwiftUI

public struct HomeSelectorView: View {
    @State private var navigationManager = AppNavigationService.shared
    @State private var theme = ThemeManager.shared
    @Binding var selectedTab: Int
    
    // Animation states for the dynamic mesh background
    @State private var animateBlob1 = false
    @State private var animateBlob2 = false
    
    public init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Base background color
                theme.backgroundColor.ignoresSafeArea()
                
                // Animated Premium Ambient Glow Mesh
                if theme.activeTheme != .amoled {
                    ZStack {
                        // Blob 1: Accent Color (Deep Blue/Indigo)
                        Circle()
                            .fill(theme.accentColor.opacity(0.18))
                            .frame(width: 320, height: 320)
                            .blur(radius: 70)
                            .offset(x: animateBlob1 ? -90 : 90, y: animateBlob1 ? -150 : 150)
                        
                        // Blob 2: Orange/Warm Ambient Glow
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 280, height: 280)
                            .blur(radius: 70)
                            .offset(x: animateBlob2 ? 100 : -100, y: animateBlob2 ? 100 : -100)
                    }
                    .ignoresSafeArea()
                }
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Welcome Logo & Elegant Greeting
                        VStack(spacing: 8) {
                            // Glowing Emblem
                            ZStack {
                                Circle()
                                    .fill(theme.accentColor.opacity(0.15))
                                    .frame(width: 76, height: 76)
                                    .blur(radius: 4)
                                
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [theme.accentColor, theme.accentColor.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                                    .frame(width: 70, height: 70)
                                    .background(Circle().fill(theme.cardBackground.opacity(0.6)))
                                
                                Image("app_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 36, height: 36)
                            }
                            .padding(.bottom, 4)
                            
                            Text("Choose Hymn Book")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundColor(theme.textPrimary)
                            
                            Text("Select CSI Hymns and Mangalore Hymns")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 28)
                        
                        // Section 1: CSI Hymns & Keerthanes
                        premiumSectionCard(title: "CSI Hymns & Keerthanes", color: theme.accentColor, iconName: "book.pages") {
                            VStack(spacing: 8) {
                                premiumSubItemRow(
                                    title: "CSI Hymns",
                                    subtitle: "ಕನ್ನಡ ಸಂಗೀತಗಳು",
                                    assetName: "hymn",
                                    glowColor: theme.accentColor
                                ) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        navigationManager.activeSection = .csi
                                        selectedTab = 0
                                    }
                                }
                                
                                Divider().background(theme.strokeColor.opacity(0.3))
                                
                                premiumSubItemRow(
                                    title: "CSI Keerthanes",
                                    subtitle: "ಕನ್ನಡ ಸಂಕೀರ್ತನೆಗಳು",
                                    assetName: "keerthane",
                                    glowColor: Color.teal
                                ) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        navigationManager.activeSection = .csi
                                        selectedTab = 1
                                    }
                                }
                                
                                Divider().background(theme.strokeColor.opacity(0.3))
                                
                                premiumSubItemRow(
                                    title: "CSI Order of Service",
                                    subtitle: "ಸಿ.ಎಸ್.ಐ. ಆರಾಧನಾ ಕ್ರಮ",
                                    assetName: "order_of_service_book",
                                    glowColor: Color.purple
                                ) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        navigationManager.activeSection = .csi
                                        selectedTab = 2
                                    }
                                }
                            }
                        }
                        
                        // Section 2: Mangalore Hymns
                        premiumSectionCard(title: "Mangalore Hymns", color: Color.orange, iconName: "bookmark") {
                            premiumSubItemRow(
                                title: "M.T. Hymns",
                                subtitle: "ಮಂಗಳೂರು ಕನ್ನಡ ಸಂಗೀತಗಳು",
                                assetName: "hymn",
                                glowColor: Color.orange
                            ) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    navigationManager.activeSection = .mt
                                    selectedTab = 0
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .csiGlassNavigationBar(theme: theme)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        ZStack {
                            Circle()
                                .fill(theme.cardBackground.opacity(0.6))
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Circle().stroke(theme.cardStroke, lineWidth: 1)
                                )
                            
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.textPrimary)
                        }
                    }
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                    animateBlob1.toggle()
                }
                withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                    animateBlob2.toggle()
                }
            }
        }
    }
    
    // MARK: - Premium Glassmorphic Cards Builder
    
    private func premiumSectionCard<Content: View>(
        title: String,
        color: Color,
        iconName: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header label with badge
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.12))
                        .frame(width: 26, height: 26)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textPrimary)
            }
            .padding(.leading, 4)
            
            // Frosted Glass Card container
            VStack {
                content()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(theme.cardBackground.opacity(0.55))
                    .background(
                        theme.cardBackground.opacity(0.2)
                            .blur(radius: 20)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [theme.cardStroke.opacity(0.6), theme.cardStroke.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - Premium Clickable Card Item Rows
    
    private func premiumSubItemRow(
        title: String,
        subtitle: String,
        assetName: String,
        glowColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                // Colored Icon Glow Frame
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(glowColor.opacity(0.15))
                        .frame(width: 46, height: 46)
                    
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [glowColor.opacity(0.5), glowColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 46, height: 46)
                    
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.textSecondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(theme.textSecondary.opacity(0.08))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(theme.textPrimary.opacity(0.5))
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressedScaleButtonStyle())
    }
}

// MARK: - Button Press Scaling Feedback Effect

struct PressedScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
