import SwiftUI
import Observation

@Observable
public final class ChristmasCarolsListViewModel {
    public var searchQuery = ""
    public var isShowingCreateChurch = false
    
    public init() {}
    
    public func filteredChurches(_ churches: [CarolChurch], service: ChristmasCarolsService) -> [CarolChurch] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return churches }
        return churches.filter { church in
            if church.name.lowercased().contains(query) { return true }
            return service.songs(for: church.id).contains { $0.title.lowercased().contains(query) }
                || service.pdfs(for: church.id).contains { $0.title.lowercased().contains(query) }
        }
    }
}

/// Church-first community carols browser.
public struct ChristmasCarolsListView: View {
    @State private var service = ChristmasCarolsService.shared
    @State private var viewModel = ChristmasCarolsListViewModel()
    @State private var isShowingSignInPrompt = false
    @State private var toastMessage: String?
    @State private var toastIsError = false
    
    public init() {}
    
    private var filteredChurches: [CarolChurch] {
        viewModel.filteredChurches(service.churches, service: service)
    }
    
    public var body: some View {
        @Bindable var viewModel = viewModel
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "0B2516"), Color(hex: "0D1B2A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
                customSearchBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                
                if service.isLoading && service.churches.isEmpty {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if filteredChurches.isEmpty {
                    emptyStateView
                } else {
                    churchListView
                }
            }
            
            floatingCreateButton
        }
        .navigationTitle("Community Carols")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await syncCarols() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(service.isLoading)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .refreshable { await syncCarols() }
        .sheet(isPresented: $viewModel.isShowingCreateChurch) {
            AddChurchFormView()
        }
        .alert("Sign In Required", isPresented: $isShowingSignInPrompt) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Sign in to create a church or add songs/PDFs.")
        }
        .appToast(message: $toastMessage, isError: toastIsError)
        .task { await syncCarols() }
        .onChange(of: service.lastErrorMessage) { _, msg in
            if let msg { toastMessage = msg; toastIsError = true }
        }
        .onChange(of: service.lastSuccessMessage) { _, msg in
            if let msg { toastMessage = msg; toastIsError = false }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Parish Carol Libraries")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.white)
            Text("\(service.churches.count) churches · \(service.songs.count) songs · \(service.pdfs.count) PDFs")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
            Text("1) Create a church  2) Add songs (lyrics) or PDF sheets inside it. Everyone can browse; only uploaders and admins can delete.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var customSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(.white.opacity(0.6))
            TextField("Search churches, songs, PDFs…", text: $viewModel.searchQuery)
                .foregroundColor(.white)
                .textInputAutocapitalization(.never)
            if !viewModel.searchQuery.isEmpty {
                Button { viewModel.searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
    }
    
    private var churchListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredChurches) { church in
                    NavigationLink(destination: ChurchDetailView(church: church)) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "B22222").opacity(0.25))
                                    .frame(width: 48, height: 48)
                                Text("🏛️").font(.system(size: 22))
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(church.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                HStack(spacing: 12) {
                                    Label("\(service.songs(for: church.id).count) songs", systemImage: "music.note")
                                    Label("\(service.pdfs(for: church.id).count) PDFs", systemImage: "doc.fill")
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.62))
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.35))
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.07))
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Text("🎄").font(.system(size: 48))
            Text("No churches yet")
                .font(.headline)
                .foregroundColor(.white)
            Text("Create a church first, then add songs or PDFs inside it.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Create Church") {
                if SupabaseService.instance.isAuthenticated {
                    viewModel.isShowingCreateChurch = true
                } else {
                    isShowingSignInPrompt = true
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "B22222"))
        }
        .frame(maxHeight: .infinity)
    }
    
    private var floatingCreateButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    if SupabaseService.instance.isAuthenticated {
                        viewModel.isShowingCreateChurch = true
                    } else {
                        isShowingSignInPrompt = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color(hex: "B22222"))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func syncCarols() async {
        do {
            try await service.fetchParishCarols(forceGitHub: true)
            toastMessage = service.churches.isEmpty
                ? "No churches yet. Create one to get started."
                : "Synced \(service.churches.count) churches."
            toastIsError = false
        } catch {
            toastMessage = "Couldn't sync. Pull to retry."
            toastIsError = true
        }
    }
}
