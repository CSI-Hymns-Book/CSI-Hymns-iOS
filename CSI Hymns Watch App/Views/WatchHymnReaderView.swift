import SwiftUI

/// Premium, high-legibility stanza reader designed specifically for Apple Watch display.
public struct WatchHymnReaderView: View {
    public let hymn: Hymn
    
    @StateObject private var favStore = WatchFavoritesStore.shared
    @StateObject private var setlistStore = WatchSetlistStore.shared
    @AppStorage("watch_lyrics_lang") private var lyricsLanguage: String = "kannada" // "kannada", "english", "both"
    @AppStorage("watch_font_size") private var fontSize: Double = 16.0
    @State private var crownAccumulator: CGFloat = 0.0
    @State private var showingOptions = false
    
    public init(hymn: Hymn) {
        self.hymn = hymn
    }
    
    private var stanzasKannada: [String] {
        splitStanzas(hymn.lyricsKannada)
    }
    
    private var stanzasEnglish: [String] {
        splitStanzas(hymn.lyricsEnglish)
    }
    
    private func splitStanzas(_ raw: String) -> [String] {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return [] }
        
        let parts = cleaned.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return parts.isEmpty ? [cleaned] : parts
    }
    
    private var maxStanzaCount: Int {
        max(stanzasKannada.count, stanzasEnglish.count, 1)
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
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
                .padding(.bottom, 4)
                
                Divider()
                
                // Stanzas
                ForEach(0..<maxStanzaCount, id: \.self) { idx in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Stanza \(idx + 1)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        // Kannada text
                        if (lyricsLanguage == "kannada" || lyricsLanguage == "both") && idx < stanzasKannada.count {
                            Text(stanzasKannada[idx])
                                .font(.system(size: fontSize, weight: .medium))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // English text
                        if (lyricsLanguage == "english" || lyricsLanguage == "both") && idx < stanzasEnglish.count {
                            Text(stanzasEnglish[idx])
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
