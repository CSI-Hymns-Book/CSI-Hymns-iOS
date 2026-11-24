import SwiftUI

private struct SnowCapsVisibleKey: EnvironmentKey { static let defaultValue = true }

extension EnvironmentValues {
    /// False while this part of the screen is covered by another (a list under an open song), so
    /// snow does not appear to land on something nobody can see.
    var snowCapsVisible: Bool {
        get { self[SnowCapsVisibleKey.self] }
        set { self[SnowCapsVisibleKey.self] = newValue }
    }
}

extension View {
    /// A pile of snow on top of this view that follows its rounded corners, stays inside its width,
    /// slides off when the phone tilts and falls when it is shaken. Apply after the background and
    /// do not clip the result: the cap draws just above the top edge.
    func snowCap(cornerRadius: CGFloat = 22, enabled: Bool = true) -> some View {
        modifier(SnowCapModifier(cornerRadius: cornerRadius, enabled: enabled))
    }
}

private struct SnowCapModifier: ViewModifier {
    let cornerRadius: CGFloat
    let enabled: Bool
    @State private var model = FestiveCapModel(initialDepth: 0.6)
    @Environment(\.festivePalette) private var palette
    @Environment(\.snowCapsVisible) private var capsVisible
    private let ambience = FestiveAmbience.shared

    func body(content: Content) -> some View {
        if ambience.level == .off {
            content
        } else {
            content
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { model.frame = $0 }
                .onAppear { model.visible = enabled && capsVisible; ambience.sim.register(model) }
                .onDisappear { ambience.sim.unregister(model) }
                .onChange(of: enabled && capsVisible) { _, visible in model.visible = visible }
                .overlay(alignment: .top) {
                    SnowCapCanvas(model: model, corner: cornerRadius, palette: palette)
                        .allowsHitTesting(false)
                }
        }
    }
}

private struct SnowCapCanvas: View {
    let model: FestiveCapModel
    let corner: CGFloat
    let palette: FestivePalette

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                // The pile lives in a plain class SwiftUI cannot see change, so the canvas must
                // read the frame time: otherwise SwiftUI treats every frame as identical and never
                // redraws, and the pile stays frozen full while the simulation drains it.
                Canvas { ctx, _ in
                    _ = timeline.date
                    let depth = model.values.depth
                    guard depth >= 0.01 else { return }
                    let o = SnowCapMetrics.overhang, base = SnowCapMetrics.baseline
                    var path = Path()
                    func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
                    for cmd in buildSnowCapOutline(cardWidth: Double(width), seed: model.seed, corner: Double(corner)) {
                        switch cmd {
                        case .move(let x, let y): path.move(to: point(x, y))
                        case .line(let x, let y): path.addLine(to: point(x, y))
                        case .quad(let cx, let cy, let x, let y): path.addQuadCurve(to: point(x, y), control: point(cx, cy))
                        }
                    }
                    path.closeSubpath()
                    let alpha = min(1, depth * 6)
                    var c = ctx
                    // Scale the pile's height around the line that sits on the card's top edge.
                    c.translateBy(x: model.values.slide - o, y: 0)
                    c.translateBy(x: 0, y: base); c.scaleBy(x: 1, y: depth); c.translateBy(x: 0, y: -base)
                    var shadow = c; shadow.translateBy(x: 0, y: 1.5)
                    shadow.fill(path, with: .color(palette.capShadow.opacity(alpha)))
                    c.fill(path, with: .color(palette.capSnow.opacity(alpha)))
                }
            }
            .frame(width: width + 2 * SnowCapMetrics.overhang, height: SnowCapMetrics.height)
            // Put the baseline 3pt inside the top edge so there is never a gap.
            .offset(x: 0, y: -(SnowCapMetrics.baseline - SnowCapMetrics.moundAboveCard))
        }
    }
}
