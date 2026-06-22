import SwiftUI

/// A swipeable, paginated lyrics reader that mimics the Flutter app's page-flip experience.
///
/// Lyrics are split into verses (double-newline separated paragraphs) and grouped into
/// pages sized to the available viewport. Pages are turned with a horizontal paging
/// `TabView`, with a light haptic on each page change.
public struct PageFlipLyricsView: View {
    private let lyrics: String
    private let fontSize: CGFloat
    private let textColor: Color
    private let accent: Color
    
    @State private var currentPage = 0
    
    public init(lyrics: String, fontSize: CGFloat, textColor: Color, accent: Color) {
        self.lyrics = lyrics
        self.fontSize = fontSize
        self.textColor = textColor
        self.accent = accent
    }
    
    private var paragraphs: [String] {
        lyrics.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    public var body: some View {
        GeometryReader { geo in
            let pages = paginate(paragraphs, size: geo.size)
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<max(1, pages.count), id: \.self) { index in
                        ScrollView {
                            VStack(spacing: 24) {
                                ForEach(pages.isEmpty ? [""] : pages[index], id: \.self) { para in
                                    Text(para)
                                        .font(.system(size: fontSize, weight: .semibold))
                                        .lineSpacing(fontSize * 0.35)
                                        .foregroundColor(textColor)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 28)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { _, _ in
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
                
                if pages.count > 1 {
                    pageIndicator(total: pages.count)
                        .padding(.vertical, 10)
                }
            }
        }
    }
    
    private func pageIndicator(total: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? accent : textColor.opacity(0.25))
                    .frame(width: index == currentPage ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPage)
            }
        }
    }
    
    /// Groups paragraphs into pages estimated to fit the available height.
    private func paginate(_ paragraphs: [String], size: CGSize) -> [[String]] {
        guard !paragraphs.isEmpty, size.height > 0, size.width > 0 else {
            return paragraphs.isEmpty ? [] : [paragraphs]
        }
        
        let lineHeight = fontSize * 1.35
        let usableHeight = max(lineHeight, size.height - 64) // account for vertical padding
        let maxLinesPerPage = max(4, Int(usableHeight / lineHeight))
        let usableWidth = max(1, size.width - 56) // horizontal padding
        let charsPerLine = max(8, Int(usableWidth / (fontSize * 0.55)))
        
        var pages: [[String]] = []
        var current: [String] = []
        var currentLines = 0
        
        for para in paragraphs {
            let estimatedLines = estimatedLineCount(for: para, charsPerLine: charsPerLine)
            // Start a new page if adding this verse would overflow (and the page isn't empty).
            if currentLines + estimatedLines > maxLinesPerPage && !current.isEmpty {
                pages.append(current)
                current = []
                currentLines = 0
            }
            current.append(para)
            currentLines += estimatedLines + 1 // +1 for inter-verse spacing
        }
        if !current.isEmpty {
            pages.append(current)
        }
        return pages
    }
    
    private func estimatedLineCount(for paragraph: String, charsPerLine: Int) -> Int {
        let explicitLines = paragraph.components(separatedBy: "\n")
        var total = 0
        for line in explicitLines {
            let count = max(1, Int(ceil(Double(line.count) / Double(charsPerLine))))
            total += count
        }
        return max(1, total)
    }
}
