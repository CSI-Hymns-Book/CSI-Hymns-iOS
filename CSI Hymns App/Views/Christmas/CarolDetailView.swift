import SwiftUI

/// A premium, festive lyrics reader view for custom parish carols.
public struct CarolDetailView: View {
    let carol: ChristmasCarol
    
    @AppStorage("use_page_swipe_physics") private var usePageSwipe = true
    @State private var selectedLanguage: String = "Kannada" // Kannada or English
    @State private var fontSize: CGFloat = 18.0
    @State private var isShowingPDF = false
    
    public init(carol: ChristmasCarol) {
        self.carol = carol
    }
    
    /// Dynamically parses combined bilingual lyrics if English translation exists.
    private var parsedLyrics: (kannada: String, english: String?) {
        let components = carol.lyrics.components(separatedBy: "\n\n---\n\nEnglish Translation:\n")
        if components.count > 1 {
            return (components[0], components[1])
        }
        
        let altComponents = carol.lyrics.components(separatedBy: "\n\n---\n\nEnglish:\n")
        if altComponents.count > 1 {
            return (altComponents[0], altComponents[1])
        }
        
        let genericComponents = carol.lyrics.components(separatedBy: "\n\n---\n\n")
        if genericComponents.count > 1 {
            return (genericComponents[0], genericComponents[1])
        }
        
        return (carol.lyrics, nil)
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
                
                if carol.hasPdf {
                    viewPDFButton
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
                
                // Lyrics Scroll Container (continuous uninterrupted reading)
                continuousLyricsContainer
            }
        }
        .navigationTitle(carol.title)
        .navigationBarTitleDisplayMode(.inline)
        .textSelection(.disabled)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isShowingPDF) {
            if let url = carol.pdfUrl {
                NavigationStack {
                    PDFDocumentReaderView(documentUrlString: url, documentTitle: carol.title)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Done") { isShowingPDF = false }
                                    .foregroundColor(.white)
                            }
                        }
                }
            }
        }
    }
    
    private var viewPDFButton: some View {
        Button {
            isShowingPDF = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.richtext.fill")
                Text("View Sheet Music (PDF)")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ChristmasColors.christmasRed.opacity(0.85))
            )
        }
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
            if parsedLyrics.english != nil {
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
    
    /// Lyrics reader: page-flip when enabled in Settings, otherwise continuous scroll.
    @ViewBuilder
    private var continuousLyricsContainer: some View {
        let text = selectedLanguage == "Kannada" ? parsedLyrics.kannada : (parsedLyrics.english ?? parsedLyrics.kannada)
        if usePageSwipe {
            PageFlipLyricsView(
                lyrics: text,
                fontSize: fontSize,
                textColor: .white,
                accent: ChristmasColors.christmasGold
            )
        } else {
            scrollLyricsContainer(text: text)
        }
    }
    
    private func scrollLyricsContainer(text: String) -> some View {
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(0..<paragraphs.count, id: \.self) { index in
                    Text(paragraphs[index])
                        .font(.system(size: fontSize, weight: .semibold))
                        .lineSpacing(fontSize * 0.35)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                }
            }
            .padding(.vertical, 20)
        }
    }
}
