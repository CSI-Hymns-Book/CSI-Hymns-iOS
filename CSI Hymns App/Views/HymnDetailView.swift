import SwiftUI
import Observation
import AVKit

#if canImport(AVFoundation)
import AVFoundation
#endif

/// View representing native AirPlay cast selection widgets.
public struct AirPlayRoutePicker: UIViewRepresentable {
    @State private var theme = ThemeManager.shared
    
    public init() {}
    public func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .systemBlue
        picker.tintColor = theme.activeTheme == .light ? .darkGray : .white
        return picker
    }
    
    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

/// Dynamic View-Model managing active detail actions.
@Observable
public final class HymnDetailViewModel {
    public var selectedLanguage: SongLanguage = .kannada
    public var fontSize: CGFloat = {
        let savedSize = UserDefaults.standard.double(forKey: "global_lyrics_font_size")
        return savedSize == 0 ? 18.0 : CGFloat(savedSize)
    }() {
        didSet {
            UserDefaults.standard.set(Double(fontSize), forKey: "global_lyrics_font_size")
        }
    }
    public var isShowingReportSheet = false
    public var reportDescription = ""
    public var isReportSubmitting = false
    
    public enum SongLanguage: String, CaseIterable, Identifiable {
        case english = "English"
        case kannada = "ಕನ್ನಡ"
        public var id: String { self.rawValue }
    }
    
    public init() {}
    
    public func submitReport(hymn: Hymn) async {
        guard !reportDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isReportSubmitting = true
        
        let result = await JiraService.shared.createTicket(
            songType: hymn.type.capitalized,
            songNumber: hymn.number,
            songTitle: hymn.title,
            description: reportDescription,
            appVersion: "1.0.0+1"
        )
        
        if result.success {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            PostHogService.shared.track(event: "jira_ticket_submitted", properties: [
                "song_number": hymn.number,
                "song_type": hymn.type
            ])
        }
        
        isReportSubmitting = false
        isShowingReportSheet = false
        reportDescription = ""
    }
}

/// A premium, immersive lyrics viewing and audio playing environment.
public struct HymnDetailView: View {
    let hymn: Hymn
    @State private var pageFlipVisibility = PageFlipVisibilityService.shared
    @AppStorage("use_page_swipe_physics") private var usePageSwipe = true
    /// Per-song only — never persisted across hymns.
    @State private var isHidden = false
    /// True after the user taps Hide/Show Actions on this hymn.
    @State private var userTouchedActionVisibility = false
    /// True when we auto-collapsed actions because audio started.
    @State private var autoHidActionsForAudio = false
    @State private var theme = ThemeManager.shared
    @State private var viewModel = HymnDetailViewModel()
    @State private var audio = AudioService.shared
    @State private var midiAudio = MidiPlaybackEngine.shared
    @State private var favoritesManager = FavoritesManager.shared
    @State private var isShowingSpeedMenu = false
    @State private var favoriteScale: CGFloat = 1.0
    @State private var isAudioPlayerVisible = false
    @State private var dragTime: Double? = nil
    
    // MT Tune variants
    @State private var tuneOptions: [String] = []
    @State private var selectedTune: String? = nil
    @State private var isShowingAdvancedMidi = false
    @State private var isViewReady = false
    @State private var scrollOffset: Double = 0
    @State private var pendingScrollRestore: Double? = nil
    @State private var showCastSheet = false
    @State private var castSongTitle: String = ""
    @State private var midiFilesList: [String] = []
    @State private var audioErrorMessage: String?
    @State private var forceOggPlayer = false
    @State private var showAudioContribution = false
    @Environment(\.scenePhase) private var scenePhase
    
    public init(hymn: Hymn) {
        self.hymn = hymn
    }
    
    public var body: some View {
        @Bindable var viewModel = viewModel
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                // Adaptive theme background
                theme.backgroundColor
                    .ignoresSafeArea()
                
                if theme.activeTheme != .amoled {
                    theme.backgroundGradient
                        .ignoresSafeArea()
                }
                
                if isLandscape {
                    HStack(spacing: 0) {
                        // Left Column: Lyrics (always maximum space)
                        VStack(spacing: 0) {
                            if usePageSwipe && pageFlipVisibility.isVisible {
                                pageFlipLyricsContainer
                            } else {
                                continuousLyricsContainer
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(isViewReady ? 1.0 : 0.0)
                        
                        if !isHidden || isAudioPlayerVisible {
                            // Split Divider
                            Rectangle()
                                .fill(theme.strokeColor)
                                .frame(width: 1)
                                .ignoresSafeArea(edges: .vertical)
                            
                            // Right Column: Controls and Audio Player
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 16) {
                                    if !isHidden {
                                        sidebarToolbarRow
                                        
                                        metadataHeaderCard(compact: false)
                                        
                                        sidebarSettingsPanel
                                    } else {
                                        metadataHeaderCard(compact: true)
                                    }
                                    
                                    if isAudioPlayerVisible {
                                        if usesMidiPlayback {
                                            glassmorphicMidiPlayer(isEmbedded: true)
                                        } else {
                                            glassmorphicAudioPlayer(isEmbedded: true)
                                        }
                                    }
                                }
                                .padding(16)
                            }
                            .frame(width: 320)
                            .background(
                                Rectangle()
                                    .fill(theme.surfaceColor.opacity(0.4))
                                    .ignoresSafeArea(edges: [.vertical, .trailing])
                            )
                            .offset(x: isViewReady ? 0 : 30)
                            .opacity(isViewReady ? 1.0 : 0.0)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isHidden)
                } else {
                    // Portrait Layout
                    VStack(spacing: 0) {
                        if !isHidden {
                            headerPanel
                                .padding(.horizontal)
                                .padding(.top, 10)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            
                            Divider()
                                .background(theme.strokeColor)
                                .padding(.vertical, 8)
                                .transition(.opacity)
                            
                            metadataHeaderCard(compact: false)
                                .padding(.bottom, 8)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            // Immersive mode: keep only hymn number + title for reference.
                            metadataHeaderCard(compact: true)
                                .padding(.top, 8)
                                .padding(.bottom, 6)
                                .transition(.opacity)
                        }
                        
                        // Lyrics: page-flip when enabled in Settings, otherwise continuous scroll.
                        Group {
                            if usePageSwipe && pageFlipVisibility.isVisible {
                                pageFlipLyricsContainer
                            } else {
                                continuousLyricsContainer
                            }
                        }
                        .opacity(isViewReady ? 1.0 : 0.0)
                        .offset(y: isViewReady ? 0 : 15)
                        
                        // Integrated glassmorphic player
                        if isAudioPlayerVisible {
                            if usesMidiPlayback {
                                glassmorphicMidiPlayer(isEmbedded: false)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            } else {
                                glassmorphicAudioPlayer(isEmbedded: false)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isHidden)
                }
            } // closes ZStack
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isLandscape || isHidden {
                        hideActionsChip
                    }
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    AirPlayRoutePicker()
                        .frame(width: 28, height: 28)
                    
                    if CastService.shared.featureEnabled {
                        Button {
                            castSongTitle = "\(hymn.type == "keerthane" ? "Keerthane" : (hymn.type == "mt" ? "M.T." : "Hymn")) \(hymn.number) — \(hymn.title)"
                            showCastSheet = true
                        } label: {
                            Image(systemName: "airplayaudio")
                                .foregroundColor(theme.textPrimary)
                        }
                    }
                    
                    CastButton(tint: theme.textPrimary)
                    
                    Button {
                        viewModel.isShowingReportSheet = true
                    } label: {
                        Image(systemName: "exclamationmark.bubble")
                            .foregroundColor(theme.textPrimary)
                    }
                    
                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: favoritesManager.isFavorite(songId: hymn.id) ? "heart.fill" : "heart")
                            .foregroundColor(favoritesManager.isFavorite(songId: hymn.id) ? .red : theme.textPrimary)
                            .scaleEffect(favoriteScale)
                    }
                }
            }
        } // closes GeometryReader
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        // Immersive reading navbar auto-hide behavior
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $viewModel.isShowingReportSheet) {
            reportLyricsSheet
        }
        .sheet(isPresented: $showCastSheet) {
            CastControlSheet(songTitle: castSongTitle)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAudioContribution) {
            AudioContributionView(
                songType: hymn.type == "keerthane" ? "Keerthane" : (hymn.type == "mt" ? "M.T. Hymn" : "Hymn"),
                songNumber: hymn.number,
                songTitle: hymn.title
            ) {
                showAudioContribution = false
                closeAudioPlayer()
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            let progress = ReadingProgressService.load(itemType: hymn.type, itemId: "\(hymn.number)")
            if let lang = progress.language {
                viewModel.selectedLanguage = lang == "english" ? .english : .kannada
            }
            if let font = progress.fontSize {
                viewModel.fontSize = CGFloat(font)
            }
            pendingScrollRestore = progress.scrollOffset
            let prefix = hymn.type.lowercased() == "keerthane" ? "keerthane_" : "hymn_"
            RecentSongsService.shared.addRecentSong(prefix: prefix, number: hymn.number)
            PostHogService.shared.trackScreen("\(hymn.type.capitalized) Detail Screen")
            PostHogService.shared.track(event: "song_detail_opened", properties: [
                "song_id": hymn.id,
                "song_number": hymn.number,
                "song_title": hymn.title,
                "song_type": hymn.type,
                "song_signature": hymn.signature,
                "initial_language": viewModel.selectedLanguage.rawValue
            ])
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                isViewReady = true
            }
        }
        .onDisappear {
            ReadingProgressService.save(
                itemType: hymn.type,
                itemId: "\(hymn.number)",
                fontSize: Double(viewModel.fontSize),
                language: viewModel.selectedLanguage == .english ? "english" : "kannada",
                scrollOffset: scrollOffset
            )
            audio.pause()
            midiAudio.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                // Android ACTION_SCREEN_OFF parity — pause when leaving the screen.
                if midiAudio.isPlaying { midiAudio.pausePlayback() }
                if audio.isPlaying { audio.pause() }
            }
        }
        .task(id: hymn.id) {
            isHidden = false
            userTouchedActionVisibility = false
            autoHidActionsForAudio = false
            
            await MidiFileCatalog.shared.refresh()
            midiFilesList = MidiFileCatalog.shared.fileNames
            
            tuneOptions = SongAudioURL.extractTuneOptions(for: hymn, midiFiles: midiFilesList)
            selectedTune = tuneOptions.first
            
            if hymn.type == "mt" {
                await withTaskGroup(of: String?.self) { group in
                    for opt in tuneOptions {
                        let cleanBase = opt.filter { $0.isNumber }
                        for suffix in ["a", "b", "c", "d"] {
                            let candidate = cleanBase + suffix
                            if candidate != opt {
                                group.addTask {
                                    let urlStr = SongAudioURL.streamURL(for: hymn, selectedTune: candidate, midiFiles: midiFilesList)
                                    if await SongAudioURL.checkUrlExists(urlStr: urlStr) {
                                        return candidate
                                    }
                                    return nil
                                }
                            }
                        }
                    }
                    
                    for await verifiedOption in group {
                        if let valid = verifiedOption, !tuneOptions.contains(valid) {
                            tuneOptions.append(valid)
                        }
                    }
                }
                
                tuneOptions.sort { a, b in
                    let numA = Int(a.filter { $0.isNumber }) ?? 0
                    let numB = Int(b.filter { $0.isNumber }) ?? 0
                    if numA == numB { return a < b }
                    return numA < numB
                }
            }
        }
    }
    
    private var sidebarSettingsPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Lyrics Options")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
            }
            
            HStack(spacing: 12) {
                // Font Size
                HStack(spacing: 8) {
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        viewModel.fontSize = max(14, viewModel.fontSize - 2)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 16))
                            .foregroundColor(theme.textPrimary.opacity(0.8))
                    }
                    
                    Text("\(Int(viewModel.fontSize))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .frame(width: 18)
                    
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        viewModel.fontSize = min(40, viewModel.fontSize + 2)
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                            .foregroundColor(theme.textPrimary.opacity(0.8))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(theme.surfaceColor)
                .cornerRadius(10)
                
                Spacer()
                
                audioIntentChip
            }
            
            // Bilingual Language Selector
            HStack(spacing: 2) {
                ForEach(HymnDetailViewModel.SongLanguage.allCases) { lang in
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation {
                            viewModel.selectedLanguage = lang
                        }
                    } label: {
                        Text(lang.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(viewModel.selectedLanguage == lang ? theme.textPrimary.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
                            .foregroundColor(theme.textPrimary)
                    }
                }
            }
            .padding(4)
            .background(theme.surfaceColor)
            .cornerRadius(10)
        }
        .padding(12)
        .background(theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.strokeColor, lineWidth: 1)
        )
    }
    
    private var hideActionsChip: some View {
        Button {
            userTouchedActionVisibility = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isHidden.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isHidden ? "eye" : "eye.slash")
                    .font(.system(size: 12, weight: .semibold))
                Text(isHidden ? "Show Actions" : "Hide Actions")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(theme.textPrimary)
        }
        .accessibilityLabel(isHidden ? "Show Actions" : "Hide Actions")
    }
    
    private func toggleFavorite() {
        let isFav = favoritesManager.isFavorite(songId: hymn.id)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
            favoriteScale = 1.4
            favoritesManager.toggleFavorite(song: hymn)
        }
        Task {
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                favoriteScale = 1.0
            }
        }
        PostHogService.shared.track(event: isFav ? "song_favorite_removed" : "song_favorite_added", properties: [
            "song_id": hymn.id,
            "song_number": hymn.number,
            "song_type": hymn.type,
            "song_title": hymn.title
        ])
    }
    
    /// Audio chip: first tap opens + plays; later taps pause/resume. Close only via player X.
    private func handleAudioIntentTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isAudioPlayerVisible {
            if usesMidiPlayback {
                midiAudio.togglePlayback()
            } else {
                audio.togglePlayback()
            }
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isAudioPlayerVisible = true
        }
        startAudioPlayback()
        PostHogService.shared.track(event: "audio_playback_started", properties: [
            "song_id": hymn.id,
            "song_number": hymn.number,
            "song_type": hymn.type,
            "song_title": hymn.title
        ])
    }
    
    private func closeAudioPlayer() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isAudioPlayerVisible = false
            restoreActionsAfterAudioDismiss()
        }
        stopAudioPlayback()
        PostHogService.shared.track(event: "audio_playback_dismissed", properties: [
            "song_id": hymn.id,
            "song_number": hymn.number,
            "song_type": hymn.type
        ])
    }
    
    /// Restore lyric actions when the player closes, unless the user already showed them.
    /// Manual Hide while the player is open still restores on dismiss.
    private func restoreActionsAfterAudioDismiss() {
        let userAlreadyShowing = userTouchedActionVisibility && !isHidden
        if userAlreadyShowing {
            autoHidActionsForAudio = false
            return
        }
        if autoHidActionsForAudio || userTouchedActionVisibility {
            isHidden = false
        }
        autoHidActionsForAudio = false
    }
    
    @ViewBuilder
    private var audioIntentChip: some View {
        let playing = usesMidiPlayback ? midiAudio.isPlaying : audio.isPlaying
        let loading = usesMidiPlayback ? midiAudio.isLoading : audio.isLoading
        
        Button(action: handleAudioIntentTap) {
            HStack(spacing: 5) {
                if loading {
                    ProgressView()
                        .controlSize(.mini)
                } else if isAudioPlayerVisible && playing {
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .semibold))
                        .symbolEffect(.variableColor.iterative, options: .repeating, isActive: true)
                } else if isAudioPlayerVisible {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12, weight: .bold))
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                
                Text(isAudioPlayerVisible ? (playing ? "Playing" : "Paused") : "Audio")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isAudioPlayerVisible ? theme.textPrimary.opacity(0.12) : theme.surfaceColor)
            .cornerRadius(10)
            .foregroundColor(theme.textPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isAudioPlayerVisible ? theme.textPrimary.opacity(0.3) : theme.strokeColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var sidebarToolbarRow: some View {
        HStack(spacing: 10) {
            hideActionsChip
            
            Spacer(minLength: 0)
            
            HStack(spacing: 14) {
                AirPlayRoutePicker()
                    .frame(width: 24, height: 24)
                
                CastButton(tint: theme.textPrimary)
                
                Button {
                    viewModel.isShowingReportSheet = true
                } label: {
                    Image(systemName: "exclamationmark.bubble")
                        .foregroundColor(theme.textPrimary)
                }
                
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: favoritesManager.isFavorite(songId: hymn.id) ? "heart.fill" : "heart")
                        .foregroundColor(favoritesManager.isFavorite(songId: hymn.id) ? .red : theme.textPrimary)
                        .scaleEffect(favoriteScale)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.strokeColor, lineWidth: 1)
            )
        }
    }
    
    private var headerPanel: some View {
        HStack(spacing: 8) {
            // Font Zoom Controllers
            HStack(spacing: 8) {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    viewModel.fontSize = max(14, viewModel.fontSize - 2)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 16))
                        .foregroundColor(theme.textPrimary.opacity(0.8))
                }
                
                Text("\(Int(viewModel.fontSize))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 18)
                
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    viewModel.fontSize = min(40, viewModel.fontSize + 2)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                        .foregroundColor(theme.textPrimary.opacity(0.8))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(theme.surfaceColor)
            .cornerRadius(10)
            .layoutPriority(0.3)
            
            audioIntentChip
                .layoutPriority(0.3)
            
            Spacer(minLength: 4)
            
            // Bilingual Language Selector
            HStack(spacing: 2) {
                ForEach(HymnDetailViewModel.SongLanguage.allCases) { lang in
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation {
                            viewModel.selectedLanguage = lang
                        }
                        PostHogService.shared.track(event: "lyrics_language_switched", properties: [
                            "song_id": hymn.id,
                            "song_number": hymn.number,
                            "song_type": hymn.type,
                            "selected_language": lang.rawValue
                        ])
                    } label: {
                        Text(lang.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedLanguage == lang ? theme.textPrimary.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
                            .foregroundColor(theme.textPrimary)
                    }
                }
            }
            .padding(4)
            .background(theme.surfaceColor)
            .cornerRadius(10)
            .layoutPriority(1)
        }
    }

    
    private func metadataHeaderCard(compact: Bool) -> some View {
        VStack(spacing: compact ? 0 : 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    Text("\(hymn.type.uppercased()) NO. \(hymn.number)")
                        .font(.system(size: compact ? 10 : 11, weight: .bold))
                        .foregroundColor(theme.textSecondary.opacity(0.8))
                        .tracking(1.5)
                    
                    Text(hymn.title)
                        .font(.system(size: compact ? 15 : 18, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(compact ? 2 : nil)
                }
                Spacer(minLength: 8)
                
                if !compact {
                    Text(hymn.type == "keerthane" ? "Keerthane" : (hymn.type == "mt" ? "M.T." : "Hymn"))
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.textPrimary.opacity(0.08))
                        .cornerRadius(6)
                        .foregroundColor(theme.textPrimary)
                }
            }
            
            if !compact, !hymn.signature.isEmpty {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(hymn.type == "keerthane" ? "keerthane" : "hymn")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 16, height: 16)
                        Text("Meter: \(hymn.signature)")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(theme.textSecondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 11))
                        Text("Traditional / Classic")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(theme.textSecondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(compact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: compact ? 12 : 16)
                .fill(theme.surfaceColor)
                .overlay(RoundedRectangle(cornerRadius: compact ? 12 : 16).stroke(theme.strokeColor, lineWidth: 1))
        )
        .padding(.horizontal)
    }
    
    /// Swipeable page-flip lyrics reader (Settings: Page Swipe Transitions).
    private var pageFlipLyricsContainer: some View {
        let text = viewModel.selectedLanguage == .kannada ? hymn.lyricsKannada : hymn.lyricsEnglish
        return PageFlipLyricsView(
            lyrics: text,
            fontSize: viewModel.fontSize,
            textColor: theme.textPrimary,
            accent: theme.accentColor
        )
    }
    
    /// Continuous vertical scroll lyrics container for uninterrupted native reading experience.
    private var continuousLyricsContainer: some View {
        let text = viewModel.selectedLanguage == .kannada ? hymn.lyricsKannada : hymn.lyricsEnglish
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {
                    Color.clear
                        .frame(height: 1)
                        .id("lyrics_top")
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: LyricsScrollOffsetKey.self,
                                    value: Double(-geo.frame(in: .named("lyricsScroll")).minY)
                                )
                            }
                        )
                    
                    ForEach(0..<paragraphs.count, id: \.self) { idx in
                        Text(paragraphs[idx])
                            .font(.system(size: viewModel.fontSize, weight: .semibold))
                            .lineSpacing(viewModel.fontSize * 0.35)
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 28)
                            .id("verse_\(idx)")
                    }
                }
                .padding(.vertical, 20)
            }
            .coordinateSpace(name: "lyricsScroll")
            .onPreferenceChange(LyricsScrollOffsetKey.self) { value in
                scrollOffset = max(0, value)
            }
            .onAppear {
                restoreScrollIfNeeded(proxy: proxy, verseCount: paragraphs.count)
            }
            .onChange(of: viewModel.selectedLanguage) { _, _ in
                restoreScrollIfNeeded(proxy: proxy, verseCount: paragraphs.count)
            }
        }
    }
    
    private func restoreScrollIfNeeded(proxy: ScrollViewProxy, verseCount: Int) {
        guard let offset = pendingScrollRestore, offset > 20 else { return }
        pendingScrollRestore = nil
        // Approximate restore by verse index derived from prior offset.
        let estimatedVerse = min(max(Int(offset / 120.0), 0), max(verseCount - 1, 0))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo("verse_\(estimatedVerse)", anchor: .top)
            }
        }
    }
    
    private func glassmorphicAudioPlayer(isEmbedded: Bool) -> some View {
        let player = VStack(spacing: 12) {
            playerTopBar(title: hymn.title)
            playerSeekRow(
                current: dragTime ?? audio.currentTime,
                duration: audio.duration,
                onEdit: { editing, value in
                    if editing {
                        dragTime = value
                    } else {
                        if let targetTime = dragTime {
                            audio.seek(to: targetTime)
                        }
                        dragTime = nil
                    }
                }
            )
            HStack {
                playerSpeedControl(
                    rate: Double(audio.playbackRate),
                    minRate: 0.75,
                    maxRate: 2.0,
                    step: 0.25,
                    onChange: { audio.playbackRate = Float($0) }
                )
                Spacer(minLength: 0)
            }
            playerTransportRow(
                isLooping: audio.isLooping,
                isLoading: audio.isLoading,
                isPlaying: audio.isPlaying,
                onLoop: { audio.isLooping.toggle() },
                onBack: { audio.skipBackward() },
                onPlayPause: { audio.togglePlayback() },
                onForward: { audio.skipForward() }
            )
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .padding(.bottom, isEmbedded ? 12 : 20)
        .background(playerChrome(isEmbedded: isEmbedded))
        
        return Group {
            if isEmbedded {
                player
            } else {
                player.ignoresSafeArea(edges: .bottom)
            }
        }
    }
    
    private func glassmorphicMidiPlayer(isEmbedded: Bool) -> some View {
        let player = VStack(spacing: 12) {
            if let audioErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(audioErrorMessage)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button("Contribute") {
                        showAudioContribution = true
                    }
                    .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.orange)
                .padding(10)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(10)
            }
            
            playerTopBar(title: selectedTuneDisplayName.isEmpty ? hymn.title : selectedTuneDisplayName)
            
            if tuneOptions.count > 1 {
                Menu {
                    ForEach(Array(tuneOptions.enumerated()), id: \.element) { index, tune in
                        Button {
                            if selectedTune != tune {
                                selectedTune = tune
                                let streamUrl = SongAudioURL.streamURL(for: hymn, selectedTune: tune, midiFiles: midiFilesList)
                                Task {
                                    midiAudio.stop()
                                    do {
                                        try await midiAudio.loadAndPlay(urlString: streamUrl)
                                        audioErrorMessage = nil
                                    } catch {
                                        if SongAudioURL.shouldAllowOggFallback(for: hymn) {
                                            audio.loadAndPlay(
                                                urlString: SongAudioURL.oggFallbackURL(for: hymn),
                                                title: "Hymn \(hymn.number)",
                                                subtitle: hymn.title
                                            )
                                        } else {
                                            audioErrorMessage = error.localizedDescription
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(tuneDisplayName(for: tune, index: index))
                                if selectedTune == tune {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Tune")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                        Text(selectedTuneDisplayName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(tuneOptions.count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.surfaceColor.opacity(0.85))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.strokeColor, lineWidth: 1))
                }
            }
            
            HStack(spacing: 10) {
                Text(formatTime(dragTime ?? midiAudio.currentTime))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 40, alignment: .leading)
                
                Slider(
                    value: Binding(
                        get: { dragTime ?? midiAudio.currentTime },
                        set: { dragTime = $0 }
                    ),
                    in: 0...max(1, midiAudio.duration),
                    onEditingChanged: { editing in
                        HapticsManager.shared.triggerSelection()
                        if editing {
                            dragTime = dragTime ?? midiAudio.currentTime
                        } else {
                            if let targetTime = dragTime {
                                midiAudio.seek(to: targetTime)
                            }
                            dragTime = nil
                        }
                    }
                )
                .tint(theme.textPrimary)
                
                Text(formatTime(midiAudio.duration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.horizontal, 4)
            
            HStack(spacing: 8) {
                playerSpeedControl(
                    rate: Double(midiAudio.playbackRate),
                    minRate: 0.5,
                    maxRate: 1.5,
                    step: 0.05,
                    onChange: { midiAudio.playbackRate = Float($0) }
                )
                
                playerTransposeControl
                
                Spacer(minLength: 4)
                
                Button {
                    isShowingAdvancedMidi = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(theme.surfaceColor.opacity(0.85))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(theme.strokeColor, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Advanced MIDI settings")
            }
            
            playerTransportRow(
                isLooping: midiAudio.isLooping,
                isLoading: midiAudio.isLoading,
                isPlaying: midiAudio.isPlaying,
                onLoop: {
                    HapticsManager.shared.triggerLight()
                    midiAudio.isLooping.toggle()
                },
                onBack: { midiAudio.skipBackward() },
                onPlayPause: { midiAudio.togglePlayback() },
                onForward: { midiAudio.skipForward() }
            )
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .padding(.bottom, isEmbedded ? 12 : 20)
        .background(playerChrome(isEmbedded: isEmbedded))
        .sheet(isPresented: $isShowingAdvancedMidi) {
            AdvancedMidiSettingsView()
        }
        
        return Group {
            if isEmbedded {
                player
            } else {
                player.ignoresSafeArea(edges: .bottom)
            }
        }
    }
    
    private func playerTopBar(title: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(hymn.type == "keerthane" ? "Keerthane \(hymn.number)" : (hymn.type == "mt" ? "M.T. \(hymn.number)" : "Hymn \(hymn.number)"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: closeAudioPlayer) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(theme.surfaceColor.opacity(0.9))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(theme.strokeColor, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close player")
        }
    }
    
    private func playerSpeedControl(
        rate: Double,
        minRate: Double,
        maxRate: Double,
        step: Double,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Text("Speed")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            
            Button {
                let next = max(minRate, (rate - step))
                onChange((next * 100).rounded() / 100)
                HapticsManager.shared.triggerSelection()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .disabled(rate <= minRate)
            
            Text(String(format: "%.2fx", rate))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
                .frame(minWidth: 44)
            
            Button {
                let next = min(maxRate, (rate + step))
                onChange((next * 100).rounded() / 100)
                HapticsManager.shared.triggerSelection()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .disabled(rate >= maxRate)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surfaceColor.opacity(0.85))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(theme.strokeColor, lineWidth: 1))
        .foregroundColor(theme.textPrimary)
    }
    
    private var playerTransposeControl: some View {
        HStack(spacing: 6) {
            Text("Key")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.textSecondary)
            
            Button {
                midiAudio.transpose = max(-12, midiAudio.transpose - 1)
                HapticsManager.shared.triggerSelection()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .disabled(midiAudio.transpose <= -12)
            
            Text(midiAudio.transpose == 0 ? "0" : String(format: "%+d", midiAudio.transpose))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
                .frame(minWidth: 28)
            
            Button {
                midiAudio.transpose = min(12, midiAudio.transpose + 1)
                HapticsManager.shared.triggerSelection()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .disabled(midiAudio.transpose >= 12)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surfaceColor.opacity(0.85))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(theme.strokeColor, lineWidth: 1))
        .foregroundColor(theme.textPrimary)
    }
    
    private func playerSeekRow(
        current: TimeInterval,
        duration: TimeInterval,
        onEdit: @escaping (_ editing: Bool, _ value: TimeInterval) -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(formatTime(current))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textSecondary)
                .frame(width: 42, alignment: .leading)
            
            Slider(
                value: Binding(
                    get: { current },
                    set: { onEdit(true, $0) }
                ),
                in: 0...max(1, duration),
                onEditingChanged: { editing in
                    onEdit(editing, current)
                }
            )
            .tint(theme.textPrimary)
            
            Text(formatTime(duration))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textSecondary)
                .frame(width: 42, alignment: .trailing)
        }
    }
    
    private func playerTransportRow(
        isLooping: Bool,
        isLoading: Bool,
        isPlaying: Bool,
        onLoop: @escaping () -> Void,
        onBack: @escaping () -> Void,
        onPlayPause: @escaping () -> Void,
        onForward: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            Button(action: onLoop) {
                Image(systemName: isLooping ? "repeat.1" : "repeat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isLooping ? .red : theme.textSecondary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            
            Spacer(minLength: 8)
            
            Button(action: onBack) {
                Image(systemName: "gobackward.5")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            
            Spacer(minLength: 8)
            
            Button(action: onPlayPause) {
                ZStack {
                    Circle()
                        .fill(theme.textPrimary)
                        .frame(width: 52, height: 52)
                    if isLoading {
                        ProgressView()
                            .tint(theme.backgroundColor)
                    } else {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(theme.backgroundColor)
                            .offset(x: isPlaying ? 0 : 1)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Spacer(minLength: 8)
            
            Button(action: onForward) {
                Image(systemName: "goforward.5")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            
            Spacer(minLength: 8)
            
            Color.clear
                .frame(width: 40, height: 40)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func playerChrome(isEmbedded: Bool) -> some View {
        Group {
            if isEmbedded {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.cardBackground)
            } else {
                UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 18,
                    style: .continuous
                )
                .fill(.ultraThinMaterial)
            }
        }
        .overlay(
            Group {
                if isEmbedded {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.strokeColor, lineWidth: 1)
                } else {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 18,
                        style: .continuous
                    )
                    .stroke(theme.strokeColor, lineWidth: 1)
                }
            }
        )
    }
    
    private var reportLyricsSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Describe the lyric issues...")) {
                    TextEditor(text: $viewModel.reportDescription)
                        .frame(height: 120)
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.isShowingReportSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Report") {
                        Task {
                            await viewModel.submitReport(hymn: hymn)
                        }
                    }
                    .disabled(viewModel.reportDescription.isEmpty || viewModel.isReportSubmitting)
                }
            }
        }
    }

    // MARK: - Helpers
    private var usesMidiPlayback: Bool {
        if forceOggPlayer { return false }
        return hymn.type == "mt" || SongAudioURL.isMidiFileURL(SongAudioURL.streamURL(for: hymn, selectedTune: selectedTune, midiFiles: midiFilesList))
    }
    
    /// Android `TUNE_METER_VIEW`: only admins with this role (or sudo/super admin) see real meter names.
    private var canViewTuneMeters: Bool {
        AdminPrefs.hasRole(
            currentUserEmail: SupabaseService.instance.currentUserEmail,
            adminEmailsConfig: AppConfigService.shared.config.adminEmails,
            requiredRole: .tuneMeterView
        )
    }
    
    private var selectedTuneDisplayName: String {
        let tune = selectedTune ?? tuneOptions.first ?? ""
        let index = tuneOptions.firstIndex(of: tune) ?? 0
        return tuneDisplayName(for: tune, index: index)
    }
    
    private func tuneDisplayName(for tune: String, index: Int) -> String {
        if hymn.type == "keerthane" || hymn.type == "mt" {
            if tune == "\(hymn.number)" { return "Default" }
            return tune
        }
        if canViewTuneMeters {
            return MeterUtils.displayTuneName(tune)
        }
        return "Version \(index + 1)"
    }
    
    private func startAudioPlayback() {
        audioErrorMessage = nil
        forceOggPlayer = false
        let streamUrl = SongAudioURL.streamURL(for: hymn, selectedTune: selectedTune, midiFiles: midiFilesList)
        // Collapse lyric actions for playback unless the user already hid them.
        if !isHidden {
            autoHidActionsForAudio = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isHidden = true
            }
        }
        
        if SongAudioURL.isMidiFileURL(streamUrl) || hymn.type == "mt" {
            Task {
                do {
                    try await midiAudio.loadAndPlay(urlString: streamUrl)
                } catch let error as MidiDownloadError where error == .notFound {
                    await fallbackToOgg(orShow: error.localizedDescription)
                } catch {
                    if isNotFound(error) {
                        await fallbackToOgg(orShow: error.localizedDescription)
                    } else {
                        audioErrorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            forceOggPlayer = true
            audio.loadAndPlay(
                urlString: streamUrl,
                title: "\(hymn.type == "keerthane" ? "Keerthane" : "Hymn") \(hymn.number)",
                subtitle: hymn.title
            )
        }
    }
    
    @MainActor
    private func fallbackToOgg(orShow message: String) async {
        if SongAudioURL.shouldAllowOggFallback(for: hymn) {
            forceOggPlayer = true
            midiAudio.stop()
            audio.loadAndPlay(
                urlString: SongAudioURL.oggFallbackURL(for: hymn),
                title: "\(hymn.type == "keerthane" ? "Keerthane" : "Hymn") \(hymn.number)",
                subtitle: hymn.title
            )
            // If OGG also fails quickly, user can still tap Contribute from the error banner.
        } else {
            audioErrorMessage = message
            showAudioContribution = true
        }
    }
    
    private func isNotFound(_ error: Error) -> Bool {
        if let midiError = error as? MidiDownloadError {
            if case .notFound = midiError { return true }
        }
        return error.localizedDescription.lowercased().contains("404")
            || error.localizedDescription.lowercased().contains("not found")
    }
    
    private func stopAudioPlayback() {
        if usesMidiPlayback || midiAudio.currentURL != nil {
            midiAudio.stop()
        }
        audio.pause()
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "00:00" }
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Advanced MIDI Settings View
struct AdvancedMidiSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var engine = MidiPlaybackEngine.shared
    @State private var globalInstrumentId: Int = MidiInstruments.currentProgramId
    
    let instrumentOptions = MidiInstruments.all
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Global Settings")) {
                    Picker("Instrument", selection: $globalInstrumentId) {
                        ForEach(instrumentOptions, id: \.program) { option in
                            Text(option.name).tag(option.program)
                        }
                    }
                    .onChange(of: globalInstrumentId) { _, newValue in
                        HapticsManager.shared.triggerSelection()
                        engine.updateGlobalInstrument(to: newValue)
                    }
                }
                
                Section(header: Text("Track Routing (SATB)"), footer: Text("Mute or assign instruments per part. Track 1 = Soprano, 2 = Alto, 3 = Tenor, 4 = Bass. Speed and transpose are on the main player.")) {
                    Toggle("Enable Advanced Routing", isOn: Binding(
                        get: { engine.isAdvancedMode },
                        set: {
                            HapticsManager.shared.triggerSelection()
                            engine.isAdvancedMode = $0
                        }
                    ))
                    
                    if engine.isAdvancedMode {
                        ForEach(0..<4, id: \.self) { index in
                            Toggle("Mute \(partName(for: index))", isOn: Binding(
                                get: { engine.satbMuted[index] },
                                set: { newValue in
                                    HapticsManager.shared.triggerSelection()
                                    engine.satbMuted[index] = newValue
                                }
                            ))
                            
                            Picker(partName(for: index), selection: Binding(
                                get: { engine.satbInstruments[index] },
                                set: { newValue in
                                    HapticsManager.shared.triggerSelection()
                                    engine.satbInstruments[index] = newValue
                                }
                            )) {
                                ForEach(instrumentOptions, id: \.program) { option in
                                    Text(option.name).tag(UInt8(option.program))
                                }
                            }
                            .disabled(engine.satbMuted[index])
                        }
                    }
                }
            }
            .navigationTitle("Advanced Audio Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func partName(for index: Int) -> String {
        switch index {
        case 0: return "Soprano (Track 1)"
        case 1: return "Alto (Track 2)"
        case 2: return "Tenor (Track 3)"
        case 3: return "Bass (Track 4)"
        default: return "Track \(index + 1)"
        }
    }
}

private struct LyricsScrollOffsetKey: PreferenceKey {
    static var defaultValue: Double = 0
    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = nextValue()
    }
}

private extension Float {
    func rounded(toPlaces places: Int) -> Float {
        let divisor = pow(10.0, Float(places))
        return (self * divisor).rounded() / divisor
    }
}
