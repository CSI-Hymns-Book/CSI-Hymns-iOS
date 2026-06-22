import SwiftUI

/// Profile editing screen — display name, account deletion (Flutter parity).
public struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var theme = ThemeManager.shared
    @State private var supabase = SupabaseService.instance
    @State private var fullName = ""
    @State private var email = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    
    public init() {}
    
    public var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            if theme.activeTheme != .amoled {
                theme.backgroundGradient.ignoresSafeArea()
            }
            
            if isLoading {
                ProgressView().tint(theme.accentColor)
            } else {
                Form {
                    Section("Profile") {
                        TextField("Full name", text: $fullName)
                        Text(email)
                            .foregroundStyle(theme.textSecondary)
                    }
                    
                    Section {
                        Button {
                            Task { await saveProfile() }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Save Changes")
                            }
                        }
                        .disabled(fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    }
                    
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            if isDeleting {
                                ProgressView().tint(.red)
                            } else {
                                Text("Delete Account")
                            }
                        }
                        .disabled(isDeleting)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This permanently deletes your account and cannot be undone.")
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task { await loadProfile() }
    }
    
    private func loadProfile() async {
        email = supabase.currentUserEmail ?? ""
        if let name = await supabase.getProfileName() {
            fullName = name
        } else {
            fullName = supabase.currentUser?.fullName ?? ""
        }
        isLoading = false
    }
    
    private func saveProfile() async {
        isSaving = true
        do {
            try await supabase.upsertProfile(fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
    
    private func deleteAccount() async {
        isDeleting = true
        do {
            try await supabase.deleteUserAccount()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isDeleting = false
    }
}
