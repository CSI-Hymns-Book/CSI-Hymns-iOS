import SwiftUI

/// Sunday Service Setlist view on Apple Watch, showing the sequence of songs for today's service.
public struct WatchSetlistView: View {
    @StateObject private var setlistStore = WatchSetlistStore.shared
    @StateObject private var dataLoader = WatchDataLoader.shared
    
    public var body: some View {
        List {
            if setlistStore.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "star")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    Text("No Songs in Setlist")
                        .font(.headline)
                    
                    Text("Pin songs from the Hymn reader or sync your Sunday service from your iPhone.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            } else {
                Section(header: Text("Today's Service")) {
                    ForEach(setlistStore.items) { item in
                        if let song = dataLoader.song(type: item.type, number: item.number) {
                            NavigationLink(destination: WatchHymnReaderView(hymn: song)) {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if let label = item.label {
                                            Text(label.uppercased())
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.accentColor)
                                        }
                                        
                                        HStack {
                                            Text("\(prefix(for: item.type)) \(item.number)")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(.primary)
                                            
                                            Text(item.title)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            let item = setlistStore.items[idx]
                            setlistStore.remove(type: item.type, number: item.number)
                        }
                    }
                }
                
                Button(role: .destructive) {
                    setlistStore.clear()
                } label: {
                    Label("Clear Setlist", systemImage: "trash")
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Sunday Setlist")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func prefix(for type: String) -> String {
        switch type {
        case "keerthane": return "Keer"
        case "mt": return "M.T."
        default: return "Hymn"
        }
    }
}
