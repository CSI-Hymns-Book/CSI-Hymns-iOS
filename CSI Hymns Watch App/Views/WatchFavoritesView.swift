import SwiftUI

/// Favorites list view on Apple Watch.
public struct WatchFavoritesView: View {
    @StateObject private var favStore = WatchFavoritesStore.shared
    @StateObject private var dataLoader = WatchDataLoader.shared
    
    private var favoriteSongs: [Hymn] {
        var result: [Hymn] = []
        for song in dataLoader.hymns where favStore.isFavorite(song) {
            result.append(song)
        }
        for song in dataLoader.keerthanes where favStore.isFavorite(song) {
            result.append(song)
        }
        for song in dataLoader.mtHymns where favStore.isFavorite(song) {
            result.append(song)
        }
        return result
    }
    
    public var body: some View {
        List {
            if favoriteSongs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "heart")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text("No Favorites")
                        .font(.headline)
                    
                    Text("Heart songs in the reader to access them quickly here.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            } else {
                ForEach(favoriteSongs) { song in
                    NavigationLink(destination: WatchHymnReaderView(hymn: song)) {
                        HStack(spacing: 8) {
                            Text("\(song.number)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.accentColor)
                                .frame(width: 32, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                
                                Text(typeLabel(for: song))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func typeLabel(for hymn: Hymn) -> String {
        switch hymn.type {
        case "keerthane": return "CSI Keerthane"
        case "mt": return "M.T. Hymn"
        default: return "CSI Hymn"
        }
    }
}
