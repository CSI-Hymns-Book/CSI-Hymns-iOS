import SwiftUI

/// Liturgy browser for Apple Watch displaying Order of Service with highlighted congregation responses.
public struct WatchOrderOfServiceView: View {
    @StateObject private var dataLoader = WatchDataLoader.shared
    @State private var serviceType: String = "regular" // "regular" or "festival"
    
    private var pages: [OrderPage] {
        serviceType == "regular" ? dataLoader.regularLiturgies : dataLoader.festivalLiturgies
    }
    
    public var body: some View {
        List {
            HStack(spacing: 6) {
                Button {
                    serviceType = "regular"
                } label: {
                    Text("Regular")
                        .font(.system(size: 11, weight: serviceType == "regular" ? .bold : .regular))
                        .frame(maxWidth: .infinity)
                }
                .tint(serviceType == "regular" ? .accentColor : .gray.opacity(0.3))
                
                Button {
                    serviceType = "festival"
                } label: {
                    Text("Festival")
                        .font(.system(size: 11, weight: serviceType == "festival" ? .bold : .regular))
                        .frame(maxWidth: .infinity)
                }
                .tint(serviceType == "festival" ? .accentColor : .gray.opacity(0.3))
            }
            .listRowBackground(Color.clear)
            
            if pages.isEmpty {
                Text("Loading liturgy...")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(pages) { page in
                    NavigationLink(destination: WatchOrderPageDetailView(page: page)) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Page \(page.pageNo)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.accentColor)
                                Spacer()
                            }
                            
                            Text(page.title ?? "Liturgy Section \(page.pageNo)")
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Order of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Liturgy page detail view on Apple Watch with responsive text styling.
public struct WatchOrderPageDetailView: View {
    public let page: OrderPage
    @AppStorage("watch_font_size") private var fontSize: Double = 16.0
    
    public init(page: OrderPage) {
        self.page = page
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let title = page.title {
                    Text(title)
                        .font(.system(size: fontSize + 1, weight: .bold))
                        .foregroundColor(.accentColor)
                        .padding(.bottom, 2)
                    
                    Divider()
                }
                
                // Content with highlighted responses
                ForEach(splitParagraphs(page.content), id: \.self) { paragraph in
                    let isResponse = paragraph.hasPrefix("ಸಭೆ:") ||
                                     paragraph.hasPrefix("ಸಭೆ :") ||
                                     paragraph.hasPrefix("People:") ||
                                     paragraph.hasPrefix("Congregation:")
                    
                    Text(paragraph)
                        .font(.system(
                            size: isResponse ? fontSize : fontSize - 1,
                            weight: isResponse ? .bold : .regular
                        ))
                        .foregroundColor(isResponse ? .accentColor : .primary)
                        .lineSpacing(3)
                        .padding(isResponse ? 6 : 0)
                        .background(isResponse ? Color.accentColor.opacity(0.12) : Color.clear)
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .navigationTitle("Page \(page.pageNo)")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func splitParagraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
