import SwiftUI

/// Physics state details for a single snowflake.
struct SnowflakeParticle: Identifiable, Sendable {
    let id = UUID()
    var x: Double      // Normalized x coordinate (0.0 to 1.0)
    var y: Double      // Normalized y coordinate (0.0 to 1.0)
    let size: Double
    let speed: Double
    let drift: Double
    let opacity: Double
}

/// Dynamic canvas driver painting falling snowflakes at ProMotion refresh rates (up to 120 Hz).
struct SnowflakeCanvasView: View {
    @State private var particles: [SnowflakeParticle] = []
    
    init() {}
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                if particles.isEmpty {
                    generateParticles()
                }
                
                // Advance physics coordinates and draw
                for idx in 0..<particles.count {
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    
                    // Vertical progression
                    var yPos = particles[idx].y + (particles[idx].speed * 0.005)
                    if yPos > 1.0 { yPos = 0.0 }
                    
                    // Side drift oscillations
                    let xOsc = sin(time + Double(idx)) * particles[idx].drift
                    var xPos = particles[idx].x + xOsc
                    if xPos > 1.0 { xPos = 0.0 } else if xPos < 0.0 { xPos = 1.0 }
                    
                    particles[idx].y = yPos
                    particles[idx].x = xPos
                    
                    let drawX = xPos * size.width
                    let drawY = yPos * size.height
                    
                    var path = Path()
                    path.addEllipse(in: CGRect(
                        x: drawX,
                        y: drawY,
                        width: particles[idx].size,
                        height: particles[idx].size
                    ))
                    
                    context.opacity = particles[idx].opacity
                    context.fill(path, with: .color(.white))
                }
            }
        }
    }
    
    private func generateParticles() {
        var newParticles = [SnowflakeParticle]()
        for _ in 0..<60 {
            newParticles.append(SnowflakeParticle(
                x: Double.random(in: 0...1),
                y: Double.random(in: 0...1),
                size: Double.random(in: 2...5),
                speed: Double.random(in: 0.15...0.45),
                drift: Double.random(in: 0.002...0.006),
                opacity: Double.random(in: 0.3...0.8)
            ))
        }
        self.particles = newParticles
    }
}

/// A spectacular Liquid Glass landing portal active during festive seasons.
public struct ChristmasLandingView: View {
    @State private var isShowingToast = false
    @State private var toastOffset: CGFloat = 100.0
    @State private var toastOpacity: Double = 0.0
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Dark mystical Christmas night sky
                LinearGradient(
                    colors: [Color(hex: "0D1B2A"), Color(hex: "132237"), Color(hex: "0D1B2A")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // ProMotion snowflake particle canvas
                SnowflakeCanvasView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header greetings
                        headerTitleRow
                            .padding(.top, 24)
                        
                        // Large Categories navigation cards
                        VStack(spacing: 16) {
                            NavigationLink(destination: HymnsListView(title: "Hymns", isKeerthanes: false)) {
                                CategoryGlassCard(
                                    title: "Hymns",
                                    subtitle: "Traditional hymns from the CSI hymn book",
                                    emoji: "🎵",
                                    gradients: [Color(hex: "2E7D32"), Color(hex: "1B5E20")],
                                    isHighlighted: false
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            NavigationLink(destination: HymnsListView(title: "Keerthanes", isKeerthanes: true)) {
                                CategoryGlassCard(
                                    title: "Keerthane",
                                    subtitle: "Kannada devotional songs and lyrics",
                                    emoji: "🎶",
                                    gradients: [Color(hex: "1976D2"), Color(hex: "0D47A1")],
                                    isHighlighted: false
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            NavigationLink(destination: ChristmasCarolsListView()) {
                                CategoryGlassCard(
                                    title: "Christmas Carols",
                                    subtitle: "Celebrate the season with festive songs",
                                    emoji: "🎄",
                                    gradients: [Color(hex: "C62828"), Color(hex: "8E0000")],
                                    isHighlighted: true
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Easter egg footer
                        footerButton
                            .padding(.top, 36)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal)
                }
                
                // Toast alert overlay
                if isShowingToast {
                    peaceToastOverlay
                }
            }
            .navigationTitle("Christmas Portal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerTitleRow: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "B22222").opacity(0.2))
                    .frame(width: 58, height: 58)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "B22222").opacity(0.35), lineWidth: 1))
                
                Text("🎄")
                    .font(.system(size: 28))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Merry Christmas!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Glory to God in the highest")
                    .font(.system(size: 14, weight: .medium).italic())
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Text("⭐")
                .font(.system(size: 24))
        }
    }
    
    private var footerButton: some View {
        Button {
            triggerPeaceToast()
        } label: {
            HStack(spacing: 8) {
                Text("❄️")
                Text("Peace on Earth")
                    .font(.system(size: 13, weight: .semibold).italic())
                Text("❄️")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
            .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var peaceToastOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Text("🕊️")
                    .font(.system(size: 18))
                
                Text("Goodwill to all men")
                    .font(.system(size: 14, weight: .semibold).italic())
                    .foregroundColor(.white)
                
                Text("✨")
                    .font(.system(size: 15))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(hex: "1B5E20").opacity(0.95))
                    .shadow(color: Color(hex: "2E7D32").opacity(0.5), radius: 12, x: 0, y: 0)
            )
            .offset(y: toastOffset)
            .opacity(toastOpacity)
            .padding(.bottom, 120)
        }
    }
    
    private func triggerPeaceToast() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            isShowingToast = true
            toastOffset = 0.0
            toastOpacity = 1.0
        }
        
        // Auto-dismiss in 3s
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.35)) {
                    toastOffset = 100.0
                    toastOpacity = 0.0
                }
            }
            try? await Task.sleep(for: .seconds(0.4))
            await MainActor.run {
                isShowingToast = false
            }
        }
    }
}

// MARK: - Reusable Category Card Widget
struct CategoryGlassCard: View {
    let title: String
    let subtitle: String
    let emoji: String
    let gradients: [Color]
    let isHighlighted: Bool
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 16) {
            // Emoji plate
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 52, height: 52)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.35), lineWidth: 1))
                
                Text(emoji)
                    .font(.system(size: 26))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    if isHighlighted {
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white)
                            .cornerRadius(6)
                            .foregroundColor(gradients.first ?? .green)
                    }
                }
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            Spacer()
            
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.white)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: gradients, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: (gradients.first ?? .clear).opacity(0.4), radius: isHighlighted ? 12 : 6, x: 0, y: 4)
        )
        .scaleEffect(scale)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                        scale = 0.95
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        scale = 1.0
                    }
                }
        )
    }
}
