import SwiftUI

// Christmas dressing for dialogs and buttons: a Santa cap perched on a dialog's corner, a snow
// trim along its top edge, a springy drop-in, and buttons that squash when pressed. All of it is
// switched on only in Christmas mode; outside it every view here behaves exactly as before.

// MARK: - Drawn pieces

/// Santa's cap: a red cone curling to one side, a white band and a pompom.
struct FestiveCap: View {
    var width: CGFloat = 64
    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 68, y: size.width / 68)
            var cone = Path()
            cone.move(to: CGPoint(x: 6, y: 37))
            cone.addCurve(to: CGPoint(x: 44, y: 8), control1: CGPoint(x: 8, y: 15), control2: CGPoint(x: 26, y: 4))
            cone.addCurve(to: CGPoint(x: 60, y: 25), control1: CGPoint(x: 54, y: 10), control2: CGPoint(x: 60, y: 16))
            cone.addCurve(to: CGPoint(x: 47, y: 27), control1: CGPoint(x: 56, y: 21), control2: CGPoint(x: 50, y: 21))
            cone.addCurve(to: CGPoint(x: 48, y: 37), control1: CGPoint(x: 45, y: 32), control2: CGPoint(x: 46, y: 36))
            cone.closeSubpath()
            ctx.fill(cone, with: .color(Color(hex: "D6342B")))
            var shade = Path()
            shade.move(to: CGPoint(x: 6, y: 37))
            shade.addCurve(to: CGPoint(x: 32, y: 8), control1: CGPoint(x: 8, y: 22), control2: CGPoint(x: 18, y: 11))
            shade.addCurve(to: CGPoint(x: 16, y: 37), control1: CGPoint(x: 22, y: 14), control2: CGPoint(x: 16, y: 24))
            shade.closeSubpath()
            ctx.fill(shade, with: .color(Color(hex: "A81F18").opacity(0.55)))
            let white = Color(hex: "F4F7FF")
            ctx.fill(Path(roundedRect: CGRect(x: 2, y: 33, width: 50, height: 12), cornerRadius: 6), with: .color(white))
            ctx.fill(Path(ellipseIn: CGRect(x: 53.5, y: 19.5, width: 13, height: 13)), with: .color(white))
        }
        .frame(width: width, height: width * 48 / 68)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A strip of snow with a few drips, repeated across the width of a dialog's top edge.
struct FestiveSnowTrim: View {
    var body: some View {
        Canvas { ctx, size in
            let scale = size.height / 18
            var tile = Path()
            tile.move(to: CGPoint(x: 0, y: 9))
            tile.addQuadCurve(to: CGPoint(x: 16, y: 8), control: CGPoint(x: 8, y: 2))
            tile.addQuadCurve(to: CGPoint(x: 32, y: 8), control: CGPoint(x: 24, y: 14))
            tile.addQuadCurve(to: CGPoint(x: 48, y: 7), control: CGPoint(x: 40, y: 2))
            tile.addQuadCurve(to: CGPoint(x: 64, y: 8), control: CGPoint(x: 56, y: 12))
            tile.addQuadCurve(to: CGPoint(x: 80, y: 8), control: CGPoint(x: 72, y: 4))
            tile.addQuadCurve(to: CGPoint(x: 90, y: 8), control: CGPoint(x: 88, y: 12))
            for (x, y) in [(90.0, 13.0), (86, 13), (84, 18), (80, 13), (60, 13), (58, 17), (55, 13), (30, 13), (27, 18), (24, 13), (0, 13)] {
                tile.addLine(to: CGPoint(x: x, y: y))
            }
            tile.closeSubpath()
            var x = 0.0
            while x * scale < size.width {
                var c = ctx
                c.translateBy(x: x * scale, y: 0)
                c.scaleBy(x: scale, y: scale)
                c.fill(tile, with: .color(Color(hex: "F1F5FF")))
                x += 90
            }
        }
        .frame(height: 18)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A red bow with two loops and two tails, worn by the main button.
struct FestiveBow: View {
    var width: CGFloat = 30
    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 40, y: size.width / 40)
            let red = Color(hex: "D6342B"), dark = Color(hex: "8E1B14")
            for side in [-1.0, 1.0] {
                var loop = Path()
                loop.move(to: CGPoint(x: 20, y: 16))
                loop.addCurve(to: CGPoint(x: 20 + side * 17, y: 13), control1: CGPoint(x: 20 + side * 8, y: 2), control2: CGPoint(x: 20 + side * 17, y: 2))
                loop.addCurve(to: CGPoint(x: 20, y: 16), control1: CGPoint(x: 20 + side * 17, y: 21), control2: CGPoint(x: 20 + side * 6, y: 19))
                ctx.fill(loop, with: .color(red))
                ctx.stroke(loop, with: .color(dark), lineWidth: 1.2)
                var tail = Path()
                tail.move(to: CGPoint(x: 20, y: 16)); tail.addLine(to: CGPoint(x: 20 + side * 8, y: 29))
                ctx.stroke(tail, with: .color(Color(hex: "B02A22")), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: 16, y: 11, width: 8, height: 8)), with: .color(Color(hex: "B02A22")))
        }
        .frame(width: width, height: width * 0.75)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A sprig of holly with two berries, worn by secondary buttons.
struct FestiveHolly: View {
    var width: CGFloat = 24
    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 32, y: size.width / 32)
            let leaf = Color(hex: "2F7D55")
            var a = Path()
            a.move(to: CGPoint(x: 4, y: 14)); a.addCurve(to: CGPoint(x: 20, y: 12), control1: CGPoint(x: 8, y: 4), control2: CGPoint(x: 18, y: 4))
            a.addCurve(to: CGPoint(x: 4, y: 14), control1: CGPoint(x: 14, y: 10), control2: CGPoint(x: 9, y: 12)); a.closeSubpath()
            var b = Path()
            b.move(to: CGPoint(x: 14, y: 18)); b.addCurve(to: CGPoint(x: 30, y: 17), control1: CGPoint(x: 18, y: 9), control2: CGPoint(x: 28, y: 9))
            b.addCurve(to: CGPoint(x: 14, y: 18), control1: CGPoint(x: 24, y: 16), control2: CGPoint(x: 19, y: 19)); b.closeSubpath()
            ctx.fill(a, with: .color(leaf)); ctx.fill(b, with: .color(leaf))
            for x in [14.0, 19.0] { ctx.fill(Path(ellipseIn: CGRect(x: x - 3, y: (x == 14 ? 17 : 19) - 3, width: 6, height: 6)), with: .color(Color(hex: "D6342B"))) }
        }
        .frame(width: width, height: width * 0.75)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Dialog decoration

/// True when dialogs and buttons should wear their Christmas dressing.
@MainActor
var festiveDialogsOn: Bool { ChristmasModeService.shared.isChristmasTime }

/// Puts a Santa cap on a dialog's top-left corner and a snow trim along its top edge. The cap
/// tips once when the dialog appears (not with Reduce Motion). `inside` keeps both inside the
/// view's bounds, for sheets whose edge is the screen.
struct FestiveDialogDecor: ViewModifier {
    var inside = false
    var cap = true
    @State private var christmas = ChristmasModeService.shared
    @State private var angle = -10.0

    func body(content: Content) -> some View {
        if christmas.isChristmasTime {
            content
                .overlay(alignment: .top) {
                    FestiveSnowTrim().padding(.horizontal, 8).offset(y: inside ? 0 : -8)
                }
                .overlay(alignment: .topLeading) {
                    if cap {
                        // On a sheet the cap sits in the nav bar between Close and the title.
                        FestiveCap(width: inside ? 52 : 64)
                            .rotationEffect(.degrees(angle), anchor: UnitPoint(x: 0.22, y: 0.92))
                            .padding(.leading, inside ? 82 : 14)
                            .offset(y: inside ? 2 : -31)
                    }
                }
                .task { await tip() }
        } else {
            content
        }
    }

    private func tip() async {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        try? await Task.sleep(for: .seconds(0.45))
        for next in [-22.0, 0.0, -10.0] {
            withAnimation(.easeInOut(duration: 0.3)) { angle = next }
            try? await Task.sleep(for: .seconds(0.3))
        }
    }
}

extension View {
    /// Cap and snow trim on a dialog (Christmas mode only).
    func festiveDialogDecor(inside: Bool = false, cap: Bool = true) -> some View {
        modifier(FestiveDialogDecor(inside: inside, cap: cap))
    }

    /// A small Santa cap on a floating button's corner (Christmas mode only).
    func festiveFloatingCap() -> some View { modifier(FestiveFloatingCap()) }
}

private struct FestiveFloatingCap: ViewModifier {
    @State private var christmas = ChristmasModeService.shared
    func body(content: Content) -> some View {
        content.overlay(alignment: .topLeading) {
            if christmas.isChristmasTime {
                FestiveCap(width: 36).rotationEffect(.degrees(-14)).offset(x: -9, y: -19)
            }
        }
    }
}

// MARK: - Buttons

/// A burst of little stars thrown outward from the middle of a button.
private struct SparkleBurst: View {
    let trigger: Int
    @State private var progress = 0.0
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) / 8 * 2 * .pi
                Text("✦")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "E8C27A"))
                    .scaleEffect(0.4 + progress * 0.9)
                    .offset(x: cos(angle) * 40 * progress, y: sin(angle) * 40 * progress)
                    .opacity(progress == 0 ? 0 : 1 - progress)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            progress = 0
            withAnimation(.easeOut(duration: 0.6)) { progress = 1 }
        }
    }
}

enum FestiveButtonKind { case main, secondary, destructive }

/// Pill buttons for Christmas mode. They squash when pressed and spring back. The main button
/// wears a bow and throws sparkles, the secondary one a sprig of holly, and the destructive one
/// stays plain red so it never looks like a decoration.
struct FestiveButtonStyle: ButtonStyle {
    var kind: FestiveButtonKind = .main
    @Environment(\.festivePalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        FestiveButtonBody(configuration: configuration, kind: kind, palette: palette)
    }
}

private struct FestiveButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: FestiveButtonKind
    let palette: FestivePalette
    @State private var burst = 0

    var body: some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 20).padding(.vertical, 11)
            .background(Capsule(style: .continuous).fill(fill))
            .overlay(Capsule(style: .continuous).strokeBorder(kind == .secondary ? palette.gold.opacity(0.55) : .clear, lineWidth: 1))
            .overlay(alignment: .topTrailing) { if kind == .main { FestiveBow().offset(x: 8, y: -11).rotationEffect(.degrees(14)) } }
            .overlay(alignment: .topLeading) { if kind == .secondary { FestiveHolly().offset(x: -6, y: -9).rotationEffect(.degrees(-18)) } }
            .overlay { if kind == .main { SparkleBurst(trigger: burst) } }
            .scaleEffect(x: configuration.isPressed ? 0.93 : 1, y: configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.5), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { AppHaptics.tap(); if kind == .main { burst += 1 } }
            }
    }

    private var fill: Color {
        switch kind {
        case .main: return palette.isNight ? Color(hex: "E8C27A") : Color(hex: "B5362C")
        case .secondary: return palette.glassHigh
        case .destructive: return Color(hex: "D6342B")
        }
    }

    private var foreground: Color {
        switch kind {
        case .main: return palette.isNight ? Color(hex: "2A1B00") : .white
        case .secondary: return palette.ink
        case .destructive: return .white
        }
    }
}

// MARK: - Alerts

struct FestiveAlertButton: Identifiable {
    enum Role { case normal, cancel, destructive }
    let id = UUID()
    let title: String
    var role = Role.normal
    var action: () -> Void = {}

    static func cancel(_ title: String = "Cancel", action: @escaping () -> Void = {}) -> FestiveAlertButton {
        FestiveAlertButton(title: title, role: .cancel, action: action)
    }
    static func destructive(_ title: String, action: @escaping () -> Void) -> FestiveAlertButton {
        FestiveAlertButton(title: title, role: .destructive, action: action)
    }
    static func normal(_ title: String, action: @escaping () -> Void = {}) -> FestiveAlertButton {
        FestiveAlertButton(title: title, role: .normal, action: action)
    }
}

struct FestiveAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
    let buttons: [FestiveAlertButton]
    /// Clears the caller's `isPresented` flag.
    let onDismiss: () -> Void
}

/// Holds the alert that is on screen. `RootTabView` shows it above everything else.
@MainActor
@Observable
final class FestiveAlertCenter {
    static let shared = FestiveAlertCenter()
    private(set) var current: FestiveAlertItem?
    func present(_ item: FestiveAlertItem) { current = item }
    func dismiss() { let item = current; current = nil; item?.onDismiss() }
}

extension View {
    /// Like `.alert(title, isPresented:)`. In Christmas mode it shows a festive dialog with a cap
    /// and snow trim; otherwise the normal system alert, with the same buttons.
    func festiveAlert(_ title: String, isPresented: Binding<Bool>, message: String? = nil, buttons: [FestiveAlertButton]) -> some View {
        modifier(FestiveAlertModifier(title: title, message: message, isPresented: isPresented, buttons: buttons))
    }
}

private struct FestiveAlertModifier: ViewModifier {
    let title: String
    let message: String?
    @Binding var isPresented: Bool
    let buttons: [FestiveAlertButton]
    @State private var christmas = ChristmasModeService.shared

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: Binding(get: { isPresented && !christmas.isChristmasTime }, set: { isPresented = $0 })) {
                ForEach(buttons) { button in
                    Button(button.title, role: button.role == .cancel ? .cancel : (button.role == .destructive ? .destructive : nil), action: button.action)
                }
            } message: {
                if let message { Text(message) }
            }
            .onChange(of: isPresented, initial: true) { _, shown in
                guard shown, christmas.isChristmasTime else { return }
                FestiveAlertCenter.shared.present(FestiveAlertItem(title: title, message: message, buttons: buttons, onDismiss: { isPresented = false }))
            }
    }
}

/// The festive alert, drawn over the whole app: a dimmed backdrop, a card that drops in with a
/// spring and the Santa cap and snow trim on it.
struct FestiveAlertHost: View {
    private let center = FestiveAlertCenter.shared
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = FestivePalette.forScheme(scheme)
        ZStack {
            if let item = center.current {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { }
                card(item, palette: palette)
                    .padding(.horizontal, 32)
                    .transition(.asymmetric(insertion: .modifier(active: DropIn(on: true), identity: DropIn(on: false)), removal: .opacity.combined(with: .scale(scale: 0.96))))
            }
        }
        .animation(.spring(duration: 0.55, bounce: 0.3), value: center.current?.id)
    }

    private func card(_ item: FestiveAlertItem, palette: FestivePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title).font(.festiveSerif(21, weight: .semibold)).foregroundStyle(palette.ink)
            if let message = item.message {
                Text(message).font(.system(size: 14)).foregroundStyle(palette.inkMuted).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                ForEach(item.buttons) { button in
                    Button(button.title) { button.action(); center.dismiss() }
                        .buttonStyle(FestiveButtonStyle(kind: kind(of: button)))
                }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 18)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: palette.isNight ? [Color(hex: "202A5C"), Color(hex: "151C44")] : [.white, Color(hex: "E7EEF8")], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(palette.gold.opacity(0.6), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
        .festiveDialogDecor()
        .environment(\.festivePalette, palette)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func kind(of button: FestiveAlertButton) -> FestiveButtonKind {
        switch button.role {
        case .cancel: return .secondary
        case .destructive: return .destructive
        case .normal: return .main
        }
    }
}

/// The drop-in: starts above and a little small, and the spring carries it down.
private struct DropIn: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        content.offset(y: on ? -70 : 0).scaleEffect(on ? 0.9 : 1).opacity(on ? 0 : 1)
    }
}
