import SwiftUI

/// A premium, App Store-styled promotion screen for the related "Praise App" devotions suite.
public struct PraiseAppPromoView: View {
    @Environment(\.openURL) private var openURL
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Dark royal purple background gradient
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1F1235"), Color(hex: "0D1B2A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    // App Icon Card Hero
                    appPromoHeroCard
                    
                    // Features list
                    featuresOutline
                    
                    // Call to Action
                    downloadStoreButton
                }
                .padding(24)
            }
        }
        .navigationTitle("Related Devotions")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Subviews
    
    private var appPromoHeroCard: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: [Color(hex: "9C27B0"), Color(hex: "E040FB")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 96, height: 96)
                    .shadow(color: Color(hex: "9C27B0").opacity(0.45), radius: 14, x: 0, y: 6)
                
                Text("🕊️")
                    .font(.system(size: 48))
            }
            
            VStack(spacing: 6) {
                Text("Praise App")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.white)
                
                Text("The Ultimate Companion Devotions Suite")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.65))
            }
        }
        .padding(.top, 16)
    }
    
    private var featuresOutline: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Why Download Praise App?")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
            
            VStack(spacing: 14) {
                featureItemRow(
                    title: "Universal search index",
                    description: "Access thousands of additional vernacular and bilingual songs offline.",
                    emoji: "🔍"
                )
                
                featureItemRow(
                    title: "Smart custom folders",
                    description: "Share worship setlists directly with parish members instantly.",
                    emoji: "📁"
                )
                
                featureItemRow(
                    title: "Full audio accompaniments",
                    description: "Vibrant high-quality instrumentals suitable for congregational play.",
                    emoji: "🎹"
                )
            }
        }
    }
    
    private func featureItemRow(title: String, description: String, emoji: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 38, height: 38)
                
                Text(emoji)
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(4)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    private var downloadStoreButton: some View {
        Button {
            // Launches related devotions App Store direct search/download URI
            if let uri = URL(string: "https://apps.apple.com") {
                openURL(uri)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "applelogo")
                    .font(.system(size: 16))
                
                Text("Download on App Store")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.white.opacity(0.12), radius: 10, y: 5)
        }
        .padding(.top, 12)
    }
}
