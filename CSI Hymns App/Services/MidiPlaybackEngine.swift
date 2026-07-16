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
    
    public var currentTime: Double = 0
    public var duration: Double = 0
    public var isLooping: Bool = false
    public var playbackRate: Float = 1.0 {
        didSet { sequencer.rate = playbackRate }
    }
    
    public var transpose: Int = 0 {
        didSet { updateTransposition() }
    }
    
    // 0: Soprano, 1: Alto, 2: Tenor, 3: Bass
    public var satbInstruments: [UInt8] = [19, 19, 19, 19] {
        didSet { applyAllInstruments() }
    }
    
    public var isAdvancedMode: Bool = false {
        didSet { applyAllInstruments() }
    }
    
    private let engine = AVAudioEngine()
    private var samplers: [AVAudioUnitSampler] = []
    
    @ObservationIgnored private var sequencer: AVAudioSequencer!
    private var timer: Timer?
    
    private override init() {
        super.init()
        self.sequencer = AVAudioSequencer(audioEngine: self.engine)
        setupEngine()
    }
    
    private func setupEngine() {
        // Create 4 samplers for SATB
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
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("TimGM6mb.sf2")
    }
    
    private func downloadSoundfontIfNeeded() async -> Bool {
        let dest = soundfontURL
        if FileManager.default.fileExists(atPath: dest.path) {
            return true
        }
        
        guard let url = URL(string: "https://raw.githubusercontent.com/craffel/pretty-midi/main/pretty_midi/TimGM6mb.sf2") else {
            return false
        }
        
        do {
            print("MidiPlaybackEngine: Downloading SoundFont (6MB)...")
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            try data.write(to: dest)
            print("MidiPlaybackEngine: SoundFont downloaded successfully!")
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
                try sampler.loadSoundBankInstrument(at: dest, program: programId, bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: UInt8(kAUSampler_DefaultBankLSB))
                print("MidiPlaybackEngine: Successfully loaded program \(programId) from SoundFont")
            } else {
                print("MidiPlaybackEngine: SoundFont not found locally. Playing default.")
                sampler.sendProgramChange(programId, onChannel: 0)
            }
        } catch {
            print("MidiPlaybackEngine: Error loading instrument \(programId): \(error). Playing default.")
            sampler.sendProgramChange(programId, onChannel: 0)
        }
    }
    
    public func applyAllInstruments() {
        let presetId = UserDefaults.standard.integer(forKey: "midiInstrumentId")
        let globalProgram: UInt8
        switch presetId {
        case 1: globalProgram = 0  // Grand Piano
        case 2: globalProgram = 19 // Pipe Organ
        case 3: globalProgram = 52 // Choir Aahs
        case 19: globalProgram = 19 // Pipe Organ (Settings tag)
        case 20: globalProgram = 20 // Reed Organ (Settings tag)
        case 52: globalProgram = 52 // Choir Aahs (Settings tag)
        default: globalProgram = 20 // Default (Advanced tag 0 or unset) -> Reed Organ
        }
        
        print("MidiPlaybackEngine: applyAllInstruments - presetId: \(presetId), globalProgram: \(globalProgram), isAdvancedMode: \(isAdvancedMode)")
        
        for (i, sampler) in samplers.enumerated() {
            let program = isAdvancedMode ? satbInstruments[i] : globalProgram
            print("MidiPlaybackEngine: Loading program \(program) into sampler \(i)")
            loadInstrument(for: sampler, programId: program)
        }
    }
    
    public func updateGlobalInstrument(to presetId: Int) {
        UserDefaults.standard.set(presetId, forKey: "midiInstrumentId")
        applyAllInstruments()
    }
    
    public func loadAndPlay(urlString: String) async {
        await MainActor.run {
            self.isLoading = true
            self.isPlaying = false
            self.currentTime = 0
            self.duration = 0
        }
        
        let sfReady = await downloadSoundfontIfNeeded()
        guard sfReady else {
            print("MidiPlaybackEngine: SoundFont not loaded, aborting play.")
            await MainActor.run { self.isLoading = false }
            return
        }
        
        guard let url = URL(string: urlString) else {
            await MainActor.run { self.isLoading = false }
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { self.isLoading = false }
                return
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".mid")
            try data.write(to: tempFile)
            
            try sequencer.load(from: tempFile, options: .smf_ChannelsToTracks)
            
            // Map tracks to our 4 samplers (skipping track 0 which is usually tempo/meta)
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
            
            try sequencer.start()
            sequencer.rate = playbackRate
            
            // Apply instruments after starting to override any embedded Program Change events at Beat 0
            applyAllInstruments()
            
            await MainActor.run {
                self.duration = maxLen
                self.isPlaying = true
                self.isLoading = false
            }
        } catch {
            print("MidiPlaybackEngine: Failed to play midi: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
    
    public func togglePlayback() {
        if isPlaying {
            sequencer.stop()
            isPlaying = false
        } else {
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
    }
    
    public func stop() {
        sequencer.stop()
        sequencer.currentPositionInBeats = 0
        isPlaying = false
        currentTime = 0
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
