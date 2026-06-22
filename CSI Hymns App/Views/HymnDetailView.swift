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
    public var fontSize: CGFloat = 18.0
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
    @State private var theme = ThemeManager.shared
    @State private var viewModel = HymnDetailViewModel()
    @State private var audio = AudioService.shared
    @State private var favoritesManager = FavoritesManager.shared
    @State private var isShowingSpeedMenu = false
    @State private var favoriteScale: CGFloat = 1.0
    @State private var isAudioPlayerVisible = false
    @State private var dragTime: Double? = nil
    
    public init(hymn: Hymn) {
        self.hymn = hymn
    }
    
    public var body: some View {
        @Bindable var viewModel = viewModel
        ZStack {
            // Adaptive theme background
            theme.backgroundColor
                .ignoresSafeArea()
            
            if theme.activeTheme != .amoled {
                theme.backgroundGradient
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Header Panel: Bilingual Toggles, Zoom controls & Audio toggle
                headerPanel
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                Divider()
                    .background(theme.strokeColor)
                    .padding(.vertical, 8)
                
                // Elegant metadata header card
                metadataHeaderCard
                    .padding(.bottom, 8)
                
                // Lyrics: page-flip when enabled in Settings, otherwise continuous scroll.
                if usePageSwipe && pageFlipVisibility.isVisible {
                    pageFlipLyricsContainer
                } else {
                    continuousLyricsContainer
                }
                
                // Integrated glassmorphic player
                if isAudioPlayerVisible {
                    glassmorphicAudioPlayer
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("\(hymn.type == "keerthane" ? "Keerthane" : "Hymn") \(hymn.number)")
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        // Immersive reading navbar auto-hide behavior
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Casting pickers (AirPlay always; Chromecast when remotely enabled)
                AirPlayRoutePicker()
                    .frame(width: 28, height: 28)
                
                CastButton(tint: theme.textPrimary)
                
                // Issue reporter
                Button {
                    viewModel.isShowingReportSheet = true
                } label: {
                    Image(systemName: "exclamationmark.bubble")
                        .foregroundColor(theme.textPrimary)
                }
                
                // Heart-shaped toggle favorite buttons
                Button {
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
                } label: {
                    Image(systemName: favoritesManager.isFavorite(songId: hymn.id) ? "heart.fill" : "heart")
                        .foregroundColor(favoritesManager.isFavorite(songId: hymn.id) ? .red : theme.textPrimary)
                        .scaleEffect(favoriteScale)
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingReportSheet) {
            reportLyricsSheet
        }
        .onAppear {
            let progress = ReadingProgressService.load(itemType: hymn.type, itemId: "\(hymn.number)")
            if let font = progress.fontSize { viewModel.fontSize = CGFloat(font) }
            if let lang = progress.language {
                viewModel.selectedLanguage = lang == "english" ? .english : .kannada
            }
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
        }
        .onDisappear {
            ReadingProgressService.save(
                itemType: hymn.type,
                itemId: "\(hymn.number)",
                fontSize: Double(viewModel.fontSize),
                language: viewModel.selectedLanguage == .english ? "english" : "kannada"
            )
            audio.pause()
        }
    }
    
    // MARK: - Subviews
    
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
            
            // Audio Intent Button (plays only on deliberate tap)
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isAudioPlayerVisible.toggle()
                    if isAudioPlayerVisible {
                        let streamUrl = SongAudioURL.streamURL(for: hymn)
                        audio.loadAndPlay(urlString: streamUrl, title: "\(hymn.type == "keerthane" ? "Keerthane" : "Hymn") \(hymn.number)", subtitle: hymn.title)
                        PostHogService.shared.track(event: "audio_playback_started", properties: [
                            "song_id": hymn.id,
                            "song_number": hymn.number,
                            "song_type": hymn.type,
                            "song_title": hymn.title
                        ])
                    } else {
                        audio.pause()
                        PostHogService.shared.track(event: "audio_playback_dismissed", properties: [
                            "song_id": hymn.id,
                            "song_number": hymn.number,
                            "song_type": hymn.type
                        ])
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isAudioPlayerVisible ? (audio.isPlaying ? "waveform.and.mic" : "pause.circle.fill") : "play.circle.fill")
                        .font(.system(size: 14))
                    Text(isAudioPlayerVisible ? (audio.isPlaying ? "Playing" : "Paused") : "Audio")
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

    
    private var metadataHeaderCard: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(hymn.type.uppercased()) NO. \(hymn.number)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(theme.textSecondary.opacity(0.8))
                        .tracking(1.5)
                    
                    Text(hymn.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                
                // Song type badge
                Text(hymn.type == "keerthane" ? "Keerthane" : "Hymn")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.textPrimary.opacity(0.08))
                    .cornerRadius(6)
                    .foregroundColor(theme.textPrimary)
            }
            
            if !hymn.signature.isEmpty {
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.surfaceColor)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.strokeColor, lineWidth: 1))
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
        
        return ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(0..<paragraphs.count, id: \.self) { idx in
                    Text(paragraphs[idx])
                        .font(.system(size: viewModel.fontSize, weight: .semibold))
                        .lineSpacing(viewModel.fontSize * 0.35)
                        .foregroundColor(theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                }
            }
            .padding(.vertical, 20)
        }
    }
    
    private var glassmorphicAudioPlayer: some View {
        VStack(spacing: 12) {
            // Progression Track bar & timings
            HStack {
                Text(formatTime(dragTime ?? audio.currentTime))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
                
                Slider(
                    value: Binding(
                        get: { dragTime ?? audio.currentTime },
                        set: { dragTime = $0 }
                    ),
                    in: 0...max(1, audio.duration),
                    onEditingChanged: { editing in
                        if !editing {
                            if let targetTime = dragTime {
                                audio.seek(to: targetTime)
                            }
                            dragTime = nil
                        }
                    }
                )
                .accentColor(theme.textPrimary)
                
                Text(formatTime(audio.duration))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.horizontal)
            
            // Audio Controls Center
            HStack(spacing: 32) {
                // Loop button
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    audio.isLooping.toggle()
                } label: {
                    Image(systemName: audio.isLooping ? "repeat.1" : "repeat")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(audio.isLooping ? .red : theme.textSecondary)
                }
                
                // Backward 5s
                Button {
                    audio.skipBackward()
                } label: {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 22))
                        .foregroundColor(theme.textPrimary)
                }
                
                // Play / Pause
                Button {
                    audio.togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(theme.textPrimary)
                            .frame(width: 54, height: 54)
                        
                        if audio.isLoading {
                            ProgressView()
                                .tint(theme.backgroundColor)
                        } else {
                            Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 22))
                                .foregroundColor(theme.backgroundColor)
                        }
                    }
                }
                
                // Forward 5s
                Button {
                    audio.skipForward()
                } label: {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 22))
                        .foregroundColor(theme.textPrimary)
                }
                
                // Speed Controller
                Menu {
                    ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button {
                            audio.playbackRate = Float(rate)
                        } label: {
                            HStack {
                                Text("\(String(format: "%.2fx", rate))")
                                if abs(audio.playbackRate - Float(rate)) < 0.05 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(String(format: "%.1fx", audio.playbackRate))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(theme.surfaceColor))
                        .foregroundColor(theme.textPrimary)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            // Ultimate Material Blur layer
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .stroke(theme.strokeColor, lineWidth: 1)
                )
                .ignoresSafeArea()
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
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
