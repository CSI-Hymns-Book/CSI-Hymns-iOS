import SwiftUI
import Observation

/// A premium, glassmorphic view rendering the list of songs in a specific custom category folder.
public struct CustomCategorySongsListView: View {
    @State private var categoriesViewModel = CustomCategoriesViewModel()
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
            // Immersive Deep Glass Gradient Background
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingDesigner = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: &isShowingDesigner, onDismiss: {
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
                .foregroundColor(.white.opacity(0.3))
            
            Text("Folder is Empty")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text("Tap the plus icon in the top right to start adding hymns and keerthanes to this collection.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
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
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 42, height: 42)
                                
                                Text("🎵")
                                    .font(.system(size: 18))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(song.number): \(song.title)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                
                                if !song.signature.isEmpty {
                                    Text(song.signature)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.5))
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
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
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
        categoriesViewModel = CustomCategoriesViewModel() // Refresh
        
        guard let folder = categoriesViewModel.categories.first(where: { $0.id == categoryId }) else {
            songs = []
            isLoading = false
            return
        }
        
        // Match mock seed song keys "hymn_1" or "hymn_25" to show items instantly
        var matched: [Hymn] = []
        let hymnsSeed = [
            Hymn(number: 1, title: "ಪರಮ ತಂದೆಯೇ ಪರಮಾದರದಿ", signature: "C.M", lyricsKannada: "1. ಪರಮ തಂದೆಯೇ...", lyricsEnglish: "1. Heavenly Father..."),
            Hymn(number: 25, title: "ಯೇಸುವೇ ನಿನ್ನ ಒಲವು ದೊಡ್ಡದು", signature: "L.M", lyricsKannada: "1. ಯೇಸುವೇ...", lyricsEnglish: "1. Jesus Thy Love..."),
            Hymn(number: 110, title: "ಮಹಾ ಪ್ರಭುವೇ ಸ್ತುತಿ ಹಾಗೂ ಘನತೆ", signature: "D.C.M", lyricsKannada: "1. ಮಹಾ...", lyricsEnglish: "1. O Great Lord..."),
            Hymn(number: 212, title: "ಶುದ್ಧಾತ್ಮನೇ ನೀ ಬಾರಯ್ಯ", signature: "7.7.7.7", lyricsKannada: "1. ಶುದ್ಧಾತ್ಮನೇ...", lyricsEnglish: "1. Holy Spirit Come..."),
            Hymn(number: 304, title: "ಕ್ರಿಸ್ತನೆ ಜಯಶಾಲಿ", signature: "C.M", lyricsKannada: "1. ಕ್ರಿಸ್ತನೆ...", lyricsEnglish: "1. Christ the Victor...")
        ]
        let keerthanesSeed = [
            Hymn(number: 1, title: "ದೇವಕುಮಾರನೇ ಧನ್ಯಾವಾದಗಳು", signature: "6.7.7.7", lyricsKannada: "1. ದೇವಕುಮಾರನೇ...", lyricsEnglish: "1. Son of God..."),
            Hymn(number: 10, title: "ಯೇಸು ನಮ್ಮ ಆಧಾರ", signature: "C.M", lyricsKannada: "1. ಯೇಸು...", lyricsEnglish: "1. Jesus our Anchor...")
        ]
        
        for key in folder.songIds {
            if key.hasPrefix("hymn_") {
                let num = Int(key.replacingOccurrences(of: "hymn_", with: "")) ?? 0
                if let song = hymnsSeed.first(where: { $0.number == num }) {
                    matched.append(song)
                }
            } else if key.hasPrefix("keerthane_") {
                let num = Int(key.replacingOccurrences(of: "keerthane_", with: "")) ?? 0
                if let song = keerthanesSeed.first(where: { $0.number == num }) {
                    matched.append(song)
                }
            }
        }
        
        self.songs = matched
        self.isLoading = false
    }
    
    private func deleteSongFromFolder(_ song: Hymn) {
        let prefix = song.signature == "6.7.7.7" ? "keerthane_" : "hymn_"
        let targetKey = "\(prefix)\(song.number)"
        
        guard let idx = categoriesViewModel.categories.firstIndex(where: { $0.id == categoryId }) else { return }
        
        var folder = categoriesViewModel.categories[idx]
        folder.songIds.removeAll { $0 == targetKey }
        categoriesViewModel.categories[idx] = folder
        
        // Save
        if let encoded = try? JSONEncoder().encode(categoriesViewModel.categories) {
            UserDefaults.standard.set(encoded, forKey: "csi_custom_categories_local_v1")
        }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Re-load list
        loadFolderSongs()
    }
}
