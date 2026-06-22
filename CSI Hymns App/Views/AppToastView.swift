import SwiftUI

/// Lightweight floating status toast (Flutter `showAppMessage` parity).
struct AppToastModifier: ViewModifier {
    @Binding var message: String?
    var isError: Bool
    
    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background((isError ? Color.red : Color.green).opacity(0.92))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                            withAnimation { self.message = nil }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.35), value: message)
    }
}

extension View {
    func appToast(message: Binding<String?>, isError: Bool = false) -> some View {
        modifier(AppToastModifier(message: message, isError: isError))
    }
}
