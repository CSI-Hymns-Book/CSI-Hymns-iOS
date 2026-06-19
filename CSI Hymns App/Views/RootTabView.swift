import SwiftUI

/// Core Navigation Hub of the application.
/// Automatically alters tab selections and layouts based on active Christmas seasons.
public struct RootTabView: View {
    @State private var christmasMode = ChristmasModeService.shared
    @State private var selectedTab = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            if christmasMode.isChristmasTime {
                // MARK: - Christmas Mode (4 Tabs)
                ChristmasLandingView()
                    .tabItem {
                        Label("Christmas", systemImage: "sparkles")
                    }
                    .tag(0)
                
                OrderOfServiceListView()
                    .tabItem {
                        Label("Service", systemImage: "doc.richtext")
                    }
                    .tag(1)
                
                CustomCategoriesView()
                    .tabItem {
                        Label("Categories", systemImage: "folder")
                    }
                    .tag(2)
                
                FavoritesListView()
                    .tabItem {
                        Label("Favorites", systemImage: "bookmark.fill")
                    }
                    .tag(3)
                
            } else {
                // MARK: - Normal Mode (5 Tabs)
                HymnsListView(title: "Hymns", isKeerthanes: false)
                    .tabItem {
                        Label("Hymns", systemImage: "music.note")
                    }
                    .tag(0)
                
                HymnsListView(title: "Keerthanes", isKeerthanes: true)
                    .tabItem {
                        Label("Keerthanes", systemImage: "music.note.list")
                    }
                    .tag(1)
                
                OrderOfServiceListView()
                    .tabItem {
                        Label("Service", systemImage: "doc.richtext")
                    }
                    .tag(2)
                
                CustomCategoriesView()
                    .tabItem {
                        Label("Categories", systemImage: "folder")
                    }
                    .tag(3)
                
                FavoritesListView()
                    .tabItem {
                        Label("Favorites", systemImage: "bookmark.fill")
                    }
                    .tag(4)
            }
        }
        .tint(christmasMode.isChristmasTime ? Color(hex: "B22222") : Color.blue)
        .onAppear {
            // Re-hydrate tab selections on switching modes
            selectedTab = 0
        }
    }
}
