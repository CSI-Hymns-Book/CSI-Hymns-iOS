import SwiftUI

/// Fast rotary number dialer for Apple Watch allowing users to roll to a song number via Digital Crown.
public struct WatchNumberDialView: View {
    @StateObject private var dataLoader = WatchDataLoader.shared
    @State private var songType: String = "hymn" // hymn, keerthane, mt
    @State private var selectedNumber: Double = 1.0
    @State private var navigateToSong: Hymn? = nil
    
    private var maxNumber: Double {
        switch songType {
        case "keerthane": return 250.0
        case "mt": return 350.0
        default: return 500.0
        }
    }
    
    private var currentSong: Hymn? {
        dataLoader.song(type: songType, number: Int(selectedNumber))
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Type Selector
            HStack(spacing: 4) {
                Button {
                    songType = "hymn"
                    if selectedNumber > 500 { selectedNumber = 500 }
                } label: {
                    Text("Hymn")
                        .font(.system(size: 11, weight: songType == "hymn" ? .bold : .regular))
                        .frame(maxWidth: .infinity)
                }
                .tint(songType == "hymn" ? .accentColor : .gray.opacity(0.3))
                
                Button {
                    songType = "keerthane"
                    if selectedNumber > 250 { selectedNumber = 250 }
                } label: {
                    Text("Keer")
                        .font(.system(size: 11, weight: songType == "keerthane" ? .bold : .regular))
                        .frame(maxWidth: .infinity)
                }
                .tint(songType == "keerthane" ? .accentColor : .gray.opacity(0.3))
                
                Button {
                    songType = "mt"
                    if selectedNumber > 350 { selectedNumber = 350 }
                } label: {
                    Text("M.T.")
                        .font(.system(size: 11, weight: songType == "mt" ? .bold : .regular))
                        .frame(maxWidth: .infinity)
                }
                .tint(songType == "mt" ? .accentColor : .gray.opacity(0.3))
            }
            
            // Large Crown-Interactive Number
            VStack(spacing: 2) {
                Text("#\(Int(selectedNumber))")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .focusable()
                    .digitalCrownRotation(
                        $selectedNumber,
                        from: 1.0,
                        through: maxNumber,
                        by: 1.0,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
                
                if let song = currentSong {
                    Text(song.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                } else {
                    Text("Rotate Crown to change")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
            
            // Step buttons (-5, -1, +1, +5)
            HStack(spacing: 6) {
                Button("-10") {
                    selectedNumber = max(1.0, selectedNumber - 10)
                }
                .buttonStyle(.bordered)
                .font(.system(size: 11, weight: .bold))
                
                Button("-1") {
                    selectedNumber = max(1.0, selectedNumber - 1)
                }
                .buttonStyle(.bordered)
                .font(.system(size: 11, weight: .bold))
                
                Button("+1") {
                    selectedNumber = min(maxNumber, selectedNumber + 1)
                }
                .buttonStyle(.bordered)
                .font(.system(size: 11, weight: .bold))
                
                Button("+10") {
                    selectedNumber = min(maxNumber, selectedNumber + 10)
                }
                .buttonStyle(.bordered)
                .font(.system(size: 11, weight: .bold))
            }
            
            // Jump to song button
            if let song = currentSong {
                NavigationLink(destination: WatchHymnReaderView(hymn: song)) {
                    Text("Open #\(Int(selectedNumber))")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .tint(.accentColor)
            } else {
                Text("Song not found")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .navigationTitle("Quick Dial")
        .navigationBarTitleDisplayMode(.inline)
    }
}
