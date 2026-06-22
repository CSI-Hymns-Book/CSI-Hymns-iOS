import SwiftUI

/// Create a parish/church first — songs and PDFs are added inside later.
public struct AddChurchFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0B2516"), Color(hex: "1C0E0E")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                Form {
                    Section("Church") {
                        TextField("Church / Parish name", text: $name)
                        TextField("Description (optional)", text: $description, axis: .vertical)
                            .lineLimit(2...4)
                    }
                    
                    if let errorMessage {
                        Section {
                            Text(errorMessage).foregroundStyle(.red)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Create Church")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await save() } }
                        .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            _ = try await ChristmasCarolsService.shared.createChurch(
                name: name,
                description: description.isEmpty ? nil : description
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
