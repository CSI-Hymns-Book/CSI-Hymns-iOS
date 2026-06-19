import SwiftUI

/// A premium, glassmorphic view rendering the user's recently read hymns and keerthanes.
public struct RecentSongsView: View {
    @State private var recentsService = RecentSongsService.shared
    @State private var recentSongsList: [Hymn] = []
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Glass background
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
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
        .onAppear {
            loadMatchedSongs()
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 54))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No Reading History")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text("Hymns and keerthanes you read will appear here for quick access later.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
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
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.3))
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
    
    // MARK: - Helpers
    
    private func loadMatchedSongs() {
        let hymnsSeed = [
            Hymn(number: 1, title: "ಪರಮ ತಂದೆಯೇ ಪರಮಾದರದಿ", signature: "C.M", lyricsKannada: "1. ಪರಮ...", lyricsEnglish: "1. Heavenly Father..."),
            Hymn(number: 25, title: "ಯೇಸುವೇ ನಿನ್ನ ಒಲವು ದೊಡ್ಡದು", signature: "L.M", lyricsKannada: "1. ಯೇಸುವೇ...", lyricsEnglish: "1. Jesus Thy Love..."),
            Hymn(number: 110, title: "ಮಹಾ ಪ್ರಭುವೇ ಸ್ತುತಿ ಹಾಗೂ ಘನತೆ", signature: "D.C.M", lyricsKannada: "1. ಮಹಾ...", lyricsEnglish: "1. O Great Lord..."),
            Hymn(number: 212, title: "ಶುದ್ಧಾತ್ಮನೇ ನೀ ಬಾರಯ್ಯ", signature: "7.7.7.7", lyricsKannada: "1. ಶುದ್ಧಾತ್ಮನೇ...", lyricsEnglish: "1. Holy Spirit Come..."),
            Hymn(number: 304, title: "ಕ್ರಿಸ್ತನೆ ಜಯಶಾಲಿ", signature: "C.M", lyricsKannada: "1. ಕ್ರಿಸ್ತನೆ...", lyricsEnglish: "1. Christ the Victor...")
        ]
        let keerthanesSeed = [
            Hymn(number: 1, title: "ದೇವಕುಮಾರನೇ ಧನ್ಯಾವಾದಗಳು", signature: "6.7.7.7", lyricsKannada: "1. ದೇವಕುಮಾರನೇ...", lyricsEnglish: "1. Son of God..."),
            Hymn(number: 10, title: "ಯೇಸು ನಮ್ಮ ಆಧಾರ", signature: "C.M", lyricsKannada: "1. ಯೇಸು...", lyricsEnglish: "1. Jesus our Anchor...")
        ]
        
        var matched: [Hymn] = []
        
        for key in recentsService.recentSongKeys {
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
        
        self.recentSongsList = matched
    }
}
