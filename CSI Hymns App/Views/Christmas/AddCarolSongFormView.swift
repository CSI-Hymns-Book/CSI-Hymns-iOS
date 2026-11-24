import SwiftUI
import Observation

@Observable
final class AddCarolSongFormViewModel {
    var title = ""
    var songNumber = ""
    var scale = "C Major"
    var lyricsKannada = ""
    var lyricsEnglish = ""
    var isSaving = false
    var errorMessage: String?
    /// Set when editing a song that already exists; nil when adding a new one.
    let editing: CarolSong?

    init(editing: CarolSong? = nil) {
        self.editing = editing
        guard let song = editing else { return }
        let parts = CarolBilingual.split(song.lyrics)
        title = song.title
        songNumber = song.songNumber ?? ""
        scale = song.scale
        lyricsKannada = parts.kannada
        lyricsEnglish = parts.english ?? ""
    }
    
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lyricsKannada.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func submit(churchId: UUID) async -> Bool {
        guard isValid else { return false }
        isSaving = true
        errorMessage = nil
        do {
            if let editing {
                _ = try await ChristmasCarolsService.shared.updateSong(
                    id: editing.id,
                    title: title,
                    songNumber: songNumber.isEmpty ? nil : songNumber,
                    lyricsKannada: lyricsKannada,
                    lyricsEnglish: lyricsEnglish,
                    scale: scale
                )
            } else {
                _ = try await ChristmasCarolsService.shared.addSong(
                    churchId: churchId,
                    title: title,
                    songNumber: songNumber.isEmpty ? nil : songNumber,
                    lyricsKannada: lyricsKannada,
                    lyricsEnglish: lyricsEnglish,
                    scale: scale.trimmingCharacters(in: .whitespaces).isEmpty ? "C Major" : scale
                )
            }
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }
}

/// Add a lyrics/text song inside an existing church, or edit one that is already there.
public struct AddCarolSongFormView: View {
    let church: CarolChurch
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddCarolSongFormViewModel
    
    public init(church: CarolChurch, editing: CarolSong? = nil) {
        self.church = church
        _viewModel = State(initialValue: AddCarolSongFormViewModel(editing: editing))
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
                            Divider().background(Color.white.opacity(0.15))
                            TextField("Scale (for example C Major)", text: $viewModel.scale)
                                .textInputAutocapitalization(.words)
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
                            Text(viewModel.isSaving ? "Saving…" : (viewModel.editing == nil ? "Add Song" : "Save changes"))
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
            .navigationTitle(viewModel.editing == nil ? "Add Song" : "Edit Song")
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
