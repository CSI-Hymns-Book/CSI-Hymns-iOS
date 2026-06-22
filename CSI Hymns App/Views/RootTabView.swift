import SwiftUI

/// Core Navigation Hub of the application.
/// Automatically alters tab selections and layouts based on active Christmas seasons.
public struct RootTabView: View {
    @State private var christmasMode = ChristmasModeService.shared
    @State private var theme = ThemeManager.shared
    @State private var selectedTab = 0
    @State private var menuShowcaseStep = 0
    @State private var isShowingMenuShowcase = UserDefaults.standard.bool(forKey: "csi_pending_menu_showcase")
    
    public init() {}
    
    public var body: some View {
        ZStack {
            tabViewContent
            
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
        }
    }
    
    private func finishMenuShowcase() {
        isShowingMenuShowcase = false
        UserDefaults.standard.set(false, forKey: "csi_pending_menu_showcase")
    }
    
    @ViewBuilder
    private var tabViewContent: some View {
        TabView(selection: $selectedTab) {
            if christmasMode.isChristmasTime {
                // MARK: - Christmas Mode (4 Tabs)
                ChristmasLandingView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Christmas", systemImage: "sparkles")
                    }
                    .tag(0)
                
                OrderOfServiceListView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Service", systemImage: "doc.richtext")
                    }
                    .tag(1)
                
                CustomCategoriesView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Categories", systemImage: "folder")
                    }
                    .tag(2)
                
                FavoritesListView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Favorites", systemImage: "heart.fill")
                    }
                    .tag(3)
                
            } else {
                // MARK: - Normal Mode (5 Tabs)
                HymnsListView(title: "Hymns", isKeerthanes: false, selectedTab: $selectedTab)
                    .tabItem {
                        Label("Hymns", systemImage: "music.note")
                    }
                    .tag(0)
                
                HymnsListView(title: "Keerthanes", isKeerthanes: true, selectedTab: $selectedTab)
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
            }
        }
        .id(christmasMode.isChristmasTime ? "christmas-tabs" : "normal-tabs")
        .toolbarBackground(.automatic, for: .tabBar)
        .tint(christmasMode.isChristmasTime ? Color(hex: "B22222") : Color.blue)
        .onChange(of: christmasMode.isChristmasTime) { _, _ in
            selectedTab = 0
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            let tabName = getTabName(for: newValue)
            PostHogService.shared.track(event: "tab_switched", properties: [
                "from_tab": oldValue,
                "to_tab": newValue,
                "tab_name": tabName
            ])
            PostHogService.shared.trackScreen(tabName)
        }
        .onAppear {
            selectedTab = 0
            theme.updateSystemAppearance()
            PostHogService.shared.trackScreen(getTabName(for: 0))
            PostHogService.shared.track(event: "app_launched")
        }
    }
    
    private func getTabName(for index: Int) -> String {
        if christmasMode.isChristmasTime {
            switch index {
            case 0: return "Christmas"
            case 1: return "Service"
            case 2: return "Categories"
            case 3: return "Favorites"
            default: return "Unknown"
            }
        } else {
            switch index {
            case 0: return "Hymns"
            case 1: return "Keerthanes"
            case 2: return "Service"
            case 3: return "Categories"
            case 4: return "Favorites"
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
