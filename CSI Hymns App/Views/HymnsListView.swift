import SwiftUI
import Observation

/// View model driving the search queries, sorting preferences, and list rendering of Hymns.
@Observable
public final class HymnsListViewModel {
    public var searchQuery = ""
    public var selectedOrder: OrderMode = .number
    public var hymns: [Hymn] = []
    public var isLoading = false
    public var isKeerthanes = false
    
    public enum OrderMode: String, CaseIterable, Identifiable {
        case number = "Number"
        case meter = "Meter"
        public var id: String { self.rawValue }
    }
    
    public init(isKeerthanes: Bool = false) {
        self.isKeerthanes = isKeerthanes
        loadMockHymns()
    }
    
    /// Filters and sorts hymns based on user selections.
    public var filteredHymns: [Hymn] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let source = hymns
        
        var results = source
        if !query.isEmpty {
            results = source.filter { hymn in
                hymn.title.lowercased().contains(query) ||
                String(hymn.number).contains(query) ||
                hymn.signature.lowercased().contains(query)
            }
        }
        
        switch selectedOrder {
        case .number:
            return results.sorted { $0.number < $1.number }
        case .meter:
            return results.sorted { $0.signature < $1.signature }
        }
    }
    
    /// Groups hymns by their time signature meter keys, splitting multi-meter signatures.
    public var groupedHymns: [String: [Hymn]] {
        var groups = [String: [Hymn]]()
        
        for hymn in filteredHymns {
            let parts = hymn.signature
                .components(separatedBy: " / ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            let realMeters = parts.filter { !isTuneReference($0) }
            let groupKeys = !realMeters.isEmpty ? realMeters : [hymn.signature.isEmpty ? "No Meter" : hymn.signature]
            
            for key in groupKeys {
                groups[key, default: []].append(hymn)
            }
        }
        
        return groups
    }
    
    private func isTuneReference(_ part: String) -> Bool {
        let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") {
            return true
        }
        
        // Match standard tune indices like 'Mang.T.B.' or 'M.T.' followed by digits
        let pattern = "^(Mang\\.T\\.B\\.|M\\.T\\.)\\d"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func loadMockHymns() {
        self.isLoading = true
        if isKeerthanes {
            self.hymns = [
                Hymn(number: 1, title: "ದೇವಕುಮಾರನೇ ಧನ್ಯಾವಾದಗಳು", signature: "6.7.7.7", lyricsKannada: "1. ದೇವಕುಮಾರನೇ ಧನ್ಯಾವಾದಗಳು...", lyricsEnglish: "1. O Son of God, thank you..."),
                Hymn(number: 10, title: "ಯೇಸು ನಮ್ಮ ಆಧಾರ", signature: "C.M", lyricsKannada: "1. ಯೇಸು ನಮ್ಮ ಆಧಾರ...", lyricsEnglish: "1. Jesus is our Anchor..."),
                Hymn(number: 102, title: "ಸ್ತೋತ್ರ ಯೇಸುವಿಗೆ ಸ್ತೋತ್ರ", signature: "7.7.7.7", lyricsKannada: "1. ಸ್ತೋತ್ರ ಯೇಸುವಿಗೆ...", lyricsEnglish: "1. Praise be to Jesus...")
            ]
        } else {
            self.hymns = [
                Hymn(number: 1, title: "ಪರಮ ತಂದೆಯೇ ಪರಮಾದರದಿ", signature: "C.M", lyricsKannada: "1. ಪರಮ ತಂದೆಯೇ ಪರಮಾದರದಿ ಮಂದಿರದೊಳಗಿರುವೆ...", lyricsEnglish: "1. Heavenly Father, in love we assemble..."),
                Hymn(number: 25, title: "ಯೇಸುವೇ ನಿನ್ನ ಒಲವು ದೊಡ್ಡದು", signature: "L.M", lyricsKannada: "1. ಯೇಸುವೇ ನಿನ್ನ ಒಲವು ದೊಡ್ಡದು ಒಲವಿನೊಳಗೆ...", lyricsEnglish: "1. O Jesus, Thy love is so great..."),
                Hymn(number: 110, title: "ಮಹಾ ಪ್ರಭುವೇ ಸ್ತುತಿ ಹಾಗೂ ಘನತೆ", signature: "D.C.M", lyricsKannada: "1. ಮಹಾ ಪ್ರಭುವೇ ಸ್ತುತಿ ಹಾಗೂ ಘನತೆ ನಿನಗೆ ಸಲ್ಲಲಿ...", lyricsEnglish: "1. O Great Lord, all praise and honor..."),
                Hymn(number: 212, title: "ಶುದ್ಧಾತ್ಮನೇ ನೀ ಬಾರಯ್ಯ", signature: "7.7.7.7", lyricsKannada: "1. ಶುದ್ಧಾತ್ಮನೇ ನೀ ಬಾರಯ್ಯ ನಮ್ಮಲ್ಲಿ ನೆಲೆಸಯ್ಯ...", lyricsEnglish: "1. O Holy Spirit come, dwell within us..."),
                Hymn(number: 304, title: "ಕ್ರಿಸ್ತನೆ ಜಯಶಾಲಿ", signature: "C.M", lyricsKannada: "1. ಕ್ರಿಸ್ತನೆ ಜಯಶಾಲಿ ಆತನೇ ನಮ್ಮ ನಾಯಕನು...", lyricsEnglish: "1. Christ the Victor, He is our Captain...")
            ]
        }
        self.isLoading = false
    }
}

/// A premium, glassmorphic view rendering the list of hymns, search filters, and sorting.
public struct HymnsListView: View {
    @State private var viewModel: HymnsListViewModel
    @State private var isShowingJumpSheet = false
    
    private let title: String
    
    public init(title: String = "CSI Hymns", isKeerthanes: Bool = false) {
        self.title = title
        self._viewModel = State(initialValue: HymnsListViewModel(isKeerthanes: isKeerthanes))
    }
    
    public var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ZStack {
                    // Deep gradient background conforming to Liquid Glass aesthetics
                    LinearGradient(
                        colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        // Custom Glass Search Container
                        customSearchBar
                        
                        // Filters & Sorting Chips
                        filterChipsRow
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxHeight: .infinity)
                        } else {
                            hymnsScrollView(scrollProxy: scrollProxy)
                        }
                    }
                    .padding(.horizontal)
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                                .foregroundColor(.white)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 14) {
                            NavigationLink(destination: RecentSongsView()) {
                                Image(systemName: "clock")
                                    .foregroundColor(.white)
                            }
                            
                            if viewModel.selectedOrder == .meter {
                                Button {
                                    isShowingJumpSheet = true
                                } label: {
                                    Image(systemName: "list.bullet.indent")
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: &isShowingJumpSheet) {
                    jumpToMeterSheet(scrollProxy: scrollProxy)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var customSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            
            TextField("Search (Number, Title, Meter)...", text: $viewModel.searchQuery)
                .foregroundColor(.white)
                .accentColor(.white)
            
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    private var filterChipsRow: some View {
        HStack(spacing: 12) {
            ForEach(HymnsListViewModel.OrderMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.selectedOrder = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(viewModel.selectedOrder == mode ? Color.white.opacity(0.25) : Color.white.opacity(0.06))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(viewModel.selectedOrder == mode ? 0.4 : 0.1), lineWidth: 1)
                                )
                        )
                        .foregroundColor(.white)
                }
            }
            Spacer()
        }
    }
    
    private func hymnsScrollView(scrollProxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                if viewModel.selectedOrder == .meter {
                    // Render Meter sections
                    ForEach(viewModel.groupedHymns.keys.sorted(), id: \.self) { meter in
                        Section(header: meterHeader(meter)) {
                            ForEach(viewModel.groupedHymns[meter] ?? []) { hymn in
                                hymnCell(hymn)
                            }
                        }
                        .id(meter)
                    }
                } else {
                    // Standard Number list
                    ForEach(viewModel.filteredHymns) { hymn in
                        hymnCell(hymn)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    private func meterHeader(_ meter: String) -> some View {
        Text(meter)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(hex: "1B263B").opacity(0.95))
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            )
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func hymnCell(_ hymn: Hymn) -> some View {
        NavigationLink(destination: HymnDetailView(hymn: hymn)) { // detail view
            HStack(spacing: 16) {
                // Glass-panel music emoji
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 46, height: 46)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    
                    Text("🎵")
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(hymn.number): \(hymn.title)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    if !hymn.signature.isEmpty {
                        Text(hymn.signature)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.white.opacity(0.08))
                            )
                    }
                }
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func jumpToMeterSheet(scrollProxy: ScrollViewProxy) -> some View {
        NavigationStack {
            List(viewModel.groupedHymns.keys.sorted(), id: \.self) { meter in
                Button {
                    isShowingJumpSheet = false
                    withAnimation(.easeInOut(duration: 0.45)) {
                        scrollProxy.scrollTo(meter, anchor: .top)
                    }
                } label: {
                    HStack {
                        Text(meter)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(viewModel.groupedHymns[meter]?.count ?? 0) songs")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Jump to Meter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isShowingJumpSheet = false
                    }
                }
            }
        }
    }
}
