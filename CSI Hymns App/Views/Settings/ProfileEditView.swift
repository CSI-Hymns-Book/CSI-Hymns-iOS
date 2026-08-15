import SwiftUI
import UIKit

/// Account profile: name, email, download stored information, and soft-deactivate.
public struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var theme = ThemeManager.shared
    @State private var supabase = SupabaseService.instance
    @State private var fullName = ""
    @State private var email = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var isExporting = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var shareItem: IdentifiableURL?
    
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
                    Section {
                        TextField("Full name", text: $fullName)
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(email.isEmpty ? "—" : email)
                                .foregroundStyle(theme.textSecondary)
                                .multilineTextAlignment(.trailing)
                        }
                    } header: {
                        Text("Profile")
                    } footer: {
                        Text("Email comes from your sign-in and cannot be changed here. We do not store a profile picture.")
                    }
                    
                    Section {
                        Button {
                            Task { await saveProfile() }
                        } label: {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Save name")
                            }
                        }
                        .disabled(fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    }
                    
                    Section {
                        Button {
                            Task { await downloadMyInformation() }
                        } label: {
                            HStack {
                                if isExporting {
                                    ProgressView()
                                } else {
                                    Label("Download my information", systemImage: "square.and.arrow.down")
                                }
                            }
                        }
                        .disabled(isExporting)
                    } footer: {
                        Text("We’ll pack the data we store about you into a zip file. You can download this once every 15 minutes.")
                    }
                    
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            if isDeleting {
                                ProgressView().tint(.red)
                            } else {
                                Text("Deactivate account")
                            }
                        }
                        .disabled(isDeleting)
                    } footer: {
                        Text("This signs you out and marks the account as deactivated. Your record is kept internally and is not permanently erased.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Deactivate this account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Deactivate", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("You will be signed out. The account stays in our records as deactivated. This is not a permanent erase.")
        }
        .alert("Couldn’t complete", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $shareItem) { item in
            ActivityShareSheet(items: [item.url])
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
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
    
    private func downloadMyInformation() async {
        isExporting = true
        do {
            shareItem = IdentifiableURL(url: try await supabase.exportMyDataZipURL())
        } catch {
            if SupabaseService.isDataExportRateLimited(error) {
                errorMessage = "Please wait 15 minutes before downloading your information again."
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isExporting = false
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

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
            popover.permittedArrowDirections = []
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
