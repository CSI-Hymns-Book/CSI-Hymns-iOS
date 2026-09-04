import SwiftUI

/// A premium, glassmorphic view rendering the user's recently read hymns and keerthanes.
public struct RecentSongsView: View {
    @State private var theme = ThemeManager.shared
    @State private var recentsService = RecentSongsService.shared
    @State private var recentSongsList: [Hymn] = []
    
    public init() {}
    
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
                if recentSongsList.isEmpty {
                    emptyStateView
                } else {
                    recentsList
                }
            }
        }
        .navigationTitle("Recently Viewed")
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        .toolbar {
            if !recentSongsList.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        recentsService.clearAllRecents()
                        loadMatchedSongs()
                    } label: {
                        Text("Clear")
                            .foregroundColor(.red)
                            .font(.system(size: 15, weight: .bold))
                    }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            loadMatchedSongs()
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 54))
                .foregroundColor(theme.textSecondary.opacity(0.35))
            
            Text("No Reading History")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text("Hymns and keerthanes you read will appear here for quick access later.")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var recentsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(recentSongsList) { song in
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
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(theme.textSecondary.opacity(0.7))
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
    
    private func loadMatchedSongs() {
        var matched: [Hymn] = []
        
        for key in recentsService.recentSongKeys {
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
        
        self.recentSongsList = matched
    }
}
