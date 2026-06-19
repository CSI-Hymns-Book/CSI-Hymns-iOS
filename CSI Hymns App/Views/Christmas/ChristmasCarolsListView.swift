import SwiftUI
import Observation

/// View model driving parish choice chips, lists, and search queries.
@Observable
public final class ChristmasCarolsListViewModel {
    public var searchQuery = ""
    public var selectedParishFilter = "All"
    public var isShowingUploadForm = false
    
    public init() {}
    
    /// Extract all unique parish names from loaded custom carols to populate filters.
    public func uniqueParishes(from carols: [ChristmasCarol]) -> [String] {
        var list = ["All"]
        let set = Set(carols.map { $0.parish.trimmingCharacters(in: .whitespacesAndNewlines) })
        list.append(contentsOf: set.sorted())
        return list
    }
    
    /// Filters carols list based on active search texts and parish choice chips.
    public func filteredCarols(from carols: [ChristmasCarol]) -> [ChristmasCarol] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        var results = carols
        if selectedParishFilter != "All" {
            results = carols.filter { $0.parish.trimmingCharacters(in: .whitespacesAndNewlines) == selectedParishFilter }
        }
        
        if !query.isEmpty {
            results = results.filter { carol in
                carol.title.lowercased().contains(query) ||
                carol.parish.lowercased().contains(query) ||
                carol.submitter.lowercased().contains(query)
            }
        }
        
        return results
    }
}

/// A premium, festive parish community carols browser.
public struct ChristmasCarolsListView: View {
    @State private var service = ChristmasCarolsService.shared
    @State private var viewModel = ChristmasCarolsListViewModel()
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Festive emerald and dark blue background
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "0B2516"), Color(hex: "0D1B2A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Custom Search
                customSearchBar
                
                // Parish Choice Chips
                parishChoiceChips
                
                if service.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxHeight: .infinity)
                } else if service.carols.isEmpty {
                    emptyStateView
                } else {
                    carolsScrollView
                }
            }
            .padding(.horizontal)
            
            // Floating Upload Button
            floatingUploadButton
        }
        .navigationTitle("Community Carols")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: &viewModel.isShowingUploadForm) {
            AddCarolFormView()
        }
        .onAppear {
            Task {
                try? await service.fetchParishCarols()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var customSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            
            TextField("Search parish carols...", text: $viewModel.searchQuery)
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
        .padding(.top, 8)
    }
    
    private var parishChoiceChips: some View {
        let list = viewModel.uniqueParishes(from: service.carols)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(list, id: \.self) { parish in
                    let isSelected = viewModel.selectedParishFilter == parish
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectedParishFilter = parish
                        }
                    } label: {
                        Text(parish)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                                    .overlay(Capsule().stroke(Color.white.opacity(isSelected ? 0.4 : 0.1), lineWidth: 1))
                            )
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.quarternote.button")
                .font(.system(size: 54))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No Community Carols")
                .font(.system(size: 18, weight: .bold))
                
            Text("Be the first to upload your parish church carols so others can join the celebration!")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var carolsScrollView: some View {
        let list = viewModel.filteredCarols(from: service.carols)
        return ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(list) { carol in
                    NavigationLink(destination: CarolDetailView(carol: carol)) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 46, height: 46)
                                
                                Text("🎄")
                                    .font(.system(size: 22))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(carol.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "house")
                                        .font(.system(size: 10))
                                    Text(carol.parish)
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.white.opacity(0.6))
                            }
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.3))
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
            }
            .padding(.bottom, 80) // Spacing for floating button
        }
    }
    
    private var floatingUploadButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    viewModel.isShowingUploadForm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 16, weight: .bold))
                        Text("Add Carol")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }
}
