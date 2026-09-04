import SwiftUI
import Observation

/// A premium, glassmorphic view rendering the list of songs in a specific custom category folder.
public struct CustomCategorySongsListView: View {
    @State private var theme = ThemeManager.shared
    @State private var categoriesViewModel = CustomCategoriesViewModel.shared
    let categoryId: String
    
    @State private var songs: [Hymn] = []
    @State private var isLoading = false
    @State private var isShowingDesigner = false
    
    public init(categoryId: String) {
        self.categoryId = categoryId
    }
    
    /// Finds the active category name matching our target ID.
    private var categoryName: String {
        categoriesViewModel.categories.first(where: { $0.id == categoryId })?.name ?? "Collection"
    }
    
    public var body: some View {
        ZStack {
            // Adaptive theme backgrounds
            theme.backgroundColor
                .ignoresSafeArea()
            
            if theme.activeTheme != .amoled {
                theme.backgroundGradient
                    .ignoresSafeArea()
            }
            
            VStack {
                if isLoading {
                    ProgressView()
                        .tint(theme.textPrimary)
                        .frame(maxHeight: .infinity)
                } else if songs.isEmpty {
                    emptyStateView
                } else {
                    songsList
                }
            }
        }
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingDesigner = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(theme.textPrimary)
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isShowingDesigner, onDismiss: {
            loadFolderSongs()
        }) {
            CustomCategoryDesignerView(categoryId: categoryId)
        }
        .onAppear {
            loadFolderSongs()
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 54))
                .foregroundColor(theme.textSecondary.opacity(0.35))
            
            Text("Folder is Empty")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text("Tap the plus icon in the top right to start adding hymns and keerthanes to this collection.")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var songsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(songs) { song in
                    NavigationLink(destination: HymnDetailView(hymn: song)) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(theme.accentColor.opacity(0.12))
                                    .frame(width: 42, height: 42)
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
                                    .multilineTextAlignment(.leading)
                                
                                if !song.signature.isEmpty {
                                    Text(song.signature)
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                            Spacer()
                            
                            // Delete button
                            Button {
                                deleteSongFromFolder(song)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.8))
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
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Controller Actions
    
    private func loadFolderSongs() {
        isLoading = true
        categoriesViewModel = CustomCategoriesViewModel.shared
        
        guard let folder = categoriesViewModel.categories.first(where: { $0.id == categoryId }) else {
            songs = []
            isLoading = false
            return
        }
        
        var matched: [Hymn] = []
        
        for key in folder.songIds {
            guard let parsed = SupabaseService.parseSongKey(key) else { continue }
            let titlePrefix: String
            switch parsed.type {
            case "keerthane": titlePrefix = "Keerthane"
            case "mt": titlePrefix = "M.T."
            default: titlePrefix = "Hymn"
            }
            if let song = FavoritesManager.shared.getHymnFromCache(number: parsed.id, type: parsed.type) {
                matched.append(song)
            } else {
                matched.append(Hymn(number: parsed.id, title: "\(titlePrefix) \(parsed.id)", signature: "", lyricsKannada: "", lyricsEnglish: "", type: parsed.type))
            }
        }
        
        self.songs = matched
        self.isLoading = false
    }
    
    private func deleteSongFromFolder(_ song: Hymn) {
        let targetKey = "\(song.type)_\(song.number)"
        categoriesViewModel.removeSong(categoryId: categoryId, songKey: targetKey)
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Re-load list
        loadFolderSongs()
    }
}
