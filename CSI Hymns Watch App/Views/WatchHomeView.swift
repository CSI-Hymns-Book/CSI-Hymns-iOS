import SwiftUI

/// Main dashboard for CSI Hymns Book on Apple Watch.
public struct WatchHomeView: View {
    @StateObject private var dataLoader = WatchDataLoader.shared
    @StateObject private var setlistStore = WatchSetlistStore.shared
    @StateObject private var favStore = WatchFavoritesStore.shared
    
    public var body: some View {
        NavigationStack {
            List {
                // Sunday Service Setlist (Hero Card)
                NavigationLink(destination: WatchSetlistView()) {
                    HStack(spacing: 10) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sunday Setlist")
                                .font(.system(size: 13, weight: .bold))
                            
                            if setlistStore.items.isEmpty {
                                Text("No songs pinned")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(setlistStore.items.count) songs ready")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    .padding(.vertical, 3)
                }
                .listRowBackground(
                    setlistStore.items.isEmpty
                    ? Color.white.opacity(0.06)
                    : Color.yellow.opacity(0.16)
                )
                
                // Quick Number Dial
                NavigationLink(destination: WatchNumberDialView()) {
                    HStack(spacing: 10) {
                        Image(systemName: "number.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Dial")
                                .font(.system(size: 13, weight: .bold))
                            Text("Crown rotary picker")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
                
                // CSI Hymns
                NavigationLink(destination: WatchHymnListView(title: "CSI Hymns", type: "hymn")) {
                    HStack(spacing: 10) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CSI Hymns")
                                .font(.system(size: 13, weight: .bold))
                            Text("ಕನ್ನಡ ಸಂಗೀತಗಳು (\(dataLoader.hymns.count))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
                
                // CSI Keerthanes
                NavigationLink(destination: WatchHymnListView(title: "Keerthanes", type: "keerthane")) {
                    HStack(spacing: 10) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 16))
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keerthanes")
                                .font(.system(size: 13, weight: .bold))
                            Text("ಕನ್ನಡ ಸಂಕೀರ್ತನೆಗಳು (\(dataLoader.keerthanes.count))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
                
                // M.T. Hymns
                NavigationLink(destination: WatchHymnListView(title: "M.T. Hymns", type: "mt")) {
                    HStack(spacing: 10) {
                        Image(systemName: "music.quarternote.3")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("M.T. Hymns")
                                .font(.system(size: 13, weight: .bold))
                            Text("ಮಂಗಳೂರು ಸಂಗೀತಗಳು (\(dataLoader.mtHymns.count))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
                
                // Order of Service
                NavigationLink(destination: WatchOrderOfServiceView()) {
                    HStack(spacing: 10) {
                        Image(systemName: "iphone.and.arrow.forward")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Order of Service")
                                .font(.system(size: 13, weight: .bold))
                            Text("Open on iPhone · ಆರಾಧನಾ ಕ್ರಮ")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
                
                // Favorites
                NavigationLink(destination: WatchFavoritesView()) {
                    HStack(spacing: 10) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Favorites")
                                .font(.system(size: 13, weight: .bold))
                            Text("\(favStore.favoriteKeys.count) saved")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            .navigationTitle("CSI Hymns")
        }
    }
}
