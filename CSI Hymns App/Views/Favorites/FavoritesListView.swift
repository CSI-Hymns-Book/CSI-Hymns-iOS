import SwiftUI
import Observation

/// View model managing locally bookmarked songs and synchronizing with SupabaseService.
@Observable
public final class FavoritesListViewModel {
    public var searchQuery = ""
    public var selectedCategory = 0 // 0 = Hymns, 1 = Keerthanes
    public var isLoading = false
    
    // In production, this binds directly to SupabaseService favorites caches
    public var favoriteHymns: [Hymn] = []
    public var favoriteKeerthanes: [Hymn] = []
    
    public init() {
        loadMockFavorites()
    }
    
    public var filteredFavorites: [Hymn] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let source = selectedCategory == 0 ? favoriteHymns : favoriteKeerthanes
        
        if query.isEmpty {
            return source
        } else {
            return source.filter { item in
                item.title.lowercased().contains(query) ||
                String(item.number).contains(query)
            }
        }
    }
    
    public func removeFavorite(_ hymn: Hymn) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if selectedCategory == 0 {
            favoriteHymns.removeAll { $0.id == hymn.id }
        } else {
            favoriteKeerthanes.removeAll { $0.id == hymn.id }
        }
    }
    
    private func loadMockFavorites() {
        isLoading = true
        // Mock favorites data for immediate UI rendering and compiler safety
        favoriteHymns = [
            Hymn(number: 25, title: "ಯೇಸುವೇ ನಿನ್ನ ಒಲವು ದೊಡ್ಡದು", signature: "L.M", lyricsKannada: "1. ಯೇಸುವೇ...", lyricsEnglish: "1. Jesus Thy Love..."),
            Hymn(number: 304, title: "ಕ್ರಿಸ್ತನೆ ಜಯಶಾಲಿ", signature: "C.M", lyricsKannada: "1. ಕ್ರಿಸ್ತನೆ ಜಯ...", lyricsEnglish: "1. Christ the Victor...")
        ]
        favoriteKeerthanes = [
            Hymn(number: 10, title: "ದೇವಕುಮಾರನೇ ಧನ್ಯಾವಾದಗಳು", signature: "6.7.7.7", lyricsKannada: "1. ದೇವಕುಮಾರನೇ...", lyricsEnglish: "1. Son of God...")
        ]
        isLoading = false
    }
}

/// A premium, glassmorphic favorites manager screen.
public struct FavoritesListView: View {
    @State private var viewModel = FavoritesListViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Glass deep blue background
                LinearGradient(
                    colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Glass Category Picker
                    pickerSegmentControl
                    
                    // Glass Search Bar
                    customSearchBar
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxHeight: .infinity)
                    } else if viewModel.filteredFavorites.isEmpty {
                        emptyStateView
                    } else {
                        favoritesScrollView
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Subviews
    
    private var pickerSegmentControl: some View {
        HStack(spacing: 0) {
            pickerButton(title: "Hymns", index: 0)
            pickerButton(title: "Keerthanes", index: 1)
        }
        .padding(4)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .padding(.top, 8)
    }
    
    private func pickerButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                viewModel.selectedCategory = index
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.selectedCategory == index ? Color.white.opacity(0.16) : Color.clear)
                )
        }
    }
    
    private var customSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            
            TextField("Search bookmarks...", text: $viewModel.searchQuery)
                .foregroundColor(.white)
                .accentColor(.white)
            
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            Text(viewModel.searchQuery.isEmpty ? "No Favorites Yet" : "No Matching Favorites")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(viewModel.searchQuery.isEmpty
                 ? "Tap the bookmark icon on any song lyric page to save them for offline access."
                 : "Try refining your search text to match your saved bookmarks.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var favoritesScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredFavorites) { song in
                    favoriteSongCell(song)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }
    
    private func favoriteSongCell(_ song: Hymn) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 42, height: 42)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18), lineWidth: 1))
                
                Text("🎵")
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(song.number): \(song.title)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                if !song.signature.isEmpty {
                    Text(song.signature)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            Button {
                viewModel.removeFavorite(song)
            } label: {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
