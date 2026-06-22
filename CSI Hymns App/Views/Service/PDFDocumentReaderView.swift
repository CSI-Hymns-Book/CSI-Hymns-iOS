import SwiftUI
import PDFKit
import CryptoKit

/// Loads remote or local PDFs with disk caching (Flutter `PdfSongViewer` parity).
enum RemotePDFLoader {
    private static let cacheFolderName = "pdf_cache"
    
    static func cachedFileURL(for remoteURL: URL) -> URL {
        let hash = SHA256.hash(data: Data(remoteURL.absoluteString.utf8))
        let name = hash.compactMap { String(format: "%02x", $0) }.joined() + ".pdf"
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(cacheFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }
    
    static func loadDocument(from urlString: String) async throws -> PDFDocument {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw URLError(.badURL)
        }
        
        if url.isFileURL {
            guard let doc = PDFDocument(url: url) else { throw URLError(.cannotOpenFile) }
            return doc
        }
        
        let cacheURL = cachedFileURL(for: url)
        if FileManager.default.fileExists(atPath: cacheURL.path),
           let cached = PDFDocument(url: cacheURL) {
            return cached
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        try data.write(to: cacheURL, options: .atomic)
        guard let doc = PDFDocument(url: cacheURL) else { throw URLError(.cannotDecodeContentData) }
        return doc
    }
}

/// PDFKit view that blocks copy/share/select on document content.
public struct PDFDocumentKitView: UIViewRepresentable {
    let document: PDFDocument
    
    public init(document: PDFDocument) {
        self.document = document
    }
    
    public func makeUIView(context: Context) -> PDFView {
        let pdfView = ProtectedPDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = document
        return pdfView
    }
    
    public func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

private final class ProtectedPDFView: PDFView {
    private static let blockedActions: [Selector] = [
        #selector(copy(_:)),
        #selector(cut(_:)),
        #selector(paste(_:)),
        #selector(select(_:)),
        #selector(selectAll(_:))
    ]
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if Self.blockedActions.contains(action) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        if #available(iOS 16.0, *) {
            builder.remove(menu: .share)
            builder.remove(menu: .lookup)
        }
    }
}

/// PDF reader for carols and service documents.
public struct PDFDocumentReaderView: View {
    let documentUrlString: String
    let documentTitle: String
    
    @State private var pdfDocument: PDFDocument?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    public init(documentUrlString: String, documentTitle: String) {
        self.documentUrlString = documentUrlString
        self.documentTitle = documentTitle
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().tint(.white).scaleEffect(1.2)
                    Text("Loading PDF…")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if let pdfDocument {
                PDFDocumentKitView(document: pdfDocument)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                errorView
            }
        }
        .navigationTitle(documentTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await loadPDF() }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.35))
            Text("Couldn't load PDF")
                .font(.headline)
                .foregroundColor(.white)
            Text(errorMessage ?? "The document may be unavailable offline.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") { Task { await loadPDF() } }
                .buttonStyle(.borderedProminent)
        }
    }
    
    private func loadPDF() async {
        isLoading = true
        errorMessage = nil
        do {
            let doc = try await RemotePDFLoader.loadDocument(from: documentUrlString)
            pdfDocument = doc
        } catch {
            errorMessage = error.localizedDescription
            pdfDocument = nil
        }
        isLoading = false
    }
}
