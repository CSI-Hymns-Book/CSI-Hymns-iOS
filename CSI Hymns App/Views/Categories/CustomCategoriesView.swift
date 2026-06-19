import SwiftUI
import Observation

/// Structured model representing a user-designed playlist folder of hymns.
public struct CustomCategory: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var songIds: [String] // Format "hymn_1", "keerthane_25" etc.
    public let createdAt: Date
}

/// View model tracking guest collection thresholds (max 5) and Supabase synchronizations.
@Observable
public final class CustomCategoriesViewModel {
    public var categories: [CustomCategory] = []
    public var isShowingCreateDialog = false
    public var newCategoryName = ""
    public var limitAlert = false
    
    private let storageKey = "csi_custom_categories_local_v1"
    
    public init() {
        loadCategories()
    }
    
    public func createCategory() -> Bool {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        
        let svc = SupabaseService.instance
        if !svc.isAuthenticated && categories.count >= 5 {
            // Enforce guest threshold limit of 5
            limitAlert = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            return false
        }
        
        let newCat = CustomCategory(
            id: UUID().uuidString,
            name: name,
            songIds: [],
            createdAt: Date()
        )
        
        categories.append(newCat)
        saveCategories()
        
        newCategoryName = ""
        isShowingCreateDialog = false
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        return true
    }
    
    public func deleteCategory(at offsets: IndexSet) {
        categories.remove(atOffsets: offsets)
        saveCategories()
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func loadCategories() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CustomCategory].self, from: data) {
            self.categories = decoded
        } else {
            // Seed a starter sample for visual layout demonstration
            self.categories = [
                CustomCategory(id: "seed_1", name: "Sunday Morning Praise", songIds: ["hymn_1", "hymn_25"], createdAt: Date()),
                CustomCategory(id: "seed_2", name: "Lent Meditations", songIds: ["hymn_110"], createdAt: Date().addingTimeInterval(-86400 * 3))
            ]
        }
    }
    
    private func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}

/// A premium glassmorphic user categories dashboard.
public struct CustomCategoriesView: View {
    @State private var viewModel = CustomCategoriesViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Immersive deep blue background
                LinearGradient(
                    colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack {
                    if viewModel.categories.isEmpty {
                        emptyStateView
                    } else {
                        categoriesList
                    }
                }
                
                // Add Playlist Floating Button
                if !viewModel.isShowingCreateDialog {
                    floatingAddButton
                }
                
                // Custom creation overlay dialog
                if viewModel.isShowingCreateDialog {
                    createCategoryOverlay
                }
            }
            .navigationTitle("My Collections")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Guest Limit Reached", isPresented: &viewModel.limitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Guest accounts are limited to 5 custom folders. Please sign up or login to unlock unlimited collection syncs!")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 54))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No Custom Folders")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text("Create custom lists to group your favorite hymns and keerthanes for services or special devotions.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var categoriesList: some View {
        List {
            ForEach(viewModel.categories) { category in
                NavigationLink(destination: CustomCategorySongsListView(categoryId: category.id)) { 
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 42, height: 42)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
                            
                            Image(systemName: "folder.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.yellow.opacity(0.8))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("\(category.songIds.count) songs")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.white.opacity(0.04))
            }
            .onDelete(perform: viewModel.deleteCategory)
        }
        .scrollContentBackground(.hidden)
        .foregroundColor(.white)
        .padding(.top, 4)
    }
    
    private var floatingAddButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.isShowingCreateDialog = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("Create List")
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
    
    private var createCategoryOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.isShowingCreateDialog = false
                    }
                }
            
            VStack(spacing: 20) {
                Text("New Collection")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                TextField("", text: $viewModel.newCategoryName, prompt: Text("Folder Name (e.g. Easter Choir)").foregroundColor(.white.opacity(0.35)))
                    .foregroundColor(.white)
                    .accentColor(.white)
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
                
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.isShowingCreateDialog = false
                        }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    Button {
                        _ = viewModel.createCategory()
                    } label: {
                        Text("Create")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "0D1B2A"))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 1))
            )
            .padding(.horizontal, 36)
        }
    }
}
