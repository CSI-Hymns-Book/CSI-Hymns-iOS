import SwiftUI

// MARK: - Motion

/// Shared timing so every festive motion feels like one family.
enum FestiveMotion {
    /// Opening or closing a whole screen: quick, smooth, a whisper of bounce.
    static let screen = Animation.spring(duration: 0.42, bounce: 0.12)
    /// Cards popping in on first view.
    static let entrance = Animation.spring(duration: 0.55, bounce: 0.22)
}

/// Zoom-pop entrance: grows from slightly smaller with a soft settle, staggered by `index`.
/// Runs once per appearance; GPU-cheap (scale + opacity only).
private struct FestiveEntrance: ViewModifier {
    let index: Int
    let enabled: Bool
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || !enabled ? 1 : 0.92)
            .opacity(shown || !enabled ? 1 : 0)
            .onAppear {
                guard !shown, enabled else { return }
                withAnimation(FestiveMotion.entrance.delay(0.08 + 0.055 * Double(index))) { shown = true }
            }
    }
}

/// Springy press: shrinks a little while held and bounces back, with a gold edge handled by callers.
struct FestivePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? 0.03 : 0)
            .animation(.spring(duration: 0.28, bounce: 0.35), value: configuration.isPressed)
            // A tap you can feel the moment a finger lands on a card or song row.
            .onChange(of: configuration.isPressed) { _, pressed in if pressed { AppHaptics.tap() } }
    }
}

extension View {
    func festiveEntrance(_ index: Int = 0, enabled: Bool = true) -> some View {
        modifier(FestiveEntrance(index: index, enabled: enabled && FestiveAmbience.shared.level != .off))
    }

    /// Frosted glass with a thin gold edge and (optionally) a snow cap.
    func festiveGlass(cornerRadius: CGFloat, high: Bool = false, capped: Bool = true) -> some View {
        modifier(FestiveGlass(cornerRadius: cornerRadius, high: high, capped: capped))
    }

    /// Dims the falling snow while a reading screen is open so lyrics stay clear.
    func festiveDimSnow() -> some View { modifier(FestiveDimSnow()) }

    /// Night-sky backdrop, a string of twinkling lights down both side edges and a low snow drift
    /// along the very bottom: for lyric screens. Drawn in the margins only; never takes touches.
    func festiveReaderFrame() -> some View { modifier(FestiveReaderFrame()) }

}

extension AnyTransition {
    /// A screen opening on top: zooms up from slightly smaller and fades in.
    static var festiveZoom: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.94).combined(with: .opacity),
            removal: .scale(scale: 0.96).combined(with: .opacity)
        )
    }

    /// The screen underneath: stays put and only fades, so two zooms never overlap (the glitch).
    static var festiveStay: AnyTransition { .opacity }
}

private struct FestiveGlass: ViewModifier {
    @Environment(\.festivePalette) private var palette
    let cornerRadius: CGFloat
    let high: Bool
    let capped: Bool
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let base = content
            .background(shape.fill(high ? palette.glassHigh : palette.glass))
            .overlay(shape.strokeBorder(palette.edge, lineWidth: 1))
        if capped { base.snowCap(cornerRadius: cornerRadius) } else { base }
    }
}

private struct FestiveDimSnow: ViewModifier {
    @State private var release: (() -> Void)?
    func body(content: Content) -> some View {
        content
            .onAppear { release = FestiveAmbience.shared.requestDim() }
            .onDisappear { release?(); release = nil }
    }
}

private struct FestiveReaderFrame: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let palette = FestivePalette.forScheme(scheme)
        ZStack {
            LinearGradient(colors: palette.screenGradient, startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            content
            FestiveEdgeDecor(palette: palette).ignoresSafeArea().allowsHitTesting(false)
        }
        .environment(\.festivePalette, palette)
    }
}

private struct FestiveEdgeDecor: View {
    let palette: FestivePalette
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: FestiveAmbience.shared.level == .off)) { timeline in
            Canvas { ctx, size in
                let phase = FestiveAmbience.shared.level == .off ? 0.5 : timeline.date.timeIntervalSinceReferenceDate / 3.6
                let colors = [palette.gold, palette.holly, palette.pine, palette.ice]
                let spacing = 30.0, top = 28.0, bottom = size.height - 30
                guard bottom > top else { return }
                for x in [5.0, size.width - 5.0] {
                    var wire = Path(); wire.move(to: CGPoint(x: x, y: top)); wire.addLine(to: CGPoint(x: x, y: bottom))
                    ctx.stroke(wire, with: .color(palette.gold.opacity(0.16)), lineWidth: 0.8)
                    var i = 0
                    var y = top
                    while y <= bottom {
                        let glow = 0.35 + 0.45 * (0.5 + 0.5 * sin(2 * .pi * (phase + Double(i) * 0.137)))
                        let color = colors[i % colors.count]
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 5.5, y: y - 5.5, width: 11, height: 11)), with: .color(color.opacity(glow * 0.22)))
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 2.1, y: y - 2.1, width: 4.2, height: 4.2)), with: .color(color.opacity(glow)))
                        y += spacing; i += 1
                    }
                }
                var drift = Path()
                drift.move(to: CGPoint(x: 0, y: size.height))
                drift.addLine(to: CGPoint(x: 0, y: size.height - 3.5))
                var x = 0.0
                while x < size.width {
                    let next = min(size.width, x + 46)
                    drift.addQuadCurve(to: CGPoint(x: next, y: size.height - 3.5), control: CGPoint(x: (x + next) / 2, y: size.height - 10.5))
                    x = next
                }
                drift.addLine(to: CGPoint(x: size.width, y: size.height)); drift.closeSubpath()
                ctx.fill(drift, with: .color(Color.white.opacity(palette.isNight ? 0.5 : 0.8)))
            }
        }
    }
}

// MARK: - Toast

struct FestiveToastHost: View {
    private let ambience = FestiveAmbience.shared
    var body: some View {
        VStack {
            Spacer()
            if let toast = ambience.toast {
                Text(toast.text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "F5EFE4"))
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Capsule().fill(Color(hex: "1B2A4A").opacity(0.96)))
                    .overlay(Capsule().strokeBorder(Color(hex: "E9C27B").opacity(0.4), lineWidth: 1))
                    .padding(.bottom, 104)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(2.4))
                        ambience.dismissToast(id: toast.id)
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: ambience.toast)
        .allowsHitTesting(false)
    }
}

// MARK: - Secrets chip and dialog

struct FestiveSecretsChip: View {
    let found: Set<FestiveSecret>
    let onTap: () -> Void
    @Environment(\.festivePalette) private var palette
    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            HStack(spacing: 8) {
                Text("✨").font(.system(size: 14))
                Text("Tap, tilt & shake · \(found.count) of \(FestiveSecret.allCases.count) secrets")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(palette.ink)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Capsule().fill(palette.glassHigh))
            .overlay(Capsule().strokeBorder(palette.edge, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hidden Christmas secrets, \(found.count) of \(FestiveSecret.allCases.count) found")
    }
}

struct FestiveSecretsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.festivePalette) private var palette
    private let ambience = FestiveAmbience.shared
    @State private var confirmReset = false

    var body: some View {
        let found = ambience.foundSecrets
        NavigationStack {
            List {
                Section {
                    Text("Christmas changes how the whole app looks and feels. Tap things, press and hold, tilt and shake your phone, and watch the sky.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Section {
                    ForEach(FestiveSecret.allCases, id: \.self) { secret in
                        let isFound = found.contains(secret)
                        HStack(alignment: .top, spacing: 10) {
                            Text(isFound ? "★" : "☆").foregroundStyle(palette.gold)
                            Text(isFound ? secret.hint : "Still hidden…")
                                .foregroundStyle(isFound ? Color.primary : Color.secondary)
                        }
                    }
                }
                if !found.isEmpty {
                    Section {
                        Button("Reset secrets", role: .destructive) { confirmReset = true }
                    }
                }
            }
            .navigationTitle("Secrets in this season")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Got it") { dismiss() } } }
            .alert("Reset all secrets?", isPresented: $confirmReset) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { ambience.resetSecrets(); dismiss() }
            } message: {
                Text("You'll forget the \(found.count) secret\(found.count == 1 ? "" : "s") you found and can discover them all again.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Back to the partner app

/// "Back to <partner app>" — only shown when an allowlisted partner opened Carols.
struct ReturnToCallerChip: View {
    private let handoff = CarolHandoff.shared
    @Environment(\.festivePalette) private var palette

    var body: some View {
        if let caller = handoff.caller {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                handoff.returnToCaller()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left").font(.system(size: 12, weight: .bold)).foregroundStyle(palette.gold)
                    Text("Back to \(caller.label)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                }
                .padding(.leading, 12).padding(.trailing, 14).padding(.vertical, 8)
                .background(Capsule().fill(palette.glassHigh))
                .overlay(Capsule().strokeBorder(palette.edge, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Go back to \(caller.label)")
        }
    }
}

// MARK: - Song rows

/// One song in a Christmas list: tinted badge, gold label, serif title, optional subtitle and a
/// trailing slot, on glass with a snow cap.
struct FestiveSongRow<Badge: View, Trailing: View>: View {
    let label: String
    let title: String
    var subtitle: String?
    var badgeBackground: Color
    @ViewBuilder var badge: () -> Badge
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.festivePalette) private var palette

    var body: some View {
        HStack(spacing: 14) {
            badge()
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(badgeBackground))
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 10.5, weight: .bold)).tracking(1.2)
                    .foregroundStyle(palette.gold)
                Text(title)
                    .font(.festiveSerif(18))
                    .foregroundStyle(palette.ink)
                    .lineLimit(2).multilineTextAlignment(.leading)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 12.5)).foregroundStyle(palette.inkMuted).lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            trailing()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .festiveGlass(cornerRadius: 22)
        .padding(.vertical, 7)
    }
}
