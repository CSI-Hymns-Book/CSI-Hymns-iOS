import SwiftUI
import Observation
import AVKit

#if canImport(AVFoundation)
import AVFoundation
#endif

/// View representing native AirPlay cast selection widgets.
public struct AirPlayRoutePicker: UIViewRepresentable {
    public init() {}
    public func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .systemBlue
        picker.tintColor = .white
        return picker
    }
    
    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

/// Dynamic View-Model managing active detail actions.
@Observable
public final class HymnDetailViewModel {
    public var selectedLanguage: SongLanguage = .kannada
    public var fontSize: CGFloat = 18.0
    public var isFavorite = false
    public var isFavoriteLoading = false
    public var isShowingReportSheet = false
    public var reportDescription = ""
    public var isReportSubmitting = false
    
    public enum SongLanguage: String, CaseIterable, Identifiable {
        case english = "English"
        case kannada = "ಕನ್ನಡ"
        public var id: String { self.rawValue }
    }
    
    public init() {}
    
    public func toggleFavorite(hymn: Hymn) async {
        isFavoriteLoading = true
        // Native trigger haptics
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        do {
            let svc = SupabaseService.instance
            if svc.isAuthenticated {
                if isFavorite {
                    _ = try await svc.removeFavorite(itemNumber: hymn.number, itemType: "hymn")
                } else {
                    try await svc.addFavorite(itemNumber: hymn.number, itemType: "hymn")
                }
            }
            isFavorite.toggle()
        } catch {
            print("HymnDetailViewModel: Favorite sync fail: \(error)")
        }
        isFavoriteLoading = false
    }
    
    public func submitReport(hymn: Hymn) async {
        guard !reportDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isReportSubmitting = true
        
        // Post issue to Jira REST APIs using JiraService Actor
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
        }
        
        isReportSubmitting = false
        isShowingReportSheet = false
        reportDescription = ""
    }
}

/// A premium, immersive lyrics viewing and audio playing environment.
public struct HymnDetailView: View {
    let hymn: Hymn
    @State private var viewModel = HymnDetailViewModel()
    @State private var audio = AudioService.shared
    @State private var isShowingSpeedMenu = false
    
    public init(hymn: Hymn) {
        self.hymn = hymn
    }
    
    public var body: some View {
        ZStack {
            // Liquid Glass Background Gradients
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Panel: Bilingual Toggles & Zoom controls
                headerPanel
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.vertical, 12)
                
                // Content Swiper
                lyricsSwipeContainer
                
                // Integrated glassmorphic player
                if audio.isPlaying || audio.isLoading || audio.currentTime > 0 {
                    glassmorphicAudioPlayer
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle(hymn.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Casting picker
                AirPlayRoutePicker()
                    .frame(width: 28, height: 28)
                
                // Issue reporter
                Button {
                    viewModel.isShowingReportSheet = true
                } label: {
                    Image(systemName: "exclamationmark.bubble")
                        .foregroundColor(.white)
                }
                
                // Bookmarking favorites
                Button {
                    Task {
                        await viewModel.toggleFavorite(hymn: hymn)
                    }
                } label: {
                    if viewModel.isFavoriteLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: viewModel.isFavorite ? "bookmark.fill" : "bookmark")
                            .foregroundColor(viewModel.isFavorite ? .amber : .white)
                    }
                }
            }
        }
        .sheet(isPresented: &viewModel.isShowingReportSheet) {
            reportLyricsSheet
        }
        .onAppear {
            // Record song in recent reading history
            let prefix = hymn.type.lowercased() == "keerthane" ? "keerthane_" : "hymn_"
            RecentSongsService.shared.addRecentSong(prefix: prefix, number: hymn.number)
            
            // Load and buffer streaming audio
            let streamUrl = "https://raw.githubusercontent.com/reynold29/midi-files/main/Hymns/Hymn_\(hymn.number).ogg"
            audio.loadAndPlay(urlString: streamUrl, title: "Hymn \(hymn.number)", subtitle: hymn.title)
        }
    }
    
    // MARK: - Subviews
    
    private var headerPanel: some View {
        HStack {
            // Font Zoom Controllers
            HStack(spacing: 14) {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    viewModel.fontSize = max(14, viewModel.fontSize - 2)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Text("\(Int(viewModel.fontSize))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24)
                
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    viewModel.fontSize = min(40, viewModel.fontSize + 2)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            
            Spacer()
            
            // Bilingual Language Selector
            HStack(spacing: 6) {
                ForEach(HymnDetailViewModel.SongLanguage.allCases) { lang in
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation {
                            viewModel.selectedLanguage = lang
                        }
                    } label: {
                        Text(lang.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedLanguage == lang ? Color.white.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
        }
    }
    
    /// Swipable Multi-Page Lyrics Container using SwiftUI TabView page styling.
    private var lyricsSwipeContainer: some View {
        let text = viewModel.selectedLanguage == .kannada ? hymn.lyricsKannada : hymn.lyricsEnglish
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        return TabView {
            ForEach(0..<paragraphs.count, id: \.self) { idx in
                ScrollView {
                    Text(paragraphs[idx])
                        .font(.system(size: viewModel.fontSize, weight: .medium))
                        .lineSpacing(8)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 36)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
    }
    
    private var glassmorphicAudioPlayer: some View {
        VStack(spacing: 12) {
            // Progression Track bar & timings
            HStack {
                Text(formatTime(audio.currentTime))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                
                Slider(value: Binding(get: { audio.currentTime }, set: { audio.seek(to: $0) }), in: 0...max(1, audio.duration))
                    .accentColor(.white)
                
                Text(formatTime(audio.duration))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
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
                        .foregroundColor(audio.isLooping ? .amber : .white.opacity(0.6))
                }
                
                // Backward 5s
                Button {
                    audio.skipBackward()
                } label: {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                
                // Play / Pause
                Button {
                    audio.togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 54, height: 54)
                        
                        if audio.isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.black)
                        }
                    }
                }
                
                // Forward 5s
                Button {
                    audio.skipForward()
                } label: {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
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
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .foregroundColor(.white)
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
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
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

// MARK: - Custom Colors Ext
extension Color {
    static let amber = Color(hex: "FFC107")
}
