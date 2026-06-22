import SwiftUI

/// Full-screen blocking gate shown when the running build is below the configured
/// minimum version. The user cannot dismiss it; they must update from the App Store.
public struct ForceUpdateView: View {
    let message: String?
    let storeURL: String?
    
    public init(message: String?, storeURL: String?) {
        self.message = message
        self.storeURL = storeURL
    }
    
    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "132237")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.white)
                
                Text("Update Required")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.white)
                
                Text(message ?? "A new version of CSI Hymns Book is available. Please update to continue.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button {
                    openStore()
                } label: {
                    Text("Update Now")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 40)
            }
        }
    }
    
    private func openStore() {
        let urlString = (storeURL?.isEmpty == false ? storeURL : nil)
            ?? "https://apps.apple.com/app/id0000000000"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
