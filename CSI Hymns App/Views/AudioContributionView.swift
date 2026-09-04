import SwiftUI
import UniformTypeIdentifiers

/// Prompt to contribute missing audio/MIDI (Android `AudioContributionDialog` parity).
public struct AudioContributionView: View {
    let songType: String
    let songNumber: Int
    let songTitle: String
    var onDismiss: () -> Void
    
    @State private var theme = ThemeManager.shared
    @State private var selectedFileName: String?
    @State private var selectedFileData: Data?
    @State private var isImporterPresented = false
    @State private var isSubmitting = false
    @State private var statusMessage: String?
    @State private var didSucceed = false
    
    public init(
        songType: String,
        songNumber: Int,
        songTitle: String,
        onDismiss: @escaping () -> Void
    ) {
        self.songType = songType
        self.songNumber = songNumber
        self.songTitle = songTitle
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("No audio is available for \"\(songTitle)\". Would you like to submit an audio or MIDI file to help improve the library for everyone?")
                    .font(.system(size: 15))
                    .foregroundColor(theme.textPrimary)
                
                if let selectedFileName {
                    HStack(spacing: 10) {
                        Image(systemName: "music.note")
                            .foregroundColor(theme.accentColor)
                        Text(selectedFileName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(12)
                    .background(theme.accentColor.opacity(0.12))
                    .cornerRadius(12)
                }
                
                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(didSucceed ? .green : .orange)
                }
                
                Spacer()
                
                if selectedFileData == nil {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Text("Select Audio File")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(theme.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                } else {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text("Submit Audio")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .background(theme.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isSubmitting)
                }
                
                Button("Cancel", role: .cancel) {
                    onDismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .padding(20)
            .background(theme.backgroundColor.ignoresSafeArea())
            .navigationTitle("No Audio Available")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: audioTypes,
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
        }
    }
    
    private var audioTypes: [UTType] {
        var types: [UTType] = [.audio, .mp3, .wav, .aiff]
        if let midi = UTType(filenameExtension: "mid") { types.append(midi) }
        if let midi2 = UTType(filenameExtension: "midi") { types.append(midi2) }
        if let ogg = UTType(filenameExtension: "ogg") { types.append(ogg) }
        if let m4a = UTType(filenameExtension: "m4a") { types.append(m4a) }
        if let flac = UTType(filenameExtension: "flac") { types.append(flac) }
        return types
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let name = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                let valid = ["mid", "midi", "mp3", "ogg", "wav", "m4a", "aac", "flac", "aiff", "caf"].contains(ext)
                guard valid else {
                    statusMessage = "Please select an audio file (e.g. .mp3, .ogg, .wav, .mid)"
                    didSucceed = false
                    return
                }
                selectedFileData = data
                selectedFileName = name
                statusMessage = nil
            } catch {
                statusMessage = "Could not read file data"
                didSucceed = false
            }
        case .failure(let error):
            statusMessage = error.localizedDescription
            didSucceed = false
        }
    }
    
    private func submit() async {
        guard let data = selectedFileData, let name = selectedFileName else { return }
        isSubmitting = true
        statusMessage = "Uploading audio contribution..."
        didSucceed = false
        
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let result = await JiraService.shared.createTicket(
            songType: songType,
            songNumber: songNumber,
            songTitle: songTitle,
            description: "User contributed audio file: \(name) for this song. Please review and add to raw assets.",
            appVersion: version,
            isAudioContribution: true
        )
        
        if result.success, let key = result.ticketKey {
            let uploaded = await JiraService.shared.uploadAttachment(
                ticketKey: key,
                fileData: data,
                fileName: name
            )
            if uploaded {
                statusMessage = "Thank you! Audio contribution ticket \(key) submitted."
                didSucceed = true
                try? await Task.sleep(for: .seconds(1.4))
                onDismiss()
            } else {
                statusMessage = "Ticket created (\(key)) but file attachment upload failed."
                didSucceed = false
            }
        } else {
            statusMessage = "Failed to submit contribution: \(result.errorMessage ?? "Unknown error")"
            didSucceed = false
        }
        isSubmitting = false
    }
}
