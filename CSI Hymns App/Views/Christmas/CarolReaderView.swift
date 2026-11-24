import SwiftUI

/// The carol reader: swipe or use the side arrows to move between a church's songs; star a song,
/// change the text size with a slider, edit it (if you may) and start Present mode. The screen
/// stays awake while a carol is open.
struct CarolReaderView: View {
    let songs: [CarolSong]
    let churchName: String
    @State private var selection: UUID
    @State private var languages: [UUID: String] = [:]
    @State private var presenting = false
    @State private var store = CarolReaderStore.shared

    init(songs: [CarolSong], startId: UUID, churchName: String) {
        self.songs = songs
        self.churchName = churchName
        _selection = State(initialValue: songs.contains { $0.id == startId } ? startId : (songs.first?.id ?? startId))
    }

    var body: some View {
        FestivePaletteProvider {
            ReaderBody(songs: songs, churchName: churchName, selection: $selection, languages: $languages, presenting: $presenting, store: store)
        }
    }
}

private struct ReaderBody: View {
    let songs: [CarolSong]
    let churchName: String
    @Binding var selection: UUID
    @Binding var languages: [UUID: String]
    @Binding var presenting: Bool
    let store: CarolReaderStore
    @State private var service = ChristmasCarolsService.shared
    @State private var showTextSize = false
    @State private var editing: CarolSong?
    @Environment(\.festivePalette) private var palette

    /// The songs as they are now, so an edit shows straight away. A song that has gone is dropped.
    private var liveSongs: [CarolSong] {
        songs.compactMap { original in service.songs.first { $0.id == original.id } ?? (service.songs.isEmpty ? original : nil) }
    }
    private var current: CarolSong? { liveSongs.first { $0.id == selection } ?? liveSongs.first }
    private var index: Int { liveSongs.firstIndex { $0.id == selection } ?? 0 }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(liveSongs) { song in
                CarolLyricsPage(song: song, churchName: churchName, scale: store.textScale,
                                language: Binding(get: { languages[song.id] ?? "Kannada" }, set: { languages[song.id] = $0 }))
                    .tag(song.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .festiveReaderFrame()
        .festiveDimSnow()
        .overlay { sideArrows }
        .overlay(alignment: .bottom) {
            HStack(alignment: .center) {
                if liveSongs.count > 1 {
                    Text("\(index + 1) of \(liveSongs.count)").font(.system(size: 12, weight: .medium)).foregroundStyle(palette.inkMuted)
                }
                Spacer()
                ReturnToCallerChip()
            }
            .padding(.horizontal, 20).padding(.bottom, 10)
        }
        .navigationTitle(current?.title ?? "Carol")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { toolbarItems }
        .sheet(item: $editing) { song in
            if let church = service.church(byId: song.churchId) { AddCarolSongFormView(church: church, editing: song) }
        }
        .onChange(of: selection, initial: true) { _, id in store.markViewed(id.uuidString) }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .fullScreenCover(isPresented: $presenting) {
            if let song = current {
                CarolPresenterView(title: song.title, stanzas: splitStanzas(lyrics(of: song, language: languages[song.id] ?? "Kannada"))) { presenting = false }
            }
        }
    }

    // MARK: Previous / next

    private var sideArrows: some View {
        HStack {
            arrow("chevron.left", label: "Previous song", enabled: index > 0) { move(-1) }
            Spacer()
            arrow("chevron.right", label: "Next song", enabled: index < liveSongs.count - 1) { move(1) }
        }
        .padding(.horizontal, 8)
    }

    private func arrow(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold)).foregroundStyle(palette.ink)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(palette.edge, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.28)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func move(_ step: Int) {
        let target = index + step
        guard liveSongs.indices.contains(target) else { return }
        AppHaptics.light()
        withAnimation(.easeInOut(duration: 0.3)) { selection = liveSongs[target].id }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let song = current {
                Button { store.toggleFavourite(song.id.uuidString) } label: {
                    Image(systemName: store.favourites.contains(song.id.uuidString) ? "star.fill" : "star")
                }
                .accessibilityLabel(store.favourites.contains(song.id.uuidString) ? "Remove from favourites" : "Add to favourites")
                Button { showTextSize = true } label: { Image(systemName: "textformat.size") }
                    .accessibilityLabel("Text size")
                    .popover(isPresented: $showTextSize) {
                        CarolTextSizeControl(store: store).presentationCompactAdaptation(.popover)
                    }
                Menu {
                    Button { presenting = true } label: { Label("Present verse by verse", systemImage: "rectangle.on.rectangle") }
                    if service.canEditSong(song) {
                        Button { editing = song } label: { Label("Edit song", systemImage: "pencil") }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("More options")
            }
        }
    }

    private func lyrics(of song: CarolSong, language: String) -> String {
        let parts = CarolBilingual.split(song.lyrics)
        return language == "English" ? (parts.english ?? parts.kannada) : parts.kannada
    }
}

/// Full-screen "present" mode for carol rounds: one verse at a time in large type on a dark screen.
/// Swipe, or tap the right half for the next verse and the left half to go back.
struct CarolPresenterView: View {
    let title: String
    let stanzas: [String]
    let onClose: () -> Void
    @State private var page = 0
    @State private var width: CGFloat = 0

    var body: some View {
        let pages = stanzas.isEmpty ? [title] : stanzas
        ZStack {
            Color(hex: "05060F").ignoresSafeArea()
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    ScrollView {
                        Text(pages[i]).font(.system(size: 30)).lineSpacing(10).foregroundStyle(Color(hex: "F5EFE4"))
                            .multilineTextAlignment(.center).padding(.horizontal, 28).padding(.vertical, 90)
                            .frame(maxWidth: .infinity, minHeight: 400)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Taps are read on the pager itself. A full-screen tap layer on top would take the
            // touches first and block swiping between verses.
            .simultaneousGesture(SpatialTapGesture().onEnded { tap in
                let step = PresenterTap.at(x: tap.location.x, width: width) == .previous ? -1 : 1
                withAnimation { page = PresenterPaging.moved(page, by: step, count: pages.count) }
            })
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            VStack {
                HStack {
                    Text("\(title)  ·  \(page + 1) of \(pages.count)").font(.system(size: 13)).foregroundStyle(Color(hex: "E9C27B"))
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark.circle.fill").font(.system(size: 26)).foregroundStyle(Color(hex: "F5EFE4")) }
                        .accessibilityLabel("Stop presenting")
                }
                .padding(.horizontal, 16).padding(.top, 8)
                Spacer()
            }
        }
        .onChange(of: pages.count) { _, count in page = PresenterPaging.clamped(page, count: count) }
        .accessibilityAction(named: "Next verse") { withAnimation { page = PresenterPaging.moved(page, by: 1, count: pages.count) } }
        .accessibilityAction(named: "Previous verse") { withAnimation { page = PresenterPaging.moved(page, by: -1, count: pages.count) } }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
