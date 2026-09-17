import SwiftUI

/// Premium, high-legibility stanza reader designed specifically for Apple Watch display.
/// Uses LazyVStack and pre-parsed stanzas for instantaneous 0ms presentation.
public struct WatchHymnReaderView: View {
    public let hymn: Hymn
    
    @ObservedObject private var favStore = WatchFavoritesStore.shared
    @ObservedObject private var setlistStore = WatchSetlistStore.shared
    @AppStorage("watch_lyrics_lang") private var lyricsLanguage: String = "kannada" // "kannada", "english", "both"
    @AppStorage("watch_font_size") private var fontSize: Double = 16.0
    
    private var maxStanzaCount: Int {
        max(hymn.stanzasKannada.count, hymn.stanzasEnglish.count, 1)
    }
    
    public init(hymn: Hymn) {
        self.hymn = hymn
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                // Header card
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(hymnTypePrefix) \(hymn.number)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        if !hymn.signature.isEmpty && hymn.signature != "C.M" {
                            Text(hymn.signature)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.18))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(hymn.title)
                        .font(.system(size: fontSize + 1, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .padding(.bottom, 2)
                
                Divider()
                
                // Stanzas (Lazy evaluated for instant opening)
                ForEach(0..<maxStanzaCount, id: \.self) { idx in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Stanza \(idx + 1)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        // Kannada text
                        if (lyricsLanguage == "kannada" || lyricsLanguage == "both") && idx < hymn.stanzasKannada.count {
                            Text(hymn.stanzasKannada[idx])
                                .font(.system(size: fontSize, weight: .medium))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // English text
                        if (lyricsLanguage == "english" || lyricsLanguage == "both") && idx < hymn.stanzasEnglish.count {
                            Text(hymn.stanzasEnglish[idx])
                                .font(.system(size: fontSize - 1, weight: .regular))
                                .foregroundColor(lyricsLanguage == "both" ? .secondary : .primary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                }
                
                // Bottom Quick Action Buttons
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            favStore.toggleFavorite(hymn)
                        } label: {
                            Label(
                                favStore.isFavorite(hymn) ? "Favorited" : "Favorite",
                                systemImage: favStore.isFavorite(hymn) ? "heart.fill" : "heart"
                            )
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(favStore.isFavorite(hymn) ? .red : .primary)
                        }
                        
                        Button {
                            setlistStore.toggle(hymn: hymn)
                        } label: {
                            Label(
                                setlistStore.isInSetlist(type: hymn.type, number: hymn.number) ? "In Setlist" : "Setlist",
                                systemImage: setlistStore.isInSetlist(type: hymn.type, number: hymn.number) ? "star.fill" : "star"
                            )
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(setlistStore.isInSetlist(type: hymn.type, number: hymn.number) ? .yellow : .primary)
                        }
                    }
                    
                    // Language Switch
                    HStack(spacing: 4) {
                        Button {
                            lyricsLanguage = "kannada"
                        } label: {
                            Text("ಕನ್ನಡ")
                                .font(.system(size: 11, weight: lyricsLanguage == "kannada" ? .bold : .regular))
                                .frame(maxWidth: .infinity)
                        }
                        .tint(lyricsLanguage == "kannada" ? .accentColor : .gray.opacity(0.3))
                        
                        Button {
                            lyricsLanguage = "english"
                        } label: {
                            Text("Eng")
                                .font(.system(size: 11, weight: lyricsLanguage == "english" ? .bold : .regular))
                                .frame(maxWidth: .infinity)
                        }
                        .tint(lyricsLanguage == "english" ? .accentColor : .gray.opacity(0.3))
                        
                        Button {
                            lyricsLanguage = "both"
                        } label: {
                            Text("Both")
                                .font(.system(size: 11, weight: lyricsLanguage == "both" ? .bold : .regular))
                                .frame(maxWidth: .infinity)
                        }
                        .tint(lyricsLanguage == "both" ? .accentColor : .gray.opacity(0.3))
                    }
                    
                    // Text Size Adjuster
                    HStack {
                        Button {
                            if fontSize > 12 { fontSize -= 1 }
                        } label: {
                            Image(systemName: "textformat.size.smaller")
                        }
                        
                        Text("\(Int(fontSize))pt")
                            .font(.system(size: 12, weight: .bold))
                            .frame(minWidth: 36)
                        
                        Button {
                            if fontSize < 24 { fontSize += 1 }
                        } label: {
                            Image(systemName: "textformat.size.larger")
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .navigationTitle("\(hymnTypePrefix) \(hymn.number)")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var hymnTypePrefix: String {
        switch hymn.type {
        case "keerthane": return "Keerthane"
        case "mt": return "M.T."
        default: return "Hymn"
        }
    }
}
