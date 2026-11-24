import SwiftUI
import Observation

@Observable
public final class ChristmasCarolsListViewModel {
    public var searchQuery = ""
    public var isShowingCreateChurch = false

    public init() {}

    public func filteredChurches(_ churches: [CarolChurch], service: ChristmasCarolsService) -> [CarolChurch] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return churches }
        return churches.filter { church in
            if church.name.lowercased().contains(query) { return true }
            return service.songs(for: church.id).contains { $0.title.lowercased().contains(query) }
                || service.pdfs(for: church.id).contains { $0.title.lowercased().contains(query) }
        }
    }
}

/// Church-first community carols browser, in the Christmas look. `onClose` is set when this is
/// opened from a partner app (YKC One), where it is the root of its own stack.
public struct ChristmasCarolsListView: View {
    var onClose: (() -> Void)?

    @State private var service = ChristmasCarolsService.shared
    @State private var viewModel = ChristmasCarolsListViewModel()
    @State private var isShowingSignInPrompt = false
    @State private var toastMessage: String?
    @State private var toastIsError = false
    private let store = CarolReaderStore.shared

    public init(onClose: (() -> Void)? = nil) { self.onClose = onClose }

    private var filteredChurches: [CarolChurch] {
        let list = viewModel.filteredChurches(service.churches, service: service)
        // The default church comes first, then A to Z.
        return list.sorted { a, b in
            let aDefault = a.id.uuidString == store.defaultChurchId, bDefault = b.id.uuidString == store.defaultChurchId
            if aDefault != bDefault { return aDefault }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    public var body: some View {
        FestivePaletteProvider { content }
    }

    private var content: some View {
        FestiveCarolsScreen(viewModel: viewModel, service: service, store: store, churches: filteredChurches,
                            isShowingSignInPrompt: $isShowingSignInPrompt, onSync: { await syncCarols() })
            .navigationTitle("Community Carols")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: onClose) { Image(systemName: "xmark") }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await syncCarols() } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(service.isLoading)
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .sheet(isPresented: $viewModel.isShowingCreateChurch) { AddChurchFormView() }
            .festiveAlert("Sign In Required", isPresented: $isShowingSignInPrompt,
                          message: "Sign in to create a church or add songs/PDFs.", buttons: [.cancel("OK")])
            .appToast(message: $toastMessage, isError: toastIsError)
            .task { await syncCarols() }
            .onChange(of: service.lastErrorMessage) { _, msg in if let msg { toastMessage = msg; toastIsError = true } }
            .onChange(of: service.lastSuccessMessage) { _, msg in if let msg { toastMessage = msg; toastIsError = false } }
    }

    private func syncCarols() async {
        do {
            try await service.fetchParishCarols(forceGitHub: true)
            toastMessage = service.churches.isEmpty ? "No churches yet. Create one to get started." : "Synced \(service.churches.count) churches."
            toastIsError = false
        } catch {
            toastMessage = "Couldn't sync. Pull to retry."
            toastIsError = true
        }
    }
}

private struct FestiveCarolsScreen: View {
    @Bindable var viewModel: ChristmasCarolsListViewModel
    let service: ChristmasCarolsService
    let store: CarolReaderStore
    let churches: [CarolChurch]
    @Binding var isShowingSignInPrompt: Bool
    let onSync: () async -> Void
    @Environment(\.festivePalette) private var palette

    private var yourSongs: (favourites: [CarolSong], recents: [CarolSong]) {
        let favourites = service.songs.filter { store.favourites.contains($0.id.uuidString) }
        let recents = store.recents.compactMap { id in service.songs.first { $0.id.uuidString == id } }
        return (favourites, recents)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(colors: palette.screenGradient, startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack { ReturnToCallerChip(); Spacer() }.padding(.horizontal, 16).padding(.top, 4)
                searchBar.padding(.horizontal, 16).padding(.vertical, 10)
                if service.isLoading && service.churches.isEmpty {
                    FestiveShimmerRows()
                } else if churches.isEmpty {
                    emptyState
                } else {
                    churchList
                }
            }
            createButton
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(palette.gold)
            TextField("Search churches or carols…", text: $viewModel.searchQuery)
                .foregroundStyle(palette.ink).textInputAutocapitalization(.never)
            if !viewModel.searchQuery.isEmpty {
                Button { viewModel.searchQuery = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(palette.inkMuted) }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .festiveGlass(cornerRadius: 28, high: true)
    }

    private var churchList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.searchQuery.isEmpty { yourCarols }
                ForEach(churches) { church in churchRow(church) }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 100)
        }
        .refreshable { await onSync() }
    }

    private func churchRow(_ church: CarolChurch) -> some View {
        let isDefault = church.id.uuidString == store.defaultChurchId
        let songs = service.songs(for: church.id).count, pdfs = service.pdfs(for: church.id).count
        let counts = "\(songs) song\(songs == 1 ? "" : "s")" + (pdfs > 0 ? " · \(pdfs) PDF\(pdfs == 1 ? "" : "s")" : "")
        return ZStack(alignment: .trailing) {
            NavigationLink(destination: ChurchDetailView(church: church)) {
                FestiveSongRow(label: isDefault ? "Default · \(counts)" : counts, title: church.name,
                               subtitle: church.description, badgeBackground: .clear) {
                    FestiveChurchAvatar(name: church.name)
                } trailing: {
                    Color.clear.frame(width: 34, height: 1)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.gold.opacity(0.8))
                }
            }
            .buttonStyle(FestivePressStyle())
            Button { store.toggleDefaultChurch(church.id.uuidString) } label: {
                Image(systemName: isDefault ? "pin.fill" : "pin")
                    .font(.system(size: 15)).foregroundStyle(isDefault ? palette.gold : palette.inkMuted)
                    .frame(width: 40, height: 40).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 36)
            .accessibilityLabel(isDefault ? "Default church: \(church.name). Tap to clear" : "Set \(church.name) as the default church")
        }
    }

    /// Favourites first, then recently opened songs, as small tappable chips.
    @ViewBuilder
    private var yourCarols: some View {
        let mine = yourSongs
        if !mine.favourites.isEmpty || !mine.recents.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if !mine.favourites.isEmpty { strip("★  Favourites", songs: mine.favourites) }
                if !mine.recents.isEmpty { strip("Recently opened", songs: mine.recents) }
            }
            .padding(.bottom, 6)
        }
    }

    private func strip(_ heading: String, songs: [CarolSong]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(heading.uppercased()).font(.system(size: 10.5, weight: .bold)).tracking(1.2).foregroundStyle(palette.gold)
                .padding(.leading, 4).padding(.top, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(songs) { song in
                        let churchSongs = service.songs(for: song.churchId)
                        NavigationLink(destination: CarolReaderView(songs: churchSongs.isEmpty ? [song] : churchSongs, startId: song.id,
                                                                    churchName: service.churches.first { $0.id == song.churchId }?.name ?? "")) {
                            Text(song.title).font(.system(size: 13)).foregroundStyle(palette.ink).lineLimit(1)
                                .frame(width: 150, alignment: .leading)
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .festiveGlass(cornerRadius: 14, capped: false)
                        }
                        .buttonStyle(FestivePressStyle())
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("⛪").font(.system(size: 48))
            Text("No churches yet").font(.festiveSerif(22)).foregroundStyle(palette.ink)
            Text("Create a church first, then add songs or PDFs inside it. Pull down to sync.")
                .font(.subheadline).foregroundStyle(palette.inkMuted).multilineTextAlignment(.center).padding(.horizontal, 32)
            Button("Sync") { Task { await onSync() } }.buttonStyle(.bordered).tint(palette.gold)
        }
        .frame(maxHeight: .infinity)
    }

    private var createButton: some View {
        Button {
            if SupabaseService.instance.isAuthenticated { viewModel.isShowingCreateChurch = true } else { isShowingSignInPrompt = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text(SupabaseService.instance.isAuthenticated ? "New church" : "Sign in").font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(palette.isNight ? Color(hex: "2A1D05") : .white)
            .padding(.horizontal, 18).frame(height: 52)
            .background(Capsule().fill(palette.gold))
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .festiveFloatingCap()
        }
        .padding(.trailing, 20).padding(.bottom, 24)
    }
}

/// Round avatar with the church's initials on a colour picked from its name.
struct FestiveChurchAvatar: View {
    let name: String
    @Environment(\.festivePalette) private var palette
    var body: some View {
        let colors = [palette.pine, palette.ice, palette.ember, palette.holly, palette.gold]
        let color = colors[churchColorSlot(name, slotCount: colors.count)]
        Text(churchInitials(name))
            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(Circle().fill(LinearGradient(colors: [color.opacity(0.85), color.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)))
    }
}

/// Placeholder rows that shimmer gently while carols load for the first time.
struct FestiveShimmerRows: View {
    @Environment(\.festivePalette) private var palette
    var body: some View {
        TimelineView(.animation) { timeline in
            let sweep = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2 * 3 - 1
            VStack(spacing: 14) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(palette.glass)
                        .frame(height: 72)
                        .overlay(
                            LinearGradient(stops: [
                                .init(color: .clear, location: max(0, sweep - 0.2)), .init(color: palette.glassHigh, location: min(max(sweep, 0), 1)),
                                .init(color: .clear, location: min(1, sweep + 0.2))
                            ], startPoint: .leading, endPoint: .trailing)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        )
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 8)
        }
    }
}
