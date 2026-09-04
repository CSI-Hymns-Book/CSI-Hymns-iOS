import Foundation

/// Shared General MIDI instrument presets (Android Settings / Hymn Detail parity).
public enum MidiInstruments {
    public static let storageKey = "midiInstrumentId"
    /// Android default: Drawbar Organ (Hammond).
    public static let defaultProgramId = 16
    
    public static let all: [(program: Int, name: String)] = [
        (0, "Acoustic Grand Piano"),
        (16, "Drawbar Organ (Hammond)"),
        (17, "Percussive Organ (Punchy)"),
        (18, "Rock Organ (Heavy)"),
        (19, "Church Organ (Pipe Organ)"),
        (48, "Orchestral Strings (Lush)"),
        (14, "Church Bells (Tubular)"),
        (52, "Choir")
    ]
    
    public static var currentProgramId: Int {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: storageKey) == nil {
            return defaultProgramId
        }
        let value = defaults.integer(forKey: storageKey)
        // Migrate legacy remapped IDs (1→piano, 2→organ, 3→choir, 20→reed)
        switch value {
        case 1: return 0
        case 2: return 19
        case 3: return 52
        case 20: return 16
        default: return value
        }
    }
    
    public static func name(for program: Int) -> String {
        all.first(where: { $0.program == program })?.name ?? "Drawbar Organ (Hammond)"
    }
}
