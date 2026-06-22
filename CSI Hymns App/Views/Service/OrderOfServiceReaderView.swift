import SwiftUI
import Observation
import MessageUI

/// View model driving the remote/local loading of liturgy pages and paginator states.
@Observable
public final class OrderOfServiceReaderViewModel {
    public var pages: [OrderPage] = []
    public var currentPageIndex = 0
    public var isLoading = true
    public var errorMessage: String? = nil
    
    private let type: String
    
    public init(type: String) {
        self.type = type
        loadLiturgyPages()
    }
    
    /// Neighboring page numbers around the current page (similar to legacy page chips window).
    public var visiblePageNumbers: [Int] {
        guard !pages.isEmpty else { return [] }
        let currentNo = pages[currentPageIndex].pageNo
        let range = 3 // Look 3 pages back and 3 pages forward
        
        let start = max(0, currentPageIndex - range)
        let end = min(pages.count - 1, currentPageIndex + range)
        
        return (start...end).map { pages[$0].pageNo }
    }
    
    /// Groups pages by their active sections (when a page defines a title).
    /// Mirroring legacy Flutter's sequential ordered category block index exactly.
    public var groupedSections: [(title: String, pages: [OrderPage])] {
        var sections: [(title: String, pages: [OrderPage])] = []
        var activeSectionTitle = ""
        
        for page in pages {
            let explicitTitle = (page.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !explicitTitle.isEmpty {
                activeSectionTitle = explicitTitle
            }
            
            if let idx = sections.firstIndex(where: { $0.title == activeSectionTitle }) {
                sections[idx].pages.append(page)
            } else {
                sections.append((title: activeSectionTitle, pages: [page]))
            }
        }
        
        return sections
    }
    
    public func jumpToPageNo(_ pageNo: Int) {
        if let idx = pages.firstIndex(where: { $0.pageNo == pageNo }) {
            currentPageIndex = idx
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
    
    public func reload() {
        loadLiturgyPages()
    }
    
    private func loadLiturgyPages() {
        self.isLoading = true
        
        // 1. Attempt loading from Flutter-aligned cached UserDefaults JSON
        if let cachedData = UserDefaults.standard.data(forKey: "orderOfServiceData") {
            do {
                let parsed = try OrderPage.parsePages(from: cachedData)
                let filtered = parsed.filter { $0.type == self.type }
                if !filtered.isEmpty {
                    self.pages = filtered
                    self.isLoading = false
                    print("[OrderOfServiceReader] Loaded \(filtered.count) pages from 'orderOfServiceData' cache.")
                    return
                }
            } catch {
                print("[OrderOfServiceReader] Error parsing 'orderOfServiceData' cache: \(error)")
            }
        }
        
        // 2. Backwards compatibility: Attempt loading from legacy csi_cached_liturgies_json
        if let cachedData = UserDefaults.standard.data(forKey: "csi_cached_liturgies_json") {
            do {
                let parsed = try OrderPage.parsePages(from: cachedData)
                let filtered = parsed.filter { $0.type == self.type }
                if !filtered.isEmpty {
                    self.pages = filtered
                    self.isLoading = false
                    print("[OrderOfServiceReader] Loaded \(filtered.count) pages from legacy 'csi_cached_liturgies_json' cache.")
                    return
                }
            } catch {
                print("[OrderOfServiceReader] Error parsing legacy cache: \(error)")
            }
        }
        
        // 3. Fallback: Load from compiled offline seed string
        if let seedData = LiturgyOfflineSeeds.fallbackJSON.data(using: .utf8) {
            do {
                let parsed = try OrderPage.parsePages(from: seedData)
                let filtered = parsed.filter { $0.type == self.type }
                if !filtered.isEmpty {
                    self.pages = filtered
                    self.isLoading = false
                    print("[OrderOfServiceReader] Loaded \(filtered.count) pages from offline seeds.")
                    return
                }
            } catch {
                print("[OrderOfServiceReader] Error parsing offline seeds: \(error)")
            }
        }
        
        // 4. Last fallback: Seed hardcoded mock items if everything else fails
        loadBundledMockLiturgies()
    }
    
    private func loadBundledMockLiturgies() {
        // Seeds comprehensive liturgies for regular and festival types
        let mockRegular = [
            OrderPage(pageNo: 1, title: "Call to Worship / ದೇವಾರಾಧನೆಯ ಪ್ರಾರಂಭ", content: "L: The Lord is in His holy temple; let all the earth keep silence before Him.\n\nಸ: ಕರ್ತನು ತನ್ನ ಪವಿತ್ರ ಆಲಯದಲ್ಲಿದ್ದಾನೆ; ಭೂಲೋಕವೆಲ್ಲಾ ಆತನ ಸನ್ನಿಧಿಯಲ್ಲಿ ಮೌನವಾಗಿರಲಿ.", type: "regular"),
            OrderPage(pageNo: 2, title: "Confession / ಪಾಪ ಒಪ್ಪಿಗೆ", content: "L: Let us confess our sins to Almighty God.\n\nಸ: ಸರ್ವಶಕ್ತನಾದ ದೇವರಿಗೆ ನಮ್ಮ ಪಾಪಗಳನ್ನು ಅರಿಕೆ ಮಾಡಿಕೊಳ್ಳೋಣ.", type: "regular"),
            OrderPage(pageNo: 3, title: "Absolution / ಪಾಪ ಪರಿಹಾರ ಘೋಷಣೆ", content: "L: May the Almighty God grant you pardon and remission of all your sins.\n\nಸ: ಸರ್ವಶಕ್ತನಾದ ದೇವರು ನಿಮಗೆ ಕ್ಷಮಾಪಣೆಯನ್ನೂ ನಿಮ್ಮ ಪಾಪಗಳ ನಿವಾರಣೆಯನ್ನೂ ಅನುಗ್ರಹಿಸಲಿ.", type: "regular"),
            OrderPage(pageNo: 4, title: "Thanksgiving / ಕೃತಜ್ಞತಾ ಸ್ತುತಿ", content: "L: O give thanks unto the Lord, for He is good.\n\nಸ: ಕರ್ತನಿಗೆ ಕೃತಜ್ಞತಾಸ್ತುತಿ ಮಾಡಿರಿ, ಆತನು ಒಳ್ಳೆಯವನು; ಆತನ ಕೃಪೆಯು ಎಂದೆಂದಿಗೂ ಇರುತ್ತದೆ.", type: "regular")
        ]
        
        let mockFestival = [
            OrderPage(pageNo: 1, title: "Festival Opening / ಹಬ್ಬದ ಆರಾಧನೆಯ ಆರಂಭ", content: "L: Rejoice in the Lord always, for today is a day of joy!\n\nಸ: ಕರ್ತನಲ್ಲಿ ಯಾವಾಗಲೂ ಆನಂದಪಡಿರಿ, ಇಂದು ಸಂತೋಷದ ದಿನವಾಗಿದೆ!", type: "festival"),
            OrderPage(pageNo: 2, title: "Festive Praise / ಹಬ್ಬದ ಕೀರ್ತನೆ", content: "L: Praise Him with the sound of the trumpet!\n\nಸ: ತುತೂರಿ ಧ್ವನಿಯಿಂದ ಆತನನ್ನು ಸ್ತುತಿಸಿರಿ; ವೀಣೆ ರಾಗಗಳೊಡನೆ ಆತನನ್ನು ಕೊಂಡಾಡಿರಿ.", type: "festival")
        ]
        
        if self.type == "regular" {
            self.pages = mockRegular
        } else {
            self.pages = mockFestival
        }
        
        self.isLoading = false
    }
}

/// An immersive liturgy reader with a home hub (jump / open full book) before paging.
public struct OrderOfServiceReaderView: View {
    let type: String
    let englishHeader: String
    let kannadaHeader: String
    
    @State private var viewModel: OrderOfServiceReaderViewModel
    @State private var hasSelectedPage = false
    @State private var jumpPageText = ""
    @State private var isShowingIndexSheet = false
    @State private var isShowingReportSheet = false
    @State private var reportDescription = ""
    
    public init(type: String, englishHeader: String, kannadaHeader: String) {
        self.type = type
        self.englishHeader = englishHeader
        self.kannadaHeader = kannadaHeader
        self._viewModel = State(initialValue: OrderOfServiceReaderViewModel(type: type))
    }
    
    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "132237"), Color(hex: "0D1B2A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxHeight: .infinity)
                } else if viewModel.pages.isEmpty {
                    emptyStateView
                } else if !hasSelectedPage {
                    homeHubView
                } else {
                    liturgyPagingController
                }
                
                if !viewModel.isLoading && !viewModel.pages.isEmpty {
                    bottomControlPanel
                }
            }
        }
        .navigationTitle(hasSelectedPage ? currentPageTitle : "\(kannadaHeader) / \(englishHeader)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(hasSelectedPage)
        .toolbar {
            if hasSelectedPage {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation { hasSelectedPage = false }
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isShowingReportSheet = true } label: {
                        Image(systemName: "exclamationmark.bubble")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isShowingIndexSheet) { allPagesSheet }
        .sheet(isPresented: $isShowingReportSheet) { reportIssueSheet }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("csi_liturgies_refreshed"))) { _ in
            viewModel.reload()
        }
    }
    
    private var currentPageTitle: String {
        guard !viewModel.pages.isEmpty else { return englishHeader }
        let title = (viewModel.pages[viewModel.currentPageIndex].title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? englishHeader : title
    }
    
    private var homeHubView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text(type == "festival" ? "Habbada Aaradhana Krama" : "Huduvada Aaradhana Krama")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Enter a page number to jump directly to that page")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                TextField("Jump to page number (e.g., 1, 98, 100)", text: $jumpPageText)
                    .keyboardType(.numberPad)
                    .foregroundColor(.white)
                    .submitLabel(.go)
                    .onSubmit { submitJump() }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .cornerRadius(28)
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .padding(.horizontal, 24)
            
            Button {
                submitJump()
            } label: {
                Text("Go to Page")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(28)
            }
            .disabled(jumpPageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(jumpPageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            
            Button {
                withAnimation { hasSelectedPage = true }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                    Text("Open Full Book")
                }
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(.white)
                .frame(maxWidth: 280)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.12))
                .cornerRadius(28)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            .padding(.top, 4)
            
            Spacer()
        }
    }
    
    private func submitJump() {
        guard let target = Int(jumpPageText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        viewModel.jumpToPageNo(target)
        if viewModel.pages.contains(where: { $0.pageNo == target }) {
            withAnimation { hasSelectedPage = true }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Liturgy Empty")
                .font(.system(size: 18, weight: .bold))
                
            Text("No pages available for this liturgy. Refresh in the previous screen or try again later.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var liturgyPagingController: some View {
        TabView(selection: $viewModel.currentPageIndex) {
            ForEach(0..<viewModel.pages.count, id: \.self) { index in
                liturgyPageView(viewModel.pages[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
    
    private func liturgyPageView(_ page: OrderPage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section Title header card if present
                if let sectionTitle = page.title, !sectionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SECTION")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue)
                        
                        Text(formatHeaderTitle(sectionTitle))
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.white)
                            .lineSpacing(6)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                
                // Page Content text
                Text(page.content)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .lineSpacing(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
    }
    
    private var bottomControlPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Button { isShowingIndexSheet = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                        Text(hasSelectedPage ? "Page \(viewModel.pages[viewModel.currentPageIndex].pageNo)" : "All pages")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.visiblePageNumbers, id: \.self) { no in
                            let isCurrent = hasSelectedPage && viewModel.pages[viewModel.currentPageIndex].pageNo == no
                            Button {
                                viewModel.jumpToPageNo(no)
                                withAnimation { hasSelectedPage = true }
                            } label: {
                                Text("\(no)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(isCurrent ? .black : .white)
                                    .frame(width: 32, height: 32)
                                    .background(isCurrent ? Color.white : Color.white.opacity(0.08))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(isCurrent ? 0.4 : 0.1), lineWidth: 1))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            
            if hasSelectedPage {
                HStack {
                    Button {
                        withAnimation { viewModel.currentPageIndex = max(0, viewModel.currentPageIndex - 1) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(viewModel.currentPageIndex > 0 ? .white : .white.opacity(0.25))
                            .padding(12)
                    }
                    .disabled(viewModel.currentPageIndex == 0)
                    
                    Spacer()
                    
                    Text("Page \(viewModel.pages[viewModel.currentPageIndex].pageNo) of \(viewModel.pages.last?.pageNo ?? 0)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Button {
                        withAnimation { viewModel.currentPageIndex = min(viewModel.pages.count - 1, viewModel.currentPageIndex + 1) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(viewModel.currentPageIndex < viewModel.pages.count - 1 ? .white : .white.opacity(0.25))
                            .padding(12)
                    }
                    .disabled(viewModel.currentPageIndex == viewModel.pages.count - 1)
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
        .background(Color(hex: "0D1B2A").opacity(0.95))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.1)), alignment: .top)
    }
    
    private var allPagesSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(viewModel.groupedSections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            if !section.title.isEmpty {
                                Text(formatHeaderTitle(section.title))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 4)
                            }
                            
                            // Horizontal wrap for pages in this section
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 46))], spacing: 10) {
                                ForEach(section.pages) { p in
                                    let isCurrent = viewModel.pages[viewModel.currentPageIndex].pageNo == p.pageNo
                                    Button {
                                        viewModel.jumpToPageNo(p.pageNo)
                                        isShowingIndexSheet = false
                                        withAnimation { hasSelectedPage = true }
                                    } label: {
                                        Text("\(p.pageNo)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(isCurrent ? .black : .white)
                                            .frame(width: 44, height: 44)
                                            .background(isCurrent ? Color.white : Color.white.opacity(0.1))
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(isCurrent ? 0.5 : 0.15), lineWidth: 1))
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                    }
                }
                .padding(16)
            }
            .background(Color(hex: "0D1B2A").ignoresSafeArea())
            .navigationTitle("All Liturgy Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isShowingIndexSheet = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private var reportIssueSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Report spelling or layout issues on page \(viewModel.pages[viewModel.currentPageIndex].pageNo)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                TextEditor(text: $reportDescription)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .frame(height: 160)
                
                Button {
                    submitCorrectionReport()
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Submit to Jira Support")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(12)
                }
                Spacer()
            }
            .padding(24)
            .background(Color(hex: "0D1B2A").ignoresSafeArea())
            .navigationTitle("Submit Correction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isShowingReportSheet = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatHeaderTitle(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: " / ") {
            let english = trimmed[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let kannada = trimmed[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !english.isEmpty && !kannada.isEmpty {
                return "\(english)\n\n\(kannada)"
            }
        }
        return trimmed
    }
    
    private func submitCorrectionReport() {
        let pageNo = viewModel.pages[viewModel.currentPageIndex].pageNo
        let desc = reportDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            // Submit issue directly to Atlassian Jira Service
            let result = await JiraService.shared.createTicket(
                songType: "Liturgy (\(type))",
                songNumber: pageNo,
                songTitle: "Order of Service - Page \(pageNo)",
                description: desc,
                appVersion: "1.0.0+1"
            )
            
            await MainActor.run {
                if result.success {
                    isShowingReportSheet = false
                    reportDescription = ""
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            }
        }
    }
}
