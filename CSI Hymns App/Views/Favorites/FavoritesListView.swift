import SwiftUI
import Observation

/// A premium, glassmorphic Favorites Manager screen supporting all app themes.
public struct FavoritesListView: View {
    @Binding var selectedTab: Int
    @State private var theme = ThemeManager.shared
    @State private var favoritesManager = FavoritesManager.shared
    @State private var searchQuery = ""
    @State private var selectedCategory = 0 // 0 = Hymns, 1 = Keerthanes
    
    private var maxTab: Int {
        ChristmasModeService.shared.isChristmasTime ? 3 : 4
    }
    
    public init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }
    
    /// Filters favorites based on the active tab selection and query
    private var filteredFavorites: [Hymn] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let targetType = selectedCategory == 0 ? "hymn" : "keerthane"
        let source = favoritesManager.favorites.filter { $0.type == targetType }
        
        if query.isEmpty {
            return source
        } else {
            return source.filter { item in
                item.title.lowercased().contains(query) ||
                String(item.number).contains(query)
            }
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive theme background
                theme.backgroundColor
                    .ignoresSafeArea()
                
                if theme.activeTheme != .amoled {
                    theme.backgroundGradient
                        .ignoresSafeArea()
                }
                
                VStack(spacing: 16) {
                    // Glass Category Picker Segment
                    pickerSegmentControl
                    
                    // Themed Search Bar
                    customSearchBar
                    
                    if filteredFavorites.isEmpty {
                        emptyStateView
                            .transition(.opacity)
                    } else {
                        favoritesScrollView
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .csiGlassNavigationBar(theme: theme)
        }
    }
    
    // MARK: - Subviews
    
    private var pickerSegmentControl: some View {
        HStack(spacing: 0) {
            pickerButton(title: "Hymns", index: 0)
            pickerButton(title: "Keerthanes", index: 1)
        }
        .padding(4)
        .background(theme.surfaceColor)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.strokeColor, lineWidth: 1))
        .padding(.top, 8)
    }
    
    private func pickerButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCategory = index
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedCategory == index ? theme.textPrimary.opacity(0.12) : Color.clear)
                )
        }
    }
    
    private var customSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.textSecondary)
            
            TextField("Search bookmarks...", text: $searchQuery)
                .foregroundColor(theme.textPrimary)
                .accentColor(theme.textPrimary)
                .keyboardType(.default)
            
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.surfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.strokeColor, lineWidth: 1)
                )
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 54))
                .foregroundColor(theme.textSecondary.opacity(0.35))
            
            Text(searchQuery.isEmpty ? "No Favorites Yet" : "No Matching Favorites")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text(searchQuery.isEmpty
                 ? "Tap the heart icon on any song lyric page to save them for offline access."
                 : "Try refining your search text to match your saved bookmarks.")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxHeight: .infinity)
        // Enable swiping to other tabs on empty state screen
        .contentShape(Rectangle())
        .swipeToNavigate(selectedTab: $selectedTab, maxTab: maxTab)
    }
    
    private var favoritesScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredFavorites) { song in
                    NavigationLink(destination: HymnDetailView(hymn: song)) {
                        favoriteSongCell(song)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        // Enable swiping to other tabs on list view scroll
        .swipeToNavigate(selectedTab: $selectedTab, maxTab: maxTab)
    }
    
    private func favoriteSongCell(_ song: Hymn) -> some View {
        HStack(spacing: 16) {
            // Premium hierarchical song category notation icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.accentColor.opacity(0.25), lineWidth: 1))
                
                Image(song.type == "keerthane" ? "keerthane" : "hymn")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(song.number): \(song.title)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                
                if !song.signature.isEmpty {
                    Text(song.signature)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(theme.surfaceColor)
                        )
                }
            }
            
            Spacer()
            
            // Scaled favorite hearts
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    favoritesManager.toggleFavorite(song: song)
                }
            } label: {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 20))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(theme.cardStroke, lineWidth: 1)
                )
                .shadow(color: theme.shadowColor, radius: 4, y: 2)
        )
    }
}
