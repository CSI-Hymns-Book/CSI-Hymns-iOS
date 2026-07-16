import SwiftUI

/// Core Navigation Hub of the application.
/// Automatically alters tab selections and layouts based on active Christmas seasons.
public struct RootTabView: View {
    @State private var christmasMode = ChristmasModeService.shared
    @State private var theme = ThemeManager.shared
    @State private var selectedTab = 0
    @State private var menuShowcaseStep = 0
    @State private var isShowingMenuShowcase = UserDefaults.standard.bool(forKey: "csi_pending_menu_showcase")
    private var navigationManager = AppNavigationService.shared
    @State private var activeAnnouncement: InAppMessage? = nil
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if let activeSection = navigationManager.activeSection {
                tabViewContent(for: activeSection)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                    .zIndex(1)
            } else {
                if christmasMode.isChristmasTime {
                    ChristmasLandingView(selectedTab: $selectedTab)
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                        .zIndex(0)
                } else {
                    HomeSelectorView(selectedTab: $selectedTab)
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                        .zIndex(0)
                }
            }
            
            if christmasMode.isChristmasTime {
                FestiveSnowfallOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            if isShowingMenuShowcase {
                MenuShowcaseOverlay(
                    isPresented: $isShowingMenuShowcase,
                    step: menuShowcaseStep,
                    onNext: {
                        if menuShowcaseStep >= 4 {
                            finishMenuShowcase()
                        } else {
                            menuShowcaseStep += 1
                        }
                    },
                    onSkip: finishMenuShowcase
                )
            }
            
            // Centered active announcement dialog modal overlay
            if let ann = activeAnnouncement {
                ZStack {
                    // Dimmed background
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    // Dialog Card
                    VStack(spacing: 20) {
                        // Header Info
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(theme.accentColor.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                    .overlay(Circle().stroke(theme.accentColor.opacity(0.35), lineWidth: 1))
                                
                                Text("📢")
                                    .font(.system(size: 22))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Announcement")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(theme.textPrimary)
                                
                                Text("Important Update")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.textSecondary)
                            }
                            Spacer()
                            
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    AnnouncementsService.shared.dismissBroadcast(id: ann.id)
                                    activeAnnouncement = nil
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(theme.textSecondary.opacity(0.7))
                                    .font(.system(size: 22))
                            }
                        }
                        
                        // Image if available
                        if let imgUrl = ann.imageUrl, let url = URL(string: imgUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 160)
                                    .cornerRadius(12)
                            } placeholder: {
                                ProgressView().tint(theme.accentColor)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Announcement Title
                        Text(ann.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        // Message text
                        ScrollView {
                            Text(ann.displayMessage)
                                .font(.system(size: 13.5))
                                .foregroundColor(theme.textSecondary)
                                .lineSpacing(4)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 140)
                        
                        // Action button (if URL exists)
                        if let actText = ann.actionText, let actUrl = ann.actionUrl, let url = URL(string: actUrl) {
                            Button {
                                UIApplication.shared.open(url)
                            } label: {
                                Text(actText)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(theme.accentColor)
                                    .cornerRadius(12)
                            }
                        }
                        
                        // Dismiss Button
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                AnnouncementsService.shared.dismissBroadcast(id: ann.id)
                                activeAnnouncement = nil
                            }
                        } label: {
                            Text("Okay")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(theme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(theme.surfaceColor)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.strokeColor, lineWidth: 1)
                                )
                        }
                    }
                    .padding(20)
                    .background(theme.cardBackground)
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(theme.strokeColor, lineWidth: 1)
                    )
                    .padding(.horizontal, 30)
                    .shadow(color: Color.black.opacity(0.25), radius: 15, y: 10)
                    .transition(.scale.combined(with: .opacity))
                }
                .zIndex(100)
            }
        }
        .task {
            activeAnnouncement = await AnnouncementsService.shared.getActiveUndismissedBroadcast()
            await navigationManager.fetchMangaloreHymnsEnabled()
            if !navigationManager.isMangaloreHymnsEnabled {
                navigationManager.activeSection = .csi
            }
        }
    }
    
    private func finishMenuShowcase() {
        isShowingMenuShowcase = false
        UserDefaults.standard.set(false, forKey: "csi_pending_menu_showcase")
    }
    
    @ViewBuilder
    private func tabViewContent(for section: BookSection) -> some View {
        TabView(selection: $selectedTab) {
            if section == .csi {
                // MARK: - CSI Section Tabs (5 Tabs)
                HymnsListView(title: "Hymns", section: .hymns, selectedTab: $selectedTab)
                    .tabItem {
                        Label("Hymns", systemImage: "music.note")
                    }
                    .tag(0)
                
                HymnsListView(title: "Keerthanes", section: .keerthanes, selectedTab: $selectedTab)
                    .tabItem {
                        Label("Keerthanes", systemImage: "music.note.list")
                    }
                    .tag(1)
                
                OrderOfServiceListView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Service", systemImage: "doc.richtext")
                    }
                    .tag(2)
                
                CustomCategoriesView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Categories", systemImage: "folder")
                    }
                    .tag(3)
                
                FavoritesListView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Favorites", systemImage: "heart.fill")
                    }
                    .tag(4)
            } else {
                // MARK: - MT Section Tabs (3 Tabs)
                HymnsListView(title: "M.T. Hymns", section: .mt, selectedTab: $selectedTab)
                    .tabItem {
                        Label("M.T.", systemImage: "music.quarternote.3")
                    }
                    .tag(0)
                
                CustomCategoriesView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Categories", systemImage: "folder")
                    }
                    .tag(1)
                
                FavoritesListView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Favorites", systemImage: "heart.fill")
                    }
                    .tag(2)
            }
        }
        .id("\(section.rawValue)-tabs")
        .toolbarBackground(.automatic, for: .tabBar)
        .tint(theme.accentColor)
        .onChange(of: selectedTab) { oldValue, newValue in
            let tabName = getTabName(for: newValue, section: section)
            PostHogService.shared.track(event: "tab_switched", properties: [
                "from_tab": oldValue,
                "to_tab": newValue,
                "tab_name": tabName
            ])
            PostHogService.shared.trackScreen(tabName)
        }
        .onAppear {
            theme.updateSystemAppearance()
            PostHogService.shared.trackScreen(getTabName(for: selectedTab, section: section))
        }
    }
    
    private func getTabName(for index: Int, section: BookSection) -> String {
        if section == .csi {
            switch index {
            case 0: return "Hymns"
            case 1: return "Keerthanes"
            case 2: return "Service"
            case 3: return "Categories"
            case 4: return "Favorites"
            default: return "Unknown"
            }
        } else {
            switch index {
            case 0: return "M.T. Hymns"
            case 1: return "Categories"
            case 2: return "Favorites"
            default: return "Unknown"
            }
        }
    }
}

// MARK: - Swipe Gesture Tab Switcher Extension

public struct SwipeNavigationModifier: ViewModifier {
    @Binding var selectedTab: Int
    let maxTab: Int
    
    public func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 45, coordinateSpace: .local)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        
                        // 1. Edge swipe from left -> pop back to home selector
                        if value.startLocation.x < 45 && horizontal > 70 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                AppNavigationService.shared.activeSection = nil
                            }
                            return
                        }
                        
                        // Ensure predominantly horizontal drag to prevent vertical scroll overrides
                        guard abs(horizontal) > abs(vertical) * 1.8 else { return }
                        
                        if horizontal > 60 {
                            // Swiped right -> Show previous tab
                            if selectedTab > 0 {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                                    selectedTab -= 1
                                }
                            }
                        } else if horizontal < -60 {
                            // Swiped left -> Show next tab
                            if selectedTab < maxTab {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                                    selectedTab += 1
                                }
                            }
                        }
                    }
            )
    }
}

extension View {
    /// Enables swipe gesture tab navigation with horizontal velocity protection
    public func swipeToNavigate(selectedTab: Binding<Int>, maxTab: Int) -> some View {
        self.modifier(SwipeNavigationModifier(selectedTab: selectedTab, maxTab: maxTab))
    }
}
