import SwiftUI

/// The carol reader: swipe between a church's songs; star a song, share its lyrics, change the
/// text size and start Present mode. The screen stays awake while a carol is open.
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

    private var current: CarolSong? { songs.first { $0.id == selection } ?? songs.first }

    var body: some View {
        FestivePaletteProvider { reader }
    }

    private var reader: some View {
        ReaderBody(songs: songs, churchName: churchName, selection: $selection, languages: $languages, presenting: $presenting, store: store)
    }
}

private struct ReaderBody: View {
    let songs: [CarolSong]
    let churchName: String
    @Binding var selection: UUID
    @Binding var languages: [UUID: String]
    @Binding var presenting: Bool
    let store: CarolReaderStore
    @Environment(\.festivePalette) private var palette

    private var current: CarolSong? { songs.first { $0.id == selection } ?? songs.first }
    private var index: Int { songs.firstIndex { $0.id == selection } ?? 0 }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(songs) { song in
                LyricsPage(song: song, churchName: churchName, scale: store.textScale,
                           language: Binding(get: { languages[song.id] ?? "Kannada" }, set: { languages[song.id] = $0 }))
                    .tag(song.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .festiveReaderFrame()
        .festiveDimSnow()
        .overlay(alignment: .bottom) {
            HStack(alignment: .center) {
                if songs.count > 1 {
                    Text("\(index + 1) of \(songs.count)  ·  swipe").font(.system(size: 12)).foregroundStyle(palette.inkMuted)
                }
                Spacer()
                ReturnToCallerChip()
            }
            .padding(.horizontal, 20).padding(.bottom, 10)
        }
        .navigationTitle(current?.title ?? "Carol")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            // Two items only: with more, iOS folds them into its own "•••" overflow, which did
            // nothing when tapped. Everything else lives in a real menu we control.
            if let song = current {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { AppHaptics.tap(); store.toggleFavourite(song.id.uuidString) } label: {
                        Image(systemName: store.favourites.contains(song.id.uuidString) ? "star.fill" : "star")
                    }
                    .accessibilityLabel(store.favourites.contains(song.id.uuidString) ? "Remove from favourites" : "Add to favourites")
                    Menu {
                        ShareLink(item: carolShareText(title: song.title, number: song.songNumber, churchName: churchName,
                                                       lyrics: lyrics(of: song, language: languages[song.id] ?? "Kannada"))) {
                            Label("Share lyrics", systemImage: "square.and.arrow.up")
                        }
                        Button { presenting = true } label: { Label("Present verse by verse", systemImage: "rectangle.on.rectangle") }
                        Divider()
                        Button { store.setTextScale(CarolTextScale.bigger(store.textScale)) } label: {
                            Label("Bigger text", systemImage: "textformat.size.larger")
                        }
                        .disabled(store.textScale >= CarolTextScale.max)
                        Button { store.setTextScale(CarolTextScale.smaller(store.textScale)) } label: {
                            Label("Smaller text", systemImage: "textformat.size.smaller")
                        }
                        .disabled(store.textScale <= CarolTextScale.min)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More options")
                }
            }
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

    private func lyrics(of song: CarolSong, language: String) -> String {
        let parts = CarolBilingual.split(song.lyrics)
        return language == "English" ? (parts.english ?? parts.kannada) : parts.kannada
    }
}

enum CarolBilingual {
    /// Splits lyrics that carry an English translation after a divider.
    static func split(_ lyrics: String) -> (kannada: String, english: String?) {
        for separator in ["\n\n---\n\nEnglish Translation:\n", "\n\n---\n\nEnglish:\n", "\n\n---\n\n"] {
            let parts = lyrics.components(separatedBy: separator)
            if parts.count > 1 { return (parts[0].trimmingCharacters(in: .whitespacesAndNewlines), parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
        return (lyrics, nil)
    }
}

private struct LyricsPage: View {
    let song: CarolSong
    let churchName: String
    let scale: Double
    @Binding var language: String
    @Environment(\.festivePalette) private var palette

    var body: some View {
        let parts = CarolBilingual.split(song.lyrics)
        let size = 17 * scale
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !churchName.isEmpty {
                    Text(churchName.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.3).foregroundStyle(palette.gold)
                }
                Text(song.title).font(.festiveSerif(26)).foregroundStyle(palette.ink).padding(.top, 2)
                Text([song.songNumber.map { "No. \($0)" }, song.scale.isEmpty ? nil : song.scale].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 13)).foregroundStyle(palette.inkMuted).padding(.top, 4)
                if parts.english != nil {
                    Picker("Language", selection: $language) {
                        Text("ಕನ್ನಡ").tag("Kannada"); Text("English").tag("English")
                    }
                    .pickerStyle(.segmented).frame(maxWidth: 220).padding(.top, 14)
                }
                Text(language == "English" ? (parts.english ?? parts.kannada) : parts.kannada)
                    .font(.system(size: size)).lineSpacing(size * 0.5).foregroundStyle(palette.ink)
                    .padding(.top, 18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 96)
        }
    }
}

/// Full-screen "present" mode for carol rounds: one verse at a time in large type on a dark screen.
/// Swipe, or tap the right half for the next verse and the left half to go back.
struct CarolPresenterView: View {
    let title: String
    let stanzas: [String]
    let onClose: () -> Void
    @State private var page = 0

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
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture { withAnimation { page = max(0, page - 1) } }
                Color.clear.contentShape(Rectangle()).onTapGesture { withAnimation { page = min(pages.count - 1, page + 1) } }
            }
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
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
