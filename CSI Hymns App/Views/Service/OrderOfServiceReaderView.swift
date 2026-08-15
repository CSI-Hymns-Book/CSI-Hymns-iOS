import SwiftUI
import Observation
import MessageUI

/// View model driving the remote/local loading of liturgy pages and paginator states.
@Observable
public final class OrderOfServiceReaderViewModel {
    public var pages: [OrderPage] = []
    public var indexEntries: [OrderIndexEntry] = []
    public var currentPageIndex = 0
    public var isLoading = true
    public var errorMessage: String? = nil
    public var jumpUnavailableMessage: String? = nil
    
    private let type: String
    
    public init(type: String) {
        self.type = type
        loadLiturgyPages()
    }
    
    /// Neighboring page numbers around the current page (similar to legacy page chips window).
    public var visiblePageNumbers: [Int] {
        guard !pages.isEmpty else { return [] }
        let range = 3
        let start = max(0, currentPageIndex - range)
        let end = min(pages.count - 1, currentPageIndex + range)
        return (start...end).map { pages[$0].pageNo }
    }
    
    /// Groups pages by their active sections (when a page defines a title).
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
    
    public var pageNoToIndex: [Int: Int] {
        Dictionary(uniqueKeysWithValues: pages.enumerated().map { ($0.element.pageNo, $0.offset) })
    }
    
    @discardableResult
    public func jumpToPageNo(_ pageNo: Int, fromIndex: Bool = false) -> Bool {
        if let idx = pages.firstIndex(where: { $0.pageNo == pageNo }) {
            currentPageIndex = idx
            jumpUnavailableMessage = nil
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            return true
        }
        if fromIndex {
            jumpUnavailableMessage = "Page not available yet"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }
        return false
    }
    
    public func reload() {
        loadLiturgyPages()
    }
    
    private func loadLiturgyPages() {
        isLoading = true
        let loaded = OrderOfServiceStore.loadPages(type: type)
        if !loaded.pages.isEmpty {
            pages = loaded.pages
            indexEntries = loaded.index
            isLoading = false
            errorMessage = nil
            return
        }
        
        loadBundledMockLiturgies()
        indexEntries = []
        errorMessage = pages.isEmpty ? "No liturgy pages available." : nil
    }
    
    private func loadBundledMockLiturgies() {
        let mockRegular = [
            OrderPage(pageNo: 1, title: "Call to Worship / ದೇವಾರಾಧನೆಯ ಪ್ರಾರಂಭ", content: "L: The Lord is in His holy temple; let all the earth keep silence before Him.\n\nಸ: ಕರ್ತನು ತನ್ನ ಪವಿತ್ರ ಆಲಯದಲ್ಲಿದ್ದಾನೆ; ಭೂಲೋಕವೆಲ್ಲಾ ಆತನ ಸನ್ನಿಧಿಯಲ್ಲಿ ಮೌನವಾಗಿರಲಿ.", type: "regular"),
            OrderPage(pageNo: 2, title: "Confession / ಪಾಪ ಒಪ್ಪಿಗೆ", content: "L: Let us confess our sins to Almighty God.\n\nಸ: ಸರ್ವಶಕ್ತನಾದ ದೇವರಿಗೆ ನಮ್ಮ ಪಾಪಗಳನ್ನು ಅರಿಕೆ ಮಾಡಿಕೊಳ್ಳೋಣ.", type: "regular")
        ]
        let mockFestival = [
            OrderPage(pageNo: 1, title: "Festival Opening / ಹಬ್ಬದ ಆರಾಧನೆಯ ಆರಂಭ", content: "L: Rejoice in the Lord always, for today is a day of joy!\n\nಸ: ಕರ್ತನಲ್ಲಿ ಯಾವಾಗಲೂ ಆನಂದಪಡಿರಿ, ಇಂದು ಸಂತೋಷದ ದಿನವಾಗಿದೆ!", type: "festival")
        ]
        pages = type == "regular" ? mockRegular : mockFestival
        isLoading = false
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
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
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
                        homeHubView(isLandscape: isLandscape)
                    } else {
                        liturgyPagingController(isLandscape: isLandscape)
                    }
                    
                    if !viewModel.isLoading && !viewModel.pages.isEmpty {
                        bottomControlPanel(isLandscape: isLandscape)
                    }
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
        .onReceive(NotificationCenter.default.publisher(for: OrderOfServiceStore.refreshedNotification)) { _ in
            viewModel.reload()
        }
    }
    
    private var currentPageTitle: String {
        guard !viewModel.pages.isEmpty else { return englishHeader }
        let title = (viewModel.pages[viewModel.currentPageIndex].title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? englishHeader : title
    }
    
    private func homeHubView(isLandscape: Bool) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: isLandscape ? 12 : 20) {
                Spacer(minLength: isLandscape ? 10 : 20)
                
                Text(type == "festival" ? "Habbada Aaradhana Krama" : "Huduvada Aaradhana Krama")
                    .font(.system(size: isLandscape ? 20 : 24, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Enter a page number to jump directly to that page")
                    .font(.system(size: 13))
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
                .padding(.vertical, isLandscape ? 10 : 14)
                .background(Color.white.opacity(0.08))
                .cornerRadius(28)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .padding(.horizontal, isLandscape ? 60 : 24)
                
                HStack(spacing: 16) {
                    Button {
                        submitJump()
                    } label: {
                        Text("Go to Page")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(28)
                    }
                    .disabled(jumpPageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(jumpPageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    
                    Button {
                        withAnimation { hasSelectedPage = true }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                            Text("Open Full Book")
                        }
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(28)
                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                }
                .padding(.horizontal, isLandscape ? 60 : 24)
                .padding(.top, 4)
                
                if !viewModel.indexEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ಪರಿವಿಡಿ")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.white)
                        Text("Tap a page number to open that section")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.65))
                        
                        ForEach(viewModel.indexEntries) { entry in
                            let available = viewModel.pageNoToIndex[entry.pageNo] != nil
                            Button {
                                if viewModel.jumpToPageNo(entry.pageNo, fromIndex: true) {
                                    withAnimation { hasSelectedPage = true }
                                }
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(entry.pageNo)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(available ? .black : .white.opacity(0.45))
                                        .frame(width: 44, height: 36)
                                        .background(available ? Color.white : Color.white.opacity(0.08))
                                        .cornerRadius(10)
                                    
                                    Text(entry.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(available ? .white : .white.opacity(0.45))
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!available)
                        }
                    }
                    .padding(.horizontal, isLandscape ? 60 : 24)
                    .padding(.top, 16)
                }
                
                if let msg = viewModel.jumpUnavailableMessage {
                    Text(msg)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
                
                Spacer(minLength: isLandscape ? 10 : 20)
            }
            .frame(maxWidth: isLandscape ? 640 : .infinity)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
        }
    }
    
    private func submitJump() {
        guard let target = Int(jumpPageText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        if viewModel.jumpToPageNo(target) {
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
    
    private func liturgyPagingController(isLandscape: Bool) -> some View {
        TabView(selection: $viewModel.currentPageIndex) {
            ForEach(0..<viewModel.pages.count, id: \.self) { index in
                liturgyPageView(viewModel.pages[index], isLandscape: isLandscape)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
    
    private func liturgyPageView(_ page: OrderPage, isLandscape: Bool) -> some View {
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
            .frame(maxWidth: isLandscape ? 680 : .infinity)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, isLandscape ? 36 : 24)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
    }
    
    private func bottomControlPanel(isLandscape: Bool) -> some View {
        VStack(spacing: 0) {
            if isLandscape {
                HStack(spacing: 12) {
                    if hasSelectedPage {
                        Button {
                            withAnimation { viewModel.currentPageIndex = max(0, viewModel.currentPageIndex - 1) }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(viewModel.currentPageIndex > 0 ? .white : .white.opacity(0.25))
                                .frame(width: 32, height: 32)
                        }
                        .disabled(viewModel.currentPageIndex == 0)
                    }
                    
                    Button { isShowingIndexSheet = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet.rectangle.portrait")
                            Text(hasSelectedPage ? "P.\(viewModel.pages[viewModel.currentPageIndex].pageNo)" : "Index")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(viewModel.visiblePageNumbers, id: \.self) { no in
                                let isCurrent = hasSelectedPage && viewModel.pages[viewModel.currentPageIndex].pageNo == no
                                Button {
                                    viewModel.jumpToPageNo(no)
                                    withAnimation { hasSelectedPage = true }
                                } label: {
                                    Text("\(no)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(isCurrent ? .black : .white)
                                        .frame(width: 28, height: 28)
                                        .background(isCurrent ? Color.white : Color.white.opacity(0.08))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    if hasSelectedPage {
                        Text("\(viewModel.pages[viewModel.currentPageIndex].pageNo)/\(viewModel.pages.last?.pageNo ?? 0)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 4)
                        
                        Button {
                            withAnimation { viewModel.currentPageIndex = min(viewModel.pages.count - 1, viewModel.currentPageIndex + 1) }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(viewModel.currentPageIndex < viewModel.pages.count - 1 ? .white : .white.opacity(0.25))
                                .frame(width: 32, height: 32)
                        }
                        .disabled(viewModel.currentPageIndex == viewModel.pages.count - 1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            } else {
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
            }
        }
        .background(Color(hex: "0D1B2A").opacity(0.95))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.1)), alignment: .top)
    }
    
    private var allPagesSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !viewModel.indexEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ಪರಿವಿಡಿ")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            ForEach(viewModel.indexEntries) { entry in
                                let available = viewModel.pageNoToIndex[entry.pageNo] != nil
                                Button {
                                    if viewModel.jumpToPageNo(entry.pageNo, fromIndex: true) {
                                        isShowingIndexSheet = false
                                        withAnimation { hasSelectedPage = true }
                                    }
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(entry.pageNo)")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(available ? .black : .white.opacity(0.4))
                                            .frame(width: 40, height: 32)
                                            .background(available ? Color.white : Color.white.opacity(0.08))
                                            .cornerRadius(8)
                                        Text(entry.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(available ? .white : .white.opacity(0.4))
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .disabled(!available)
                            }
                        }
                    }
                    
                    Text("Available pages")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                    
                    ForEach(viewModel.groupedSections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            if !section.title.isEmpty {
                                Text(formatHeaderTitle(section.title))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 4)
                            }
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 46))], spacing: 10) {
                                ForEach(section.pages) { p in
                                    let isCurrent = viewModel.pages[viewModel.currentPageIndex].pageNo == p.pageNo
                                    Button {
                                        _ = viewModel.jumpToPageNo(p.pageNo)
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
