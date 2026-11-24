import SwiftUI

/// Fast, scrollable list of hymns/keerthanes on Apple Watch with live search.
public struct WatchHymnListView: View {
    public let title: String
    public let type: String // hymn, keerthane, mt
    
    @ObservedObject private var dataLoader = WatchDataLoader.shared
    @State private var searchText: String = ""
    
    public init(title: String, type: String) {
        self.title = title
        self.type = type
    }
    
    private var filteredSongs: [Hymn] {
        if searchText.isEmpty {
            return dataLoader.songs(for: type)
        }
        return dataLoader.search(query: searchText, in: type)
    }
    
    public var body: some View {
        List {
            if filteredSongs.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("No songs found")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredSongs) { song in
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
                                
                                if !song.firstLineKannada.isEmpty {
                                    Text(song.firstLineKannada)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search # or title")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
