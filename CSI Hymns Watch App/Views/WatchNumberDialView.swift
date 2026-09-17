import SwiftUI

/// Fast rotary number dialer for Apple Watch allowing users to roll to a song number via Digital Crown.
public struct WatchNumberDialView: View {
    @ObservedObject private var dataLoader = WatchDataLoader.shared
    @State private var songType: String = "hymn" // hymn, keerthane, mt
    @State private var selectedNumber: Double = 1.0
    @FocusState private var isCrownFocused: Bool
    
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
        ScrollView {
            VStack(spacing: 10) {
                // Book Segmented Selector with clean safe spacing
                HStack(spacing: 3) {
                    typeTabButton(title: "Hymn", type: "hymn", maxNum: 500)
                    typeTabButton(title: "Keer", type: "keerthane", maxNum: 250)
                    typeTabButton(title: "M.T.", type: "mt", maxNum: 350)
                }
                .padding(3)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                .padding(.top, 2)
                
                // Digital Crown-Interactive Number Card
                VStack(spacing: 4) {
                    Text("#\(Int(selectedNumber))")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.accentColor)
                    
                    if let song = currentSong {
                        Text(song.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                    } else {
                        Text("Rotate Digital Crown")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isCrownFocused ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1.5)
                        )
                )
                .focusable()
                .focused($isCrownFocused)
                .digitalCrownRotation(
                    $selectedNumber,
                    from: 1.0,
                    through: maxNumber,
                    by: 1.0,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
                
                // Step Jump Buttons (-10, -1, +1, +10)
                HStack(spacing: 5) {
                    stepButton("-10", delta: -10)
                    stepButton("-1", delta: -1)
                    stepButton("+1", delta: 1)
                    stepButton("+10", delta: 10)
                }
                
                // Jump to song button
                if let song = currentSong {
                    NavigationLink(destination: WatchHymnReaderView(hymn: song)) {
                        HStack(spacing: 6) {
                            Image(systemName: "book.pages.fill")
                                .font(.system(size: 12))
                            Text("Open #\(Int(selectedNumber))")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .tint(.accentColor)
                    .padding(.top, 2)
                } else {
                    Text("Song #\(Int(selectedNumber)) not available")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .navigationTitle("Quick Dial")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isCrownFocused = true
        }
    }
    
    @ViewBuilder
    private func typeTabButton(title: String, type: String, maxNum: Double) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                songType = type
                if selectedNumber > maxNum { selectedNumber = maxNum }
            }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: songType == type ? .bold : .medium))
                .foregroundColor(songType == type ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(songType == type ? Color.accentColor : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func stepButton(_ label: String, delta: Double) -> some View {
        Button {
            let nextVal = selectedNumber + delta
            selectedNumber = min(max(1.0, nextVal), maxNumber)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
