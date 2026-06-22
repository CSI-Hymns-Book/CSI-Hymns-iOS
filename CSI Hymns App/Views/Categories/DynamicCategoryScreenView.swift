import SwiftUI

/// A premium, native iOS counterpart to Flutter's DynamicCategoryScreen.
/// Displays segmented tabs for Hymns and Keerthanes matching specific category numbers.
public struct DynamicCategoryScreenView: View {
    let categoryName: String
    let hymnNumbers: [Int]
    let keerthaneNumbers: [Int]
    
    @State private var theme = ThemeManager.shared
    @State private var selectedSegment = 0 // 0 = Hymns, 1 = Keerthanes
    @State private var hymns: [Hymn] = []
    @State private var keerthanes: [Hymn] = []
    @State private var isLoading = false
    
    public init(categoryName: String, hymnNumbers: [Int], keerthaneNumbers: [Int]) {
        self.categoryName = categoryName
        self.hymnNumbers = hymnNumbers
        self.keerthaneNumbers = keerthaneNumbers
    }
    
    private var hasHymns: Bool { !hymnNumbers.isEmpty }
    private var hasKeerthanes: Bool { !keerthaneNumbers.isEmpty }
    
    public var body: some View {
        ZStack {
            // Adaptive theme background
            theme.backgroundColor
                .ignoresSafeArea()
            
            if theme.activeTheme != .amoled {
                theme.backgroundGradient
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Segmented Tab Picker
                if hasHymns && hasKeerthanes {
                    pickerView
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                
                if isLoading {
                    ProgressView()
                        .tint(theme.textPrimary)
                        .frame(maxHeight: .infinity)
                } else {
                    let activeList = selectedSegment == 0 ? hymns : keerthanes
                    
                    if activeList.isEmpty {
                        emptyStateView
                    } else {
                        songsListView(activeList)
                    }
                }
            }
        }
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            setupInitialTab()
            loadCategorySongs()
        }
    }
    
    // MARK: - Subviews
    
    private var pickerView: some View {
        HStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedSegment = 0
                }
            } label: {
                Text("Hymns (\(hymnNumbers.count))")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(selectedSegment == 0 ? theme.textPrimary.opacity(0.12) : Color.clear)
                    )
                    .foregroundColor(selectedSegment == 0 ? theme.accentColor : theme.textSecondary)
            }
            
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedSegment = 1
                }
            } label: {
                Text("Keerthanes (\(keerthaneNumbers.count))")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(selectedSegment == 1 ? theme.textPrimary.opacity(0.12) : Color.clear)
                    )
                    .foregroundColor(selectedSegment == 1 ? theme.accentColor : theme.textSecondary)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(theme.surfaceColor)
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(theme.strokeColor, lineWidth: 1))
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 54))
                .foregroundColor(theme.textSecondary.opacity(0.35))
            
            Text("No Songs Found")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text("Could not resolve song numbers from local cache database.")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func songsListView(_ list: [Hymn]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(list) { song in
                    NavigationLink(destination: HymnDetailView(hymn: song)) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(theme.accentColor.opacity(0.12))
                                    .frame(width: 42, height: 42)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.accentColor.opacity(0.25), lineWidth: 1))
                                
                                Image(song.type == "keerthane" ? "keerthane" : "hymn")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(song.number): \(song.title)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(theme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                
                                if !song.signature.isEmpty {
                                    Text(song.signature)
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(theme.textSecondary.opacity(0.5))
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(theme.cardStroke, lineWidth: 1)
                                )
                                .shadow(color: theme.shadowColor.opacity(0.05), radius: 6, y: 3)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Controller Actions
    
    private func setupInitialTab() {
        if !hasHymns && hasKeerthanes {
            selectedSegment = 1
        } else {
            selectedSegment = 0
        }
    }
    
    private func loadCategorySongs() {
        isLoading = true
        
        var resolvedHymns: [Hymn] = []
        var resolvedKeerthanes: [Hymn] = []
        
        for num in hymnNumbers {
            if let song = FavoritesManager.shared.getHymnFromCache(number: num, type: "hymn") {
                resolvedHymns.append(song)
            } else {
                resolvedHymns.append(Hymn(number: num, title: "Hymn \(num)", signature: "", lyricsKannada: "", lyricsEnglish: "", type: "hymn"))
            }
        }
        
        for num in keerthaneNumbers {
            if let song = FavoritesManager.shared.getHymnFromCache(number: num, type: "keerthane") {
                resolvedKeerthanes.append(song)
            } else {
                resolvedKeerthanes.append(Hymn(number: num, title: "Keerthane \(num)", signature: "", lyricsKannada: "", lyricsEnglish: "", type: "keerthane"))
            }
        }
        
        self.hymns = resolvedHymns.sorted(by: { $0.number < $1.number })
        self.keerthanes = resolvedKeerthanes.sorted(by: { $0.number < $1.number })
        self.isLoading = false
    }
}
