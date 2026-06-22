import SwiftUI
import UniformTypeIdentifiers

/// Upload a PDF sheet inside an existing church (opens directly in PDF reader).
public struct AddCarolPdfFormView: View {
    let church: CarolChurch
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var songNumber = ""
    @State private var pdfData: Data?
    @State private var pdfFileName: String?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isShowingImporter = false
    
    public init(church: CarolChurch) {
        self.church = church
    }
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pdfData != nil
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(hex: "0B2516"), Color(hex: "1C0E0E")], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    TextField("PDF title", text: $title)
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                    
                    TextField("Song number (optional)", text: $songNumber)
                        .keyboardType(.numberPad)
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                    
                    Button { isShowingImporter = true } label: {
                        HStack {
                            Image(systemName: "doc.fill")
                            Text(pdfFileName ?? "Choose PDF file")
                                .lineLimit(1)
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                    }
                    
                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                    
                    Spacer()
                    
                    Button { Task { await save() } } label: {
                        Text(isSaving ? "Uploading…" : "Upload PDF")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isValid ? Color.white : Color.white.opacity(0.3))
                            .foregroundStyle(.black)
                            .cornerRadius(12)
                    }
                    .disabled(!isValid || isSaving)
                }
                .padding(20)
            }
            .navigationTitle("Add PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
            }
            .fileImporter(isPresented: $isShowingImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: url) {
                        pdfData = data
                        pdfFileName = url.lastPathComponent
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func save() async {
        guard let pdfData else { return }
        isSaving = true
        errorMessage = nil
        do {
            _ = try await ChristmasCarolsService.shared.addPdf(
                churchId: church.id,
                title: title,
                songNumber: songNumber.isEmpty ? nil : songNumber,
                pdfData: pdfData
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
