import SwiftUI
import PDFKit

/// Native UIKit wrapper for loading and zooming PDF documents inside SwiftUI.
public struct PDFDocumentKitView: UIViewRepresentable {
    let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        // Asynchronously load the PDF from remote or local storage
        DispatchQueue.global(qos: .userInitiated).async {
            if let document = PDFDocument(url: url) {
                DispatchQueue.main.async {
                    pdfView.document = document
                }
            }
        }
        
        return pdfView
    }
    
    public func updateUIView(_ uiView: PDFView, context: Context) {}
}

/// A spectacular, high-end PDF songbook and music sheet reader.
public struct PDFDocumentReaderView: View {
    let documentUrlString: String
    let documentTitle: String
    
    @State private var isLoading = true
    @State private var isShowingShareSheet = false
    
    public init(documentUrlString: String, documentTitle: String) {
        self.documentUrlString = documentUrlString
        self.documentTitle = documentTitle
    }
    
    private var verifiedURL: URL? {
        URL(string: documentUrlString)
    }
    
    public var body: some View {
        ZStack {
            // Pure AMOLED dark background
            Color.black
                .ignoresSafeArea()
            
            VStack {
                if let url = verifiedURL {
                    ZStack {
                        PDFDocumentKitView(url: url)
                            .ignoresSafeArea(edges: .bottom)
                            .onAppear {
                                // Simulate completion of async load
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    isLoading = false
                                }
                            }
                        
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                        }
                    }
                } else {
                    invalidUrlView
                }
            }
        }
        .navigationTitle(documentTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let url = verifiedURL {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private var invalidUrlView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Invalid Document URL")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            Text("The requested PDF file path is corrupted or unavailable.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
