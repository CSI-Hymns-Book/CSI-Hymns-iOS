import SwiftUI

/// One carol on the reader: church, a gold number chip, a centred serif title, the scale, then the
/// lyrics verse by verse with room between verses. Everything is centred and scales with the
/// reader's text-size slider and the phone's Dynamic Type setting.
struct CarolLyricsPage: View {
    let song: CarolSong
    let churchName: String
    let scale: Double
    @Binding var language: String
    @Environment(\.festivePalette) private var palette
    @ScaledMetric(relativeTo: .body) private var baseSize = 20.0

    var body: some View {
        let parts = CarolBilingual.split(song.lyrics)
        let text = language == "English" ? (parts.english ?? parts.kannada) : parts.kannada
        let size = baseSize * scale
        ScrollView {
            VStack(spacing: 0) {
                header
                if parts.english != nil {
                    Picker("Language", selection: $language) {
                        Text("ಕನ್ನಡ").tag("Kannada"); Text("English").tag("English")
                    }
                    .pickerStyle(.segmented).frame(maxWidth: 240).padding(.top, 20)
                }
                VStack(spacing: size * 1.15) {
                    ForEach(Array(splitStanzas(text).enumerated()), id: \.offset) { _, verse in
                        Text(verse)
                            .font(.system(size: size))
                            .lineSpacing(size * 0.42)
                            .foregroundStyle(palette.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 26)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 56)      // clear of the previous and next arrows
            .padding(.top, 14).padding(.bottom, 110)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            if !churchName.isEmpty {
                Text(churchName.uppercased())
                    .font(.system(size: 11, weight: .bold)).tracking(1.4).foregroundStyle(palette.gold)
                    .multilineTextAlignment(.center)
            }
            if let number = song.songNumber, !number.isEmpty {
                Text("No. \(number)")
                    .font(.system(size: 14, weight: .heavy)).foregroundStyle(palette.gold)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(Capsule().fill(palette.gold.opacity(0.16)))
                    .overlay(Capsule().strokeBorder(palette.gold.opacity(0.55), lineWidth: 1))
                    .accessibilityLabel("Song number \(number)")
            }
            Text(song.title)
                .font(.festiveSerif(30, weight: .semibold)).foregroundStyle(palette.ink)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !song.scale.isEmpty {
                Text("Scale · \(song.scale)")
                    .font(.system(size: 13)).foregroundStyle(palette.inkMuted)
            }
            Capsule().fill(palette.gold.opacity(0.5)).frame(width: 44, height: 2).padding(.top, 6)
        }
    }
}

/// The "Aa" popover: a real slider for the lyric size, a live preview line and a reset.
struct CarolTextSizeControl: View {
    let store: CarolReaderStore
    @Environment(\.festivePalette) private var palette
    @ScaledMetric(relativeTo: .body) private var baseSize = 20.0

    private var scale: Binding<Double> {
        Binding(get: { store.textScale }, set: { store.setTextScale($0) })
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Text size").font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.ink)
                Spacer()
                Text("\(Int((store.textScale * 100).rounded()))%")
                    .font(.system(size: 14, weight: .medium).monospacedDigit()).foregroundStyle(palette.inkMuted)
            }
            HStack(spacing: 12) {
                Text("A").font(.system(size: 14, weight: .semibold)).foregroundStyle(palette.inkMuted)
                Slider(value: scale, in: CarolTextScale.min...CarolTextScale.max, step: 0.05)
                    .tint(palette.gold)
                    .accessibilityLabel("Lyrics text size")
                    .accessibilityValue("\(Int((store.textScale * 100).rounded())) percent")
                Text("A").font(.system(size: 26, weight: .semibold)).foregroundStyle(palette.inkMuted)
            }
            Text("ಕ್ರಿಸ್ತನು ಹುಟ್ಟಿದನು · Joy to the world")
                .font(.system(size: baseSize * store.textScale))
                .foregroundStyle(palette.ink).multilineTextAlignment(.center)
                .minimumScaleFactor(0.5).lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 64)
            Button("Reset to normal") { store.setTextScale(CarolTextScale.defaultScale) }
                .font(.system(size: 14, weight: .medium)).tint(palette.gold)
                .disabled(abs(store.textScale - CarolTextScale.defaultScale) < 0.001)
        }
        .padding(18)
        .frame(width: 320)
        .background(palette.glassHigh)
    }
}
