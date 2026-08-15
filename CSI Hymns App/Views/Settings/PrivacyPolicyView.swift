import SwiftUI
import WebKit

/// In-app Privacy Policy WebView (Android `PrivacyPolicyScreen` parity).
public struct PrivacyPolicyView: View {
    @State private var theme = ThemeManager.shared
    @State private var isLoading = true
    
    public static let policyURL = URL(string: "https://sites.google.com/view/csi-hymns-privacy-policy/home")!
    
    public init() {}
    
    public var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            
            PrivacyWebView(url: Self.policyURL, isLoading: $isLoading)
            
            if isLoading {
                ProgressView()
                    .tint(theme.accentColor)
            }
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct PrivacyWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        
        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}
