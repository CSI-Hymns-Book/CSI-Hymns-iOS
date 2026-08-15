import Foundation
import AVFoundation
import SwiftUI

@Observable
public final class MidiPlaybackEngine: NSObject, Sendable {
    public static let shared = MidiPlaybackEngine()
    
    public private(set) var isPlaying = false {
        didSet {
            if isPlaying { startTimer() } else { stopTimer() }
        }
    }
    public private(set) var isLoading = false
    public private(set) var lastError: String?
    public private(set) var currentURL: String?
    
    public var currentTime: Double = 0
    public var duration: Double = 0
    public var isLooping: Bool = false
    public var playbackRate: Float = 1.0 {
        didSet {
            // Tempo is patched into MIDI bytes; keep sequencer rate at 1.0 after re-patch.
            scheduleReapply()
        }
    }
    
    public var transpose: Int = 0 {
        didSet {
            updateTransposition()
            scheduleReapply()
        }
    }
    
    // 0: Soprano, 1: Alto, 2: Tenor, 3: Bass
    public var satbInstruments: [UInt8] = {
        let d = UInt8(clamping: MidiInstruments.currentProgramId)
        return [d, d, d, d]
    }() {
        didSet {
            applyAllInstruments()
            scheduleReapply()
        }
    }
    
    /// Per-part mute toggles (Android SATB mute parity).
    public var satbMuted: [Bool] = [false, false, false, false] {
        didSet {
            applyMuteStates()
            scheduleReapply()
        }
    }
    
    public var isAdvancedMode: Bool = UserDefaults.standard.bool(forKey: "is_satb_routing_enabled") {
        didSet {
            UserDefaults.standard.set(isAdvancedMode, forKey: "is_satb_routing_enabled")
            applyAllInstruments()
            scheduleReapply()
        }
    }
    
    private let engine = AVAudioEngine()
    private var samplers: [AVAudioUnitSampler] = []
    
    @ObservationIgnored private var sequencer: AVAudioSequencer!
    private var timer: Timer?
    private var loadTask: Task<Void, Never>?
    private var rawMidiCache: Data?
    private var isReloadingPatched = false
    
    private override init() {
        super.init()
        self.sequencer = AVAudioSequencer(audioEngine: self.engine)
        setupEngine()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    private func setupEngine() {
        for _ in 0..<4 {
            let sampler = AVAudioUnitSampler()
            samplers.append(sampler)
            engine.attach(sampler)
            engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        }
        
        do {
            try engine.start()
            sequencer.stop()
        } catch {
            print("MidiPlaybackEngine: Failed to start engine: \(error)")
        }
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue),
              type == .began else { return }
        pausePlayback()
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentTime = self.sequencer.currentPositionInSeconds
                if self.duration > 0 && self.currentTime >= self.duration - 0.1 {
                    if self.isLooping {
                        self.sequencer.currentPositionInSeconds = 0
                        self.currentTime = 0
                        do { try self.sequencer.start() } catch {}
                    } else {
                        self.stop()
                    }
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTransposition() {
        for sampler in samplers {
            sampler.globalTuning = Float(transpose * 100)
        }
    }
    
    private var soundfontURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TimGM6mb.sf2")
    }
    
    private func downloadSoundfontIfNeeded() async -> Bool {
        let dest = soundfontURL
        if FileManager.default.fileExists(atPath: dest.path) { return true }
        
        guard let url = URL(string: "https://raw.githubusercontent.com/craffel/pretty-midi/main/pretty_midi/TimGM6mb.sf2") else {
            return false
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            try data.write(to: dest)
            return true
        } catch {
            print("MidiPlaybackEngine: Failed to download SoundFont: \(error)")
            return false
        }
    }
    
    private func loadInstrument(for sampler: AVAudioUnitSampler, programId: UInt8) {
        let dest = soundfontURL
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try sampler.loadSoundBankInstrument(
                    at: dest,
                    program: programId,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: UInt8(kAUSampler_DefaultBankLSB)
                )
            } else {
                sampler.sendProgramChange(programId, onChannel: 0)
            }
        } catch {
            sampler.sendProgramChange(programId, onChannel: 0)
        }
    }
    
    public func applyAllInstruments() {
        let globalProgram = UInt8(clamping: MidiInstruments.currentProgramId)
        for (i, sampler) in samplers.enumerated() {
            let program = isAdvancedMode ? satbInstruments[i] : globalProgram
            loadInstrument(for: sampler, programId: program)
        }
        applyMuteStates()
    }
    
    public func applyMuteStates() {
        for (i, sampler) in samplers.enumerated() {
            let muted = i < satbMuted.count ? satbMuted[i] : false
            sampler.volume = muted ? 0.0 : 1.0
        }
    }
    
    public func updateGlobalInstrument(to programId: Int) {
        UserDefaults.standard.set(programId, forKey: MidiInstruments.storageKey)
        // Keep SATB defaults aligned with global when not customized mid-session.
        if !isAdvancedMode {
            let program = UInt8(clamping: programId)
            satbInstruments = [program, program, program, program]
        }
        applyAllInstruments()
    }
    
    /// Reset vocal instruments to the user default (Android new-song behavior).
    public func resetPartsToUserDefault() {
        isReloadingPatched = true
        let program = UInt8(clamping: MidiInstruments.currentProgramId)
        satbInstruments = [program, program, program, program]
        satbMuted = [false, false, false, false]
        transpose = 0
        isReloadingPatched = false
    }
    
    private func scheduleReapply() {
        guard !isReloadingPatched, rawMidiCache != nil else { return }
        Task { await reapplyPatchedMidi(preservePosition: true) }
    }
    
    public func loadAndPlay(urlString: String) async throws {
        loadTask?.cancel()
        
        await MainActor.run {
            self.isLoading = true
            self.isPlaying = false
            self.currentTime = 0
            self.duration = 0
            self.lastError = nil
            self.currentURL = urlString
            self.resetPartsToUserDefault()
        }
        
        let sfReady = await downloadSoundfontIfNeeded()
        guard sfReady else {
            await MainActor.run {
                self.isLoading = false
                self.lastError = "SoundFont failed to load."
            }
            throw MidiDownloadError.decode
        }
        
        do {
            let data = try await MidiDownloader.download(urlString: urlString)
            try Task.checkCancellation()
            rawMidiCache = data
            
            let position: Double = 0
            try await loadPatchedBytes(data, resumeAt: position, shouldPlay: true)
            
            await MainActor.run {
                self.isLoading = false
                self.lastError = nil
            }
        } catch is CancellationError {
            await MainActor.run { self.isLoading = false }
            throw CancellationError()
        } catch let error as MidiDownloadError {
            await MainActor.run {
                self.isLoading = false
                self.isPlaying = false
                self.lastError = error.localizedDescription
            }
            throw error
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.isPlaying = false
                self.lastError = error.localizedDescription
            }
            throw MidiDownloadError.unknown(error.localizedDescription)
        }
    }
    
    private func patchedData(from raw: Data) -> Data {
        MidiBytePatcher.patch(
            midiBytes: raw,
            instrumentProgram: MidiInstruments.currentProgramId,
            transposeSemitones: transpose,
            satbMuted: satbMuted,
            satbInstruments: satbInstruments.map(Int.init),
            isSatbRoutingEnabled: isAdvancedMode,
            speed: playbackRate
        )
    }
    
    private func loadPatchedBytes(_ raw: Data, resumeAt: Double, shouldPlay: Bool) async throws {
        let patched = patchedData(from: raw)
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mid")
        try patched.write(to: tempFile)
        
        sequencer.stop()
        try sequencer.load(from: tempFile, options: .smf_ChannelsToTracks)
        
        var samplerIndex = 0
        for track in sequencer.tracks {
            if track.lengthInSeconds > 0 && samplerIndex < samplers.count {
                track.destinationAudioUnit = samplers[samplerIndex]
                samplerIndex += 1
            }
        }
        
        sequencer.prepareToPlay()
        updateTransposition()
        
        var maxLen: Double = 0
        for track in sequencer.tracks {
            if track.lengthInSeconds > maxLen { maxLen = track.lengthInSeconds }
        }
        
        if !engine.isRunning { try engine.start() }
        sequencer.currentPositionInSeconds = max(0, min(resumeAt, maxLen))
        // Speed already baked into tempo meta events.
        sequencer.rate = 1.0
        applyAllInstruments()
        
        if shouldPlay {
            try sequencer.start()
        }
        
        await MainActor.run {
            self.duration = maxLen
            self.currentTime = sequencer.currentPositionInSeconds
            self.isPlaying = shouldPlay
        }
    }
    
    /// Re-patch cached MIDI after instrument / mute / transpose / speed changes (Android realtime parity).
    private func reapplyPatchedMidi(preservePosition: Bool) async {
        guard let raw = rawMidiCache, !isLoading else { return }
        isReloadingPatched = true
        defer { isReloadingPatched = false }
        
        let position = preservePosition ? currentTime : 0
        let wasPlaying = isPlaying
        do {
            try await loadPatchedBytes(raw, resumeAt: position, shouldPlay: wasPlaying)
        } catch {
            print("MidiPlaybackEngine: reapply patch failed: \(error)")
        }
    }
    
    public func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            resumePlayback()
        }
    }
    
    public func pausePlayback() {
        sequencer.stop()
        isPlaying = false
    }
    
    public func resumePlayback() {
        do {
            if !engine.isRunning { try engine.start() }
            if currentTime >= duration {
                sequencer.currentPositionInSeconds = 0
            }
            try sequencer.start()
            applyAllInstruments()
            isPlaying = true
        } catch {
            print("MidiPlaybackEngine: Failed to resume: \(error)")
        }
    }
    
    public func stop() {
        loadTask?.cancel()
        sequencer.stop()
        sequencer.currentPositionInBeats = 0
        isPlaying = false
        currentTime = 0
        rawMidiCache = nil
    }
    
    public func seek(to time: Double) {
        let clamped = max(0, min(time, duration))
        let wasPlaying = isPlaying
        if wasPlaying { sequencer.stop() }
        sequencer.currentPositionInSeconds = clamped
        currentTime = clamped
        if wasPlaying {
            do {
                try sequencer.start()
                applyAllInstruments()
            } catch {}
        }
    }
    
    public func skipForward() { seek(to: currentTime + 5) }
    public func skipBackward() { seek(to: currentTime - 5) }
}
