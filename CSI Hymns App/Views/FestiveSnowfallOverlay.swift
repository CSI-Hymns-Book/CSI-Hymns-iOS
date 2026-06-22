import SwiftUI

/// Physics seed for a single snowflake — positions are computed deterministically per frame.
private struct SnowflakeSeed: Sendable {
    let startX: Double
    let startY: Double
    let size: Double
    let speed: Double
    let drift: Double
    let opacity: Double
    let phase: Double
}

/// Dynamic canvas driver painting falling snowflakes (decorative only).
struct SnowflakeCanvasView: View {
    private let seeds: [SnowflakeSeed]
    
    init(particleCount: Int = 60) {
        seeds = (0..<max(1, particleCount)).map { _ in
            SnowflakeSeed(
                startX: Double.random(in: 0...1),
                startY: Double.random(in: 0...1),
                size: Double.random(in: 2...5),
                speed: Double.random(in: 0.15...0.45),
                drift: Double.random(in: 0.002...0.006),
                opacity: Double.random(in: 0.3...0.8),
                phase: Double.random(in: 0...(Double.pi * 2))
            )
        }
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                for (idx, seed) in seeds.enumerated() {
                    var yPos = seed.startY + (seed.speed * time * 0.005)
                    yPos = yPos.truncatingRemainder(dividingBy: 1.0)
                    if yPos < 0 { yPos += 1.0 }
                    
                    let xOsc = sin(time + seed.phase + Double(idx)) * seed.drift
                    var xPos = seed.startX + xOsc
                    if xPos > 1.0 { xPos -= 1.0 }
                    if xPos < 0.0 { xPos += 1.0 }
                    
                    let drawX = xPos * size.width
                    let drawY = yPos * size.height
                    
                    var path = Path()
                    path.addEllipse(in: CGRect(
                        x: drawX,
                        y: drawY,
                        width: seed.size,
                        height: seed.size
                    ))
                    
                    context.opacity = seed.opacity
                    context.fill(path, with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Decorative snowfall + festive emoji — never intercepts touches.
struct FestiveSnowfallOverlay: View {
    var body: some View {
        ZStack {
            SnowflakeCanvasView(particleCount: 56)
                .opacity(0.85)
            FestiveEmojiDriftOverlay()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Occasional drifting festive emoji (easter-egg ambience).
private struct FestiveEmojiDriftOverlay: View {
    private struct DriftSeed: Identifiable {
        let id = UUID()
        let x: Double
        let emoji: String
        let speed: Double
        let phase: Double
    }
    
    private let seeds: [DriftSeed]
    
    init() {
        let emojis = ["❄️", "⭐", "🎄", "✨", "🕊️", "🔔"]
        seeds = (0..<14).map { i in
            DriftSeed(
                x: Double.random(in: 0.05...0.95),
                emoji: emojis[i % emojis.count],
                speed: Double.random(in: 0.06...0.14),
                phase: Double.random(in: 0...(Double.pi * 2))
            )
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(Array(seeds.enumerated()), id: \.element.id) { idx, seed in
                        let y = (seed.phase + t * seed.speed).truncatingRemainder(dividingBy: 1.15)
                        let x = seed.x + sin(t * 0.35 + Double(idx)) * 0.025
                        Text(seed.emoji)
                            .font(.system(size: 13))
                            .opacity(0.45)
                            .position(
                                x: x * geo.size.width,
                                y: y * geo.size.height
                            )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
