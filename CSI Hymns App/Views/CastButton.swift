import SwiftUI

#if canImport(GoogleCast)
import GoogleCast

/// Wraps the Google Cast SDK's `GCKUICastButton` for SwiftUI.
struct GoogleCastButton: UIViewRepresentable {
    let tint: UIColor
    
    func makeUIView(context: Context) -> GCKUICastButton {
        let button = GCKUICastButton(frame: CGRect(x: 0, y: 0, width: 28, height: 28))
        button.tintColor = tint
        return button
    }
    
    func updateUIView(_ uiView: GCKUICastButton, context: Context) {
        uiView.tintColor = tint
    }
}
#endif

/// A Chromecast button that only renders when casting is remotely enabled and the
/// Google Cast SDK is linked. Otherwise it renders nothing (AirPlay remains available).
public struct CastButton: View {
    @State private var castService = CastService.shared
    var tint: Color = .primary
    
    public init(tint: Color = .primary) {
        self.tint = tint
    }
    
    public var body: some View {
        Group {
            if castService.featureEnabled {
                #if canImport(GoogleCast)
                GoogleCastButton(tint: UIColor(tint))
                    .frame(width: 28, height: 28)
                #else
                EmptyView()
                #endif
            }
        }
    }
}
