import Foundation

/// Patches MIDI SMF bytes for instrument, SATB mute, transpose, and tempo (Android `AudioViewModel.patchMidiInstrument`).
enum MidiBytePatcher {
    static func patch(
        midiBytes: Data,
        instrumentProgram: Int,
        transposeSemitones: Int,
        satbMuted: [Bool],
        satbInstruments: [Int],
        isSatbRoutingEnabled: Bool,
        speed: Float
    ) -> Data {
        guard midiBytes.count >= 14 else { return midiBytes }
        var result = [UInt8](midiBytes)
        
        // Verify MThd
        guard result[0] == 0x4D, result[1] == 0x54, result[2] == 0x68, result[3] == 0x64 else {
            return midiBytes
        }
        
        var i = 14
        let length = result.count
        
        while i < length - 8 {
            let c0 = result[i]
            let c1 = result[i + 1]
            let c2 = result[i + 2]
            let c3 = result[i + 3]
            
            let chunkLen = (Int(result[i + 4]) << 24)
                | (Int(result[i + 5]) << 16)
                | (Int(result[i + 6]) << 8)
                | Int(result[i + 7])
            
            i += 8
            if c0 == 0x4D, c1 == 0x54, c2 == 0x72, c3 == 0x6B { // MTrk
                let trackEnd = min(i + chunkLen, length)
                var trackPtr = i
                var runningStatus = 0
                
                while trackPtr < trackEnd {
                    // Delta time VLQ
                    var byte = Int(result[trackPtr])
                    trackPtr += 1
                    while byte & 0x80 != 0 {
                        if trackPtr >= trackEnd { break }
                        byte = Int(result[trackPtr])
                        trackPtr += 1
                    }
                    if trackPtr >= trackEnd { break }
                    
                    var status = Int(result[trackPtr])
                    if status & 0x80 != 0 {
                        trackPtr += 1
                        runningStatus = status
                    } else {
                        status = runningStatus
                    }
                    
                    let statusType = status & 0xF0
                    let channel = status & 0x0F
                    
                    if status == 0xFF {
                        // Meta event
                        if trackPtr >= trackEnd { break }
                        let metaType = Int(result[trackPtr])
                        trackPtr += 1
                        
                        var metaLen = 0
                        if trackPtr < trackEnd {
                            var lenByte = Int(result[trackPtr])
                            trackPtr += 1
                            metaLen = lenByte & 0x7F
                            while lenByte & 0x80 != 0, trackPtr < trackEnd {
                                lenByte = Int(result[trackPtr])
                                trackPtr += 1
                                metaLen = (metaLen << 7) | (lenByte & 0x7F)
                            }
                        }
                        
                        // Tempo meta (0x51, 3 bytes) — scale by speed
                        if metaType == 0x51, metaLen == 3, trackPtr + 2 < trackEnd, speed != 1.0, speed > 0 {
                            let oldTempo = (Int(result[trackPtr]) << 16)
                                | (Int(result[trackPtr + 1]) << 8)
                                | Int(result[trackPtr + 2])
                            let newTempo = max(10_000, min(10_000_000, Int(Float(oldTempo) / speed)))
                            result[trackPtr] = UInt8((newTempo >> 16) & 0xFF)
                            result[trackPtr + 1] = UInt8((newTempo >> 8) & 0xFF)
                            result[trackPtr + 2] = UInt8(newTempo & 0xFF)
                        }
                        trackPtr += metaLen
                    } else if statusType == 0xF0 {
                        // SysEx
                        var sysexLen = 0
                        if trackPtr < trackEnd {
                            var lenByte = Int(result[trackPtr])
                            trackPtr += 1
                            sysexLen = lenByte & 0x7F
                            while lenByte & 0x80 != 0, trackPtr < trackEnd {
                                lenByte = Int(result[trackPtr])
                                trackPtr += 1
                                sysexLen = (sysexLen << 7) | (lenByte & 0x7F)
                            }
                        }
                        trackPtr += sysexLen
                    } else {
                        switch statusType {
                        case 0x90: // Note On
                            if trackPtr + 1 < trackEnd {
                                let muted: Bool = {
                                    guard isSatbRoutingEnabled, channel < satbMuted.count else { return false }
                                    return satbMuted[channel]
                                }()
                                if muted {
                                    result[trackPtr + 1] = 0
                                }
                            }
                            if trackPtr < trackEnd, channel != 9 {
                                var note = Int(result[trackPtr])
                                note = max(0, min(127, note + transposeSemitones))
                                result[trackPtr] = UInt8(note)
                            }
                            trackPtr += 2
                        case 0x80, 0xA0: // Note Off / Aftertouch
                            if trackPtr < trackEnd, channel != 9 {
                                var note = Int(result[trackPtr])
                                note = max(0, min(127, note + transposeSemitones))
                                result[trackPtr] = UInt8(note)
                            }
                            trackPtr += 2
                        case 0xB0, 0xE0:
                            trackPtr += 2
                        case 0xC0: // Program Change
                            if trackPtr < trackEnd, channel != 9 {
                                let instr: Int
                                if isSatbRoutingEnabled, channel < satbInstruments.count {
                                    instr = satbInstruments[channel]
                                } else {
                                    instr = instrumentProgram
                                }
                                result[trackPtr] = UInt8(max(0, min(127, instr)))
                            }
                            trackPtr += 1
                        case 0xD0:
                            trackPtr += 1
                        default:
                            trackPtr += 1
                        }
                    }
                }
                i = trackEnd
            } else {
                i += chunkLen
            }
        }
        
        return Data(result)
    }
}
