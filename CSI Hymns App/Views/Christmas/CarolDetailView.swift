import SwiftUI

/// A premium, festive lyrics reader view for custom parish carols.
public struct CarolDetailView: View {
    let carol: ChristmasCarol
    
    @State private var selectedLanguage: String = "Kannada" // Kannada or English
    @State private var fontSize: CGFloat = 18.0
    
    public init(carol: ChristmasCarol) {
        self.carol = carol
    }
    
    public var body: some View {
        ZStack {
            // Festive dark emerald and ruby gradient background
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "0B2516")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Control Panel
                headerPanel
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.vertical, 12)
                
                // Lyrics Swiper
                lyricsSwipeContainer
            }
        }
        .navigationTitle(carol.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Subviews
    
    private var headerPanel: some View {
        HStack {
            // Font adjusters
            HStack(spacing: 14) {
                Button {
                    fontSize = max(14, fontSize - 2)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Text("\(Int(fontSize))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24)
                
                Button {
                    fontSize = min(40, fontSize + 2)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            
            Spacer()
            
            // Language selector if English translation is available
            if carol.lyricsEnglish != nil {
                HStack(spacing: 6) {
                    ForEach(["Kannada", "English"], id: \.self) { lang in
                        Button {
                            withAnimation {
                                selectedLanguage = lang
                            }
                        } label: {
                            Text(lang)
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(selectedLanguage == lang ? Color.white.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
            }
        }
    }
    
    private var lyricsSwipeContainer: some View {
        let text = selectedLanguage == "Kannada" ? carol.lyrics : (carol.lyricsEnglish ?? carol.lyrics)
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        return TabView {
            ForEach(0..<paragraphs.count, id: \.self) { index in
                ScrollView {
                    Text(paragraphs[index])
                        .font(.system(size: fontSize, weight: .medium))
                        .lineSpacing(8)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 36)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
    }
}
