import Foundation
import AVFoundation
import MediaPlayer
import Observation

/// Singleton audio engine managing background streaming, remote command events,
/// dynamic playback rates, and lockscreen now playing interfaces.
@Observable
public final class AudioService: NSObject, Sendable {
    public static let shared = AudioService()
    
    // MARK: - State Properties
    public private(set) var isPlaying = false
    public private(set) var isLoading = false
    public private(set) var currentTime: Double = 0
    public private(set) var duration: Double = 0
    public var playbackRate: Float = 1.0 {
        didSet {
            player?.rate = isPlaying ? playbackRate : 0.0
            updateNowPlaying(rate: isPlaying ? playbackRate : 0.0)
        }
    }
    public var isLooping = false
    
    // MARK: - Private Engine Parts
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var isSeeking = false
    
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    deinit {
        removeTimeObserver()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true)
        } catch {
            print("AudioService: Failed to configure AVAudioSession: \(error)")
        }
    }
    
    // MARK: - Control APIs
    
    /// Loads and buffers a stream from remote CDN.
    /// - Parameters:
    ///   - urlString: Fully qualified stream endpoint
    ///   - title: Track name for now playing labels
    ///   - subtitle: Details description
    public func loadAndPlay(urlString: String, title: String, subtitle: String) {
        guard let url = URL(string: urlString) else { return }
        
        self.isLoading = true
        self.isPlaying = false
        self.currentTime = 0
        self.duration = 0
        
        // Remove active observers
        removeTimeObserver()
        
        let playerItem = AVPlayerItem(url: url)
        
        // Watch for duration resolution
        let player = AVPlayer(playerItem: playerItem)
        self.player = player
        
        // Track progress & duration
        self.timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            guard !self.isSeeking else { return }
            self.currentTime = time.seconds
            if let duration = player.currentItem?.duration.seconds, !duration.isNaN {
                self.duration = duration
                self.updateNowPlayingProgress()
            }
        }
        
        // Notification for track completions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        self.player?.rate = playbackRate
        self.isPlaying = true
        self.isLoading = false
        
        // Set metadata on Lock Screen
        setupNowPlayingMetadata(title: title, subtitle: subtitle)
    }
    
    public func togglePlayback() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.rate = playbackRate
            isPlaying = true
        }
        updateNowPlaying(rate: isPlaying ? playbackRate : 0.0)
    }
    
    public func pause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            updateNowPlaying(rate: 0.0)
        }
    }
    
    public func skipForward() {
        seek(to: currentTime + 5.0)
    }
    
    public func skipBackward() {
        seek(to: currentTime - 5.0)
    }
    
    public func seek(to seconds: Double) {
        guard let player = player else { return }
        let clampedSeconds = max(0, min(seconds, duration))
        let targetTime = CMTime(seconds: clampedSeconds, preferredTimescale: 600)
        
        isSeeking = true
        self.currentTime = clampedSeconds
        
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isSeeking = false
                self.currentTime = clampedSeconds
                self.updateNowPlayingProgress()
            }
        }
    }
    
    @objc private func playerItemDidReachEnd() {
        guard let player = player else { return }
        if isLooping {
            seek(to: 0)
            player.rate = playbackRate
        } else {
            player.pause()
            isPlaying = false
            seek(to: 0)
            updateNowPlaying(rate: 0.0)
        }
    }
    
    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    // MARK: - Lockscreen & Remote Command setups
    
    private func setupNowPlayingMetadata(title: String, subtitle: String) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = subtitle
        info[MPMediaItemPropertyAlbumTitle] = "CSI Devotionals"
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
        info[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func updateNowPlayingProgress() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func updateNowPlaying(rate: Float) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying {
                self.togglePlayback()
                return .success
            }
            return .noActionableNowPlayingItem
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying {
                self.togglePlayback()
                return .success
            }
            return .noActionableNowPlayingItem
        }
        
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [5]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward()
            return .success
        }
        
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [5]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward()
            return .success
        }
    }
}
