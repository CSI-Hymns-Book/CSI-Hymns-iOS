import SwiftUI

/// The Christmas home: a Bethlehem night scene (always a dark sky, even in light mode) with the
/// title and verse, then the collection cards. Built to fit the screen without scrolling; it
/// only scrolls as a fallback when a very small screen cannot fit everything.
public struct ChristmasLandingView: View {
    @Binding var selectedTab: Int

    public init(selectedTab: Binding<Int>) { self._selectedTab = selectedTab }

    public var body: some View {
        NavigationStack {
            FestivePaletteProvider { FestiveHome(selectedTab: $selectedTab) }
        }
    }
}

private let festiveVerses: [(text: String, reference: String)] = [
    ("For unto us a child is born, unto us a son is given.", "Isaiah 9:6"),
    ("For unto you is born this day in the city of David a Saviour.", "Luke 2:11"),
    ("Glory to God in the highest, and on earth peace, good will toward men.", "Luke 2:14"),
    ("When they saw the star, they rejoiced with exceeding great joy.", "Matthew 2:10"),
    ("The people that walked in darkness have seen a great light.", "Isaiah 9:2"),
    ("And the Word was made flesh, and dwelt among us.", "John 1:14")
]

@MainActor
private enum FestiveHomeSession {
    static var entrancePlayed = false
    /// Last measured heights, so coming back home lays out at the right size on the first frame
    /// instead of guessing and then jumping (the glitch on the way back from a book).
    static var collectionsHeight: CGFloat = 330
    static var sideColumnHeight: CGFloat = 360
}

private struct FestiveHome: View {
    @Binding var selectedTab: Int
    @Environment(\.festivePalette) private var palette
    private let ambience = FestiveAmbience.shared

    @State private var heroModel = FestiveHeroModel(moment: FestiveCalendar.moment(for: Date()))
    @State private var collectionsHeight = FestiveHomeSession.collectionsHeight
    @State private var sideColumnHeight = FestiveHomeSession.sideColumnHeight
    @State private var showSecrets = false
    @State private var starCounter = StarTapCounter()
    @State private var gloria = false
    @State private var verseIndex = 0
    @State private var lightsSweep: Double = -1
    @State private var heroWidth: CGFloat = 390
    /// Cards pop in once per app launch; coming back from a book or rotating must not replay it.
    @State private var entrancesDone = FestiveHomeSession.entrancePlayed

    private static let minHero: CGFloat = 330, maxHero: CGFloat = 520
    /// Design-unit y of the tallest rooftops: hero text stays above it.
    private static let skylineDesignY = 254.0

    var body: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let full = CGSize(width: geo.size.width + insets.leading + insets.trailing,
                              height: geo.size.height + insets.top + insets.bottom)
            let landscape = full.width > full.height
            ZStack {
                LinearGradient(colors: [palette.ground, palette.groundDeep], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                if landscape {
                    landscapeLayout(full: full, insets: insets)
                } else {
                    portraitLayout(full: full, insets: insets)
                }
            }
            .onChange(of: full.width, initial: true) { _, w in heroWidth = landscape ? (w * 0.5).rounded() : w }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar) // keeps the status bar white on the dark sky
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape").foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showSecrets) { FestiveSecretsSheet() }
        .onAppear { ambience.sim.darkSkyBehind = !palette.isNight; startMoments() }
        .onDisappear { ambience.sim.darkSkyBehind = false }
        .task {
            guard !entrancesDone else { return }
            try? await Task.sleep(for: .seconds(1.4))
            entrancesDone = true
            FestiveHomeSession.entrancePlayed = true
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6.5))
                if !gloria { withAnimation(.easeInOut(duration: 0.6)) { verseIndex = (verseIndex + 1) % festiveVerses.count } }
            }
        }
    }

    // MARK: Layouts

    /// Portrait: the scene grows or shrinks so scene + collections + secrets chip exactly fill the
    /// screen. Nothing scrolls unless the screen is genuinely too short to fit it all.
    @ViewBuilder
    private func portraitLayout(full: CGSize, insets: EdgeInsets) -> some View {
        let chipBlock: CGFloat = (ambience.eggsActive ? 50 : 10) + max(insets.bottom, 10)
        let ideal = full.height - collectionsHeight - chipBlock
        let heroHeight = min(max(ideal, Self.minHero), Self.maxHero)
        let overflows = ideal < Self.minHero - 0.5
        let content = VStack(spacing: 0) {
            hero(size: CGSize(width: full.width, height: heroHeight), textTop: insets.top + 4, statusTop: statusBarHeight,
                 leading: 0, chipRowCenter: (statusBarHeight + insets.top) / 2)
            collections(compact: false)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
                .frame(maxWidth: 620)
                .padding(.top, 10)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { collectionsHeight = $0; FestiveHomeSession.collectionsHeight = $0 }
            Spacer(minLength: 8)
            secretsChip
                .padding(.bottom, max(insets.bottom, 10) + 2)
        }
        // Exactly one screen tall (taller only when it must scroll), anchored at the top.
        .frame(width: full.width, height: overflows ? nil : full.height, alignment: .top)

        Group {
            if overflows {
                ScrollView { content }.scrollIndicators(.hidden)
            } else {
                content
            }
        }
        .frame(width: full.width, height: full.height, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }

    /// Landscape: the scene on the left half, the collections on the right, both full height.
    @ViewBuilder
    private func landscapeLayout(full: CGSize, insets: EdgeInsets) -> some View {
        let heroW = (full.width * 0.5).rounded()
        // The navigation bar only holds the settings button on the left, over the scene, so the
        // right column can start near the top edge.
        let columnTop: CGFloat = 14
        let available = full.height - columnTop - max(insets.bottom, 10)
        let column = VStack(spacing: 10) {
            collections(compact: true)
            secretsChip
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, 18)
        .padding(.trailing, max(insets.trailing, 14) + 4)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sideColumnHeight = $0; FestiveHomeSession.sideColumnHeight = $0 }

        HStack(spacing: 0) {
            hero(size: CGSize(width: heroW, height: full.height), textTop: insets.top + 6, statusTop: 0,
                 leading: insets.leading, chipRowCenter: nil)
            Group {
                if sideColumnHeight > available + 0.5 {
                    ScrollView { column.padding(.vertical, 4) }.scrollIndicators(.hidden)
                } else {
                    column.frame(maxHeight: .infinity)
                }
            }
            .padding(.top, columnTop)
            .padding(.bottom, max(insets.bottom, 10))
            .frame(maxWidth: .infinity)
        }
        .frame(width: full.width, height: full.height, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var secretsChip: some View {
        if ambience.eggsActive {
            FestiveSecretsChip(found: ambience.foundSecrets) { showSecrets = true }
                .transition(.opacity)
        }
    }

    /// The status bar (not the navigation bar) height, which the bell string hangs through.
    private var statusBarHeight: CGFloat {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.statusBarManager?.statusBarFrame.height ?? 0
    }

    // MARK: Hero

    /// `chipRowCenter`: when set, the countdown chip sits beside the settings button (in the
    /// navigation-bar row) instead of above the title, which gives the title more room.
    private func hero(size: CGSize, textTop: CGFloat, statusTop: CGFloat, leading: CGFloat, chipRowCenter: CGFloat?) -> some View {
        let skyline = FestiveHeroRenderer.canvasY(designY: Self.skylineDesignY, size: size)
        let available = max(120, skyline - textTop - 10)
        return ZStack(alignment: .topLeading) {
            FestiveHeroScene(
                model: heroModel,
                animate: ambience.level != .off,
                onStarTap: starTapped,
                onSnowTap: snowTapped
            )
            FestiveGarland(bellFraction: 0.93, bellDrop: statusTop, animate: ambience.level != .off) { at in ringBell(at: at) }
            if let center = chipRowCenter {
                countdownChip
                    .frame(height: 32)
                    .padding(.leading, 74 + leading)
                    .padding(.top, center - 16)
            }
            heroText(available: available, includeChip: chipRowCenter == nil)
                .padding(.leading, 20 + leading).padding(.trailing, 66)
                .padding(.top, textTop)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func heroText(available: CGFloat, includeChip: Bool) -> some View {
        // Fixed parts (greeting, verse, gaps, and the chip when it is here) take this much;
        // the two-line title gets the rest.
        let fixed: CGFloat = includeChip ? 128 : 86
        let titleSize = min(60, max(34, (available - fixed) / 2.1))
        return VStack(alignment: .leading, spacing: 8) {
            if includeChip { countdownChip }
            titleBlock(size: titleSize)
        }
        .frame(maxHeight: available, alignment: .topLeading)
    }

    private var countdownChip: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(hex: "D6493D")).frame(width: 8, height: 8)
            Text(FestiveCalendar.chipLabel(Date())).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(FestivePalette.night.ink)
        }
        .padding(.horizontal, 13).padding(.vertical, 7)
        .background(Capsule().fill(FestivePalette.night.glassHigh))
        .overlay(Capsule().strokeBorder(FestivePalette.night.edge, lineWidth: 1))
        .festiveEntrance(0, enabled: !entrancesDone)
    }

    private func titleBlock(size: CGFloat) -> some View {
        let night = FestivePalette.night
        return VStack(alignment: .leading, spacing: 6) {
            Text("ಕ್ರಿಸ್ಮಸ್ ಹಬ್ಬದ ಶುಭಾಶಯಗಳು")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(night.gold)
                .lineLimit(1).minimumScaleFactor(0.8)
                .festiveEntrance(1, enabled: !entrancesDone)
            VStack(alignment: .leading, spacing: -size * 0.14) {
                Text("Merry").font(.festiveSerif(size, weight: .regular))
                Text("Christmas").font(.festiveSerif(size, weight: .regular)).italic()
            }
            .lineLimit(1)
            .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
            .foregroundStyle(
                LinearGradient(colors: [night.ink, night.gold, night.ink], startPoint: UnitPoint(x: lightsSweep - 0.4, y: 0.5), endPoint: UnitPoint(x: lightsSweep, y: 0.5))
            )
            .minimumScaleFactor(0.6)
            .onLongPressGesture(minimumDuration: 0.6) { lightTitle() }
            .festiveEntrance(2, enabled: !entrancesDone)

            Group {
                if gloria {
                    Text("Gloria in excelsis Deo").font(.festiveSerif(17, weight: .regular)).italic().foregroundStyle(night.gold)
                } else {
                    let verse = festiveVerses[verseIndex]
                    (Text(verse.text + "  ").foregroundStyle(night.inkMuted) + Text(verse.reference).bold().foregroundStyle(night.gold))
                        .font(.system(size: 14.5))
                        .id(verseIndex)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 6)), removal: .opacity))
                }
            }
            .lineLimit(2).frame(minHeight: 40, alignment: .topLeading)
            .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
            .festiveEntrance(3, enabled: !entrancesDone)
        }
    }

    // MARK: Collections

    private func collections(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            HStack {
                Text("COLLECTIONS").font(.system(size: 11.5, weight: .bold)).tracking(1.6).foregroundStyle(palette.inkMuted)
                Spacer()
                Text(FestiveCalendar.adventLabel(Date())).font(.system(size: 12, weight: .semibold)).foregroundStyle(palette.gold)
            }
            .padding(.horizontal, 4).padding(.top, compact ? 8 : 4)
            .festiveEntrance(4, enabled: !entrancesDone)

            HStack(spacing: 12) {
                BigCollectionCard(title: "Hymns", subtitle: "CSI hymn book", footer: "Kannada Sangeetha",
                                  tint: palette.pineBackground, index: 5, minHeight: compact ? 112 : 128, entrance: !entrancesDone) {
                    open(.csi, tab: 0)
                } icon: { FestiveHymnBookIcon(tint: palette.pine, leaf: palette.hollyLeaf, size: 31, animate: ambience.level != .off) }
                BigCollectionCard(title: "Keerthane", subtitle: "ಕೀರ್ತನೆಗಳು", footer: "Kannada Sankeerthane",
                                  tint: palette.iceBackground, index: 6, minHeight: compact ? 112 : 128, entrance: !entrancesDone) {
                    open(.csi, tab: 1)
                } icon: { FestiveStarLanternIcon(tint: palette.ice, size: 34, animate: ambience.level != .off) }
            }

            NavigationLink(destination: ChristmasCarolsListView()) { carolsCard }
                .buttonStyle(FestivePressStyle())
                .festiveEntrance(7, enabled: !entrancesDone)

            Button { open(.mt, tab: 0) } label: { mtRow }
                .buttonStyle(FestivePressStyle())
                .festiveEntrance(8, enabled: !entrancesDone)
        }
    }

    private var carolsCard: some View {
        HStack(spacing: 13) {
            FestiveTreeIcon(leaf: palette.hollyLeaf, size: 32, animate: ambience.level != .off)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(palette.holly.opacity(0.18)))
            VStack(alignment: .leading, spacing: 1) {
                Text("THIS SEASON").font(.system(size: 10.5, weight: .bold)).tracking(1.4).foregroundStyle(palette.gold)
                Text("Community Carols").font(.festiveSerif(20)).foregroundStyle(palette.ink).lineLimit(1)
                Text("Lyrics and sheet music from churches").font(.system(size: 12.5)).foregroundStyle(palette.inkMuted).lineLimit(1)
            }
            Spacer(minLength: 4)
            FestiveBobbingStave(tint: palette.gold, animate: ambience.level != .off).frame(width: 52, height: 34)
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [palette.featureStart, palette.featureEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .festiveGlass(cornerRadius: 22)
        .accessibilityLabel("Community Carols")
    }

    private var mtRow: some View {
        HStack(spacing: 12) {
            FestivePianoBowIcon(tint: palette.ember, size: 24)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.emberBackground))
            VStack(alignment: .leading, spacing: 1) {
                Text("M.T. Hymns").font(.system(size: 14.5, weight: .bold)).foregroundStyle(palette.ink)
                Text("Mangalore tunes").font(.system(size: 12)).foregroundStyle(palette.inkMuted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(palette.ink)
        }
        .padding(.leading, 10).padding(.trailing, 14).padding(.vertical, 9)
        .festiveGlass(cornerRadius: 18)
        .accessibilityLabel("M.T. Hymns")
    }

    /// Opens a book. The tab is chosen first WITHOUT animation (otherwise the tab bar slides
    /// while the screen zooms), then the book zooms in over the home in one smooth spring.
    private func open(_ section: BookSection, tab: Int) {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { selectedTab = tab }
        withAnimation(FestiveMotion.screen) {
            AppNavigationService.shared.activeSection = section
        }
    }

    // MARK: Easter eggs

    private func starTapped(_ at: CGPoint) {
        guard ambience.eggsActive else { return }
        heroModel.starTappedAt = heroModel.clock
        ambience.sim.effects.sparkle(x: at.x, y: at.y, count: 6)
        switch starCounter.tap(now: heroModel.clock) {
        case .hint: ambience.showToast("The star is getting brighter…")
        case .shootingStar:
            heroModel.shootingStarAt = heroModel.clock
            gloria = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            ambience.discover(.star)
            Task { try? await Task.sleep(for: .seconds(4.2)); gloria = false }
        case .tap: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func snowTapped() {
        guard ambience.eggsActive, !heroModel.isSnowmanDone else { return }
        heroModel.snowmanPieceStartedAt.append(heroModel.clock)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if heroModel.isSnowmanDone { ambience.discover(.snowman) }
    }

    private func ringBell(at: CGPoint) {
        FestiveHaptics.shared.play(HapticPattern(timings: [0, 25, 70, 25, 70, 60], amplitudes: [0, 180, 0, 180, 0, 255]))
        guard ambience.eggsActive else { return }
        ambience.sim.effects.rings(x: at.x, y: at.y)
        ambience.discover(.bell)
    }

    private func lightTitle() {
        guard ambience.eggsActive else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        lightsSweep = -0.4
        withAnimation(.easeInOut(duration: 1.7)) { lightsSweep = 1.6 }
        ambience.discover(.lights)
        gloria = true
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            lightsSweep = -1; gloria = false
        }
    }

    /// Christmas Day: confetti and a ringing bell as the home opens.
    private func startMoments() {
        guard heroModel.moment == .christmasDay else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            ambience.celebrateChristmasDay(width: heroWidth)
            ringBell(at: CGPoint(x: heroWidth - 44, y: 160))
        }
    }
}

// MARK: - Cards

private struct BigCollectionCard<Icon: View>: View {
    let title: String, subtitle: String, footer: String
    let tint: Color
    let index: Int
    var minHeight: CGFloat = 128
    var entrance = true
    let action: () -> Void
    @ViewBuilder var icon: () -> Icon
    @Environment(\.festivePalette) private var palette

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                icon()
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(tint))
                Spacer(minLength: 6)
                Text(title).font(.festiveSerif(22)).foregroundStyle(palette.ink)
                Text(subtitle).font(.system(size: 12.5)).foregroundStyle(palette.inkMuted).padding(.top, 4)
                Spacer().frame(height: 8)
                HStack {
                    // Shrinks on narrow phones so both big cards keep the same height.
                    Text(footer).font(.system(size: 12, weight: .semibold)).foregroundStyle(palette.gold)
                        .lineLimit(1).minimumScaleFactor(0.65)
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).foregroundStyle(palette.gold)
                }
            }
            .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 11)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [tint, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.75)))
            )
            .festiveGlass(cornerRadius: 24)
        }
        .buttonStyle(FestivePressStyle())
        .festiveEntrance(index, enabled: entrance)
        .accessibilityLabel(title)
    }
}
