import SwiftUI
import Observation

/// View model driving song selection queries and playlist configurations.
@Observable
public final class CustomCategoryDesignerViewModel {
    public var searchQuery = ""
    public var selectedCategoryTab = 0 // 0 = Hymns, 1 = Keerthanes
    public var hymns: [Hymn] = []
    public var keerthanes: [Hymn] = []
    
    public init() {
        loadSeeds()
    }
    
    public var filteredSongs: [Hymn] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let source = selectedCategoryTab == 0 ? hymns : keerthanes
        
        if query.isEmpty {
            return source
        } else {
            return source.filter { song in
                song.title.lowercased().contains(query) ||
                String(song.number).contains(query) ||
                song.signature.lowercased().contains(query)
            }
        }
    }
    
    private func loadSeeds() {
        hymns = [
            Hymn(number: 1, title: "ಪರಮ ತಂದೆಯೇ ಪರಮಾದರದಿ", signature: "C.M", lyricsKannada: "1. ಪರಮ...", lyricsEnglish: "1. Heavenly Father..."),
            Hymn(number: 25, title: "ಯೇಸುವೇ ನಿನ್ನ ಒಲವು ದೊಡ್ಡದು", signature: "L.M", lyricsKannada: "1. ಯೇಸುವೇ...", lyricsEnglish: "1. Jesus Thy Love..."),
            Hymn(number: 110, title: "ಮಹಾ ಪ್ರಭುವೇ ಸ್ತುತಿ ಹಾಗೂ ಘನತೆ", signature: "D.C.M", lyricsKannada: "1. ಮಹಾ...", lyricsEnglish: "1. O Great Lord..."),
            Hymn(number: 212, title: "ಶುದ್ಧಾತ್ಮನೇ ನೀ ಬಾರಯ್ಯ", signature: "7.7.7.7", lyricsKannada: "1. ಶುದ್ಧಾತ್ಮನೇ...", lyricsEnglish: "1. Holy Spirit Come..."),
            Hymn(number: 304, title: "ಕ್ರಿಸ್ತನೆ ಜಯಶಾಲಿ", signature: "C.M", lyricsKannada: "1. ಕ್ರಿಸ್ತನೆ...", lyricsEnglish: "1. Christ the Victor...")
        ]
        keerthanes = [
            Hymn(number: 1, title: "ದೇವಕುಮಾರನೇ ಧನ್ಯಾವಾದಗಳು", signature: "6.7.7.7", lyricsKannada: "1. ದೇವಕುಮಾರನೇ...", lyricsEnglish: "1. Son of God..."),
            Hymn(number: 10, title: "ಯೇಸು ನಮ್ಮ ಆಧಾರ", signature: "C.M", lyricsKannada: "1. ಯೇಸು...", lyricsEnglish: "1. Jesus our Anchor...")
        ]
    }
}

/// A premium, glassmorphic playlist junction selector.
public struct CustomCategoryDesignerView: View {
    @Environment(\.dismiss) private var dismiss
    let categoryId: String
    
    @State private var viewModel = CustomCategoryDesignerViewModel()
    @State private var categoriesViewModel = CustomCategoriesViewModel()
    
    public init(categoryId: String) {
        self.categoryId = categoryId
    }
    
    /// Song IDs active in this target category playlist folder.
    private var activeSongIds: Set<String> {
        guard let folder = categoriesViewModel.categories.first(where: { $0.id == categoryId }) else { return [] }
        return Set(folder.songIds)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Glass Deep background
                LinearGradient(
                    colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Segment Tabs
                    pickerSegmentControl
                    
                    // Search Bar
                    customSearchBar
                    
                    // Song Checklist
                    songsScrollView
                }
                .padding(.horizontal)
            }
            .navigationTitle("Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .bold))
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var pickerSegmentControl: some View {
        HStack(spacing: 0) {
            pickerButton(title: "Hymns", index: 0)
            pickerButton(title: "Keerthanes", index: 1)
        }
        .padding(4)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .padding(.top, 8)
    }
    
    private func pickerButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                viewModel.selectedCategoryTab = index
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.selectedCategoryTab == index ? Color.white.opacity(0.16) : Color.clear)
                )
        }
    }
    
    private var customSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            
            TextField("Search songs to add...", text: $viewModel.searchQuery)
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
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    private var songsScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredSongs) { song in
                    let prefix = viewModel.selectedCategoryTab == 0 ? "hymn_" : "keerthane_"
                    let songKey = "\(prefix)\(song.number)"
                    let isChecked = activeSongIds.contains(songKey)
                    
                    Button {
                        toggleSongSelection(songKey: songKey)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isChecked ? .green : .white.opacity(0.4))
                                .font(.system(size: 22))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(song.number): \(song.title)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                
                                if !song.signature.isEmpty {
                                    Text(song.signature)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isChecked ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(isChecked ? 0.25 : 0.12), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Controller Actions
    
    private func toggleSongSelection(songKey: String) {
        guard let idx = categoriesViewModel.categories.firstIndex(where: { $0.id == categoryId }) else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        var folder = categoriesViewModel.categories[idx]
        if folder.songIds.contains(songKey) {
            folder.songIds.removeAll { $0 == songKey }
        } else {
            folder.songIds.append(songKey)
        }
        
        categoriesViewModel.categories[idx] = folder
        
        // Save
        if let encoded = try? JSONEncoder().encode(categoriesViewModel.categories) {
            UserDefaults.standard.set(encoded, forKey: "csi_custom_categories_local_v1")
        }
        
        // Triggers UI refresh reactively
        categoriesViewModel = CustomCategoriesViewModel()
    }
}
