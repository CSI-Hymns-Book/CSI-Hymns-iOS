import SwiftUI
import Observation

@Observable
final class AddCarolSongFormViewModel {
    var title = ""
    var songNumber = ""
    var lyricsKannada = ""
    var lyricsEnglish = ""
    var isSaving = false
    var errorMessage: String?
    
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lyricsKannada.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func submit(churchId: UUID) async -> Bool {
        guard isValid else { return false }
        isSaving = true
        errorMessage = nil
        do {
            _ = try await ChristmasCarolsService.shared.addSong(
                churchId: churchId,
                title: title,
                songNumber: songNumber.isEmpty ? nil : songNumber,
                lyricsKannada: lyricsKannada,
                lyricsEnglish: lyricsEnglish
            )
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
}

/// Add a lyrics/text song inside an existing church.
public struct AddCarolSongFormView: View {
    let church: CarolChurch
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddCarolSongFormViewModel()
    
    public init(church: CarolChurch) {
        self.church = church
    }
    
    public var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(hex: "0B2516"), Color(hex: "1C0E0E")], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        if let err = viewModel.errorMessage {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                        
                        fieldCard {
                            TextField("Song title", text: $viewModel.title)
                                .foregroundStyle(.white)
                            Divider().background(Color.white.opacity(0.15))
                            TextField("Song number (optional)", text: $viewModel.songNumber)
                                .keyboardType(.numberPad)
                                .foregroundStyle(.white)
                        }
                        
                        fieldCard {
                            Text("Kannada lyrics")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.6))
                            TextEditor(text: $viewModel.lyricsKannada)
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 120)
                        }
                        
                        fieldCard {
                            Text("English translation (optional)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.6))
                            TextEditor(text: $viewModel.lyricsEnglish)
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 100)
                        }
                        
                        Button {
                            Task {
                                if await viewModel.submit(churchId: church.id) { dismiss() }
                            }
                        } label: {
                            Text(viewModel.isSaving ? "Saving…" : "Add Song")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(viewModel.isValid ? Color.white : Color.white.opacity(0.3))
                                .foregroundStyle(.black)
                                .cornerRadius(12)
                        }
                        .disabled(!viewModel.isValid || viewModel.isSaving)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
    }
    
    @ViewBuilder
    private func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
}
