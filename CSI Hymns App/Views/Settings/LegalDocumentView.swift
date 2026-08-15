import SwiftUI

/// In-app Privacy Policy and Terms, with English / Kannada (DPDP language option).
public struct LegalDocumentView: View {
    let kind: LegalDocumentKind
    @State private var theme = ThemeManager.shared
    @Bindable private var consent = ConsentManager.shared
    
    public init(kind: LegalDocumentKind) {
        self.kind = kind
    }
    
    public var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            if theme.activeTheme != .amoled {
                theme.backgroundGradient.ignoresSafeArea()
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Language", selection: $consent.language) {
                        ForEach(ConsentManager.LegalLanguage.allCases) { lang in
                            Text(lang.label).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Version \(ConsentManager.currentPolicyVersion)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                    
                    ForEach(LegalDocuments.sections(for: kind, language: consent.language)) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.heading)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(theme.textPrimary)
                            Text(section.body)
                                .font(.system(size: 14))
                                .foregroundColor(theme.textSecondary)
                                .lineSpacing(5)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.cardBackground)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(theme.cardStroke, lineWidth: 1)
                        )
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(kind.title(language: consent.language))
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        .toolbar(.hidden, for: .tabBar)
    }
}

public struct PrivacyPolicyView: View {
    public init() {}
    public var body: some View {
        LegalDocumentView(kind: .privacy)
    }
}

public struct TermsOfUseView: View {
    public init() {}
    public var body: some View {
        LegalDocumentView(kind: .terms)
    }
}
