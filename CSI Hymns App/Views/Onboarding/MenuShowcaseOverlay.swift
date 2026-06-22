import SwiftUI

/// Post-onboarding tab bar showcase overlay (Flutter ShowCaseWidget parity).
struct MenuShowcaseOverlay: View {
    @Binding var isPresented: Bool
    let step: Int
    let onNext: () -> Void
    let onSkip: () -> Void
    
    private var message: (title: String, body: String) {
        switch step {
        case 0: return ("Hymns & Keerthanes", "Browse the full hymn book and keerthane collection from the bottom tabs.")
        case 1: return ("Order of Service", "Open liturgy PDFs and service orders for worship.")
        case 2: return ("Categories", "Find occasion hymn lists and your custom folders.")
        case 3: return ("Favorites", "Save songs and sync them when signed in.")
        default: return ("You're ready!", "Explore CSI Hymns Book — settings and themes live in the menu.")
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onSkip() }
            
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 12) {
                    Text(message.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(message.body)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.85))
                    
                    HStack {
                        Button("Skip", action: onSkip)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Button(step >= 4 ? "Done" : "Next", action: onNext)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
        .transition(.opacity)
    }
}
