import SwiftUI
import Observation

/// View model driving the upload configurations and input validations.
@Observable
public final class AddCarolFormViewModel {
    public var title = ""
    public var parish = ""
    public var lyricsKannada = ""
    public var lyricsEnglish = ""
    public var submitterName = ""
    public var isUploading = false
    public var errorMessage: String? = nil
    
    public init() {}
    
    public var isFormValid: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !parish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !lyricsKannada.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !submitterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return true
    }
    
    public func submitCarol() async -> Bool {
        guard isFormValid else { return false }
        
        isUploading = true
        errorMessage = nil
        
        do {
            try await ChristmasCarolsService.shared.uploadNewCarol(
                title: title,
                parish: parish,
                lyrics: lyricsKannada,
                lyricsEnglish: lyricsEnglish,
                submitter: submitterName
            )
            
            isUploading = false
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            return true
        } catch {
            isUploading = false
            errorMessage = error.localizedDescription
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return false
        }
    }
}

/// A spectacular, festive custom carol registration form sheet.
public struct AddCarolFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddCarolFormViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Festive emerald and ruby background style
                LinearGradient(
                    colors: [Color(hex: "0B2516"), Color(hex: "1C0E0E")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if let err = viewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(err)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color.red.opacity(0.12))
                            .cornerRadius(12)
                        }
                        
                        // Fields Card
                        VStack(spacing: 16) {
                            customField(placeholder: "Carol Title", text: $viewModel.title, icon: "text.alignleft")
                            customField(placeholder: "Parish / Church Name", text: $viewModel.parish, icon: "house.fill")
                            customField(placeholder: "Your Name (Submitter)", text: $viewModel.submitterName, icon: "person.fill")
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Lyrics (Kannada)*")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                TextEditor(text: $viewModel.lyricsKannada)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(10)
                                    .frame(height: 120)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Lyrics (English Translation - Optional)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                TextEditor(text: $viewModel.lyricsEnglish)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(10)
                                    .frame(height: 120)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        
                        // Submit Button
                        Button {
                            Task {
                                if await viewModel.submitCarol() {
                                    dismiss()
                                }
                            }
                        } label: {
                            ZStack {
                                if viewModel.isUploading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text("Upload Carol")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(viewModel.isFormValid ? Color.white : Color.white.opacity(0.3))
                            .cornerRadius(12)
                        }
                        .disabled(!viewModel.isFormValid || viewModel.isUploading)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Upload Carol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func customField(placeholder: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 20)
            
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.35)))
                .foregroundColor(.white)
                .accentColor(.white)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}
