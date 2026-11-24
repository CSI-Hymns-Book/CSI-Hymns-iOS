import SwiftUI
#if canImport(WatchKit)
import WatchKit
#endif

/// Informational handoff view for Apple Watch directing users to view the Order of Service on their iPhone.
public struct WatchOrderOfServiceView: View {
    @ObservedObject private var connectivity = WatchConnectivityService.shared
    @State private var didSendSignal = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // iPhone Icon with glowing accent ring
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "iphone.gen3")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
                
                // Title and Subtitle
                VStack(spacing: 2) {
                    Text("Open on iPhone")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("ಆರಾಧನಾ ಕ್ರಮ · Liturgy")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Informational Card
                Text("The full Order of Service and responsive congregational readings are formatted for your iPhone display.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 4)
                
                // Quick Action / Signal button
                Button {
                    #if canImport(WatchKit)
                    WKInterfaceDevice.current().play(.click)
                    #endif
                    connectivity.notifyPhoneToOpenOrderOfService()
                    withAnimation {
                        didSendSignal = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation {
                            didSendSignal = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: didSendSignal ? "checkmark.circle.fill" : "arrow.up.forward.app")
                            .font(.system(size: 12, weight: .bold))
                        Text(didSendSignal ? "Sent to iPhone" : "Notify iPhone")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .tint(didSendSignal ? .green : .accentColor)
                
                // Connection Indicator
                HStack(spacing: 5) {
                    Circle()
                        .fill(connectivity.isReachable ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    
                    Text(connectivity.isReachable ? "iPhone is active" : "Open CSI Hymns on iPhone")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .navigationTitle("Order of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}
