import SwiftUI

/// Blocking DPDP notice + consent. Cannot be dismissed until required boxes are checked.
public struct ConsentGateView: View {
    @State private var theme = ThemeManager.shared
    @Bindable private var consent = ConsentManager.shared
    @State private var privacyAccepted = false
    @State private var termsAccepted = false
    @State private var ageConfirmed = false
    @State private var analyticsOptIn = false
    @State private var pushOptIn = false
    
    public init() {}
    
    private var canAccept: Bool {
        privacyAccepted && termsAccepted && ageConfirmed
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    Picker("Language", selection: $consent.language) {
                        ForEach(ConsentManager.LegalLanguage.allCases) { lang in
                            Text(lang.label).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(consent.language == .kannada ? LegalDocuments.noticeKannada : LegalDocuments.noticeEnglish)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.86))
                                .lineSpacing(5)
                                .padding(16)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(16)
                            
                            NavigationLink(destination: LegalDocumentView(kind: .privacy)) {
                                docLinkLabel(
                                    title: consent.language == .kannada ? "ಪೂರ್ಣ ಗೌಪ್ಯತಾ ನೀತಿ" : "Read full Privacy Policy",
                                    icon: "lock.shield"
                                )
                            }
                            NavigationLink(destination: LegalDocumentView(kind: .terms)) {
                                docLinkLabel(
                                    title: consent.language == .kannada ? "ಪೂರ್ಣ ಬಳಕೆಯ ನಿಯಮಗಳು" : "Read full Terms of Use",
                                    icon: "doc.text"
                                )
                            }
                            
                            consentCheckbox(
                                isOn: $privacyAccepted,
                                title: consent.language == .kannada
                                    ? "ನಾನು ಗೌಪ್ಯತಾ ನೀತಿಯನ್ನು ಓದಿದ್ದೇನೆ ಮತ್ತು ಖಾತೆ/ಬೆಂಬಲಕ್ಕೆ ಅಗತ್ಯವಾದ ಸಂಸ್ಕರಣೆಗೆ ಸಮ್ಮತಿಸುತ್ತೇನೆ."
                                    : "I have read the Privacy Policy and consent to the necessary processing described in the notice."
                            )
                            consentCheckbox(
                                isOn: $termsAccepted,
                                title: consent.language == .kannada
                                    ? "ನಾನು ಬಳಕೆಯ ನಿಯಮಗಳನ್ನು ಒಪ್ಪುತ್ತೇನೆ."
                                    : "I accept the Terms of Use."
                            )
                            consentCheckbox(
                                isOn: $ageConfirmed,
                                title: consent.language == .kannada
                                    ? "ನಾನು ೧೮ ವರ್ಷ ಅಥವಾ ಹೆಚ್ಚು, ಅಥವಾ ನಾನು ಪೋಷಕ/ಪಾಲಕನಾಗಿ ಸಮ್ಮತಿಸುತ್ತೇನೆ."
                                    : "I am 18 or older, or I am a parent/guardian consenting for a minor."
                            )
                            
                            Text(consent.language == .kannada ? "ಐಚ್ಛಿಕ (ಮುಂತಿಳಿಸಿ ಆಯ್ಕೆ ಇಲ್ಲ)" : "Optional — off unless you tick")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.45))
                                .padding(.top, 8)
                            
                            consentCheckbox(
                                isOn: $analyticsOptIn,
                                title: consent.language == .kannada
                                    ? "ಆ್ಯಪ್ ಸುಧಾರಣೆಗಾಗಿ ಐಚ್ಛಿಕ ವಿಶ್ಲೇಷಣೆ (PostHog) — ಗೀತೆ ಓದಲು ಅಗತ್ಯವಿಲ್ಲ."
                                    : "Optional analytics (PostHog) to improve the app. Not required to read hymns."
                            )
                            consentCheckbox(
                                isOn: $pushOptIn,
                                title: consent.language == .kannada
                                    ? "ಐಚ್ಛಿಕ ಪುಶ್ ಸೂಚನೆಗಳು — ಗೀತೆ ಓದಲು ಅಗತ್ಯವಿಲ್ಲ."
                                    : "Optional push notifications. Not required to read hymns."
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    
                    Button {
                        consent.acceptRequiredConsent(
                            analytics: analyticsOptIn,
                            push: pushOptIn,
                            ageConfirmed: ageConfirmed,
                            privacyAccepted: privacyAccepted,
                            termsAccepted: termsAccepted
                        )
                    } label: {
                        Text(consent.language == .kannada ? "ಸಮ್ಮತಿಸಿ ಮತ್ತು ಮುಂದುವರಿಸಿ" : "Agree and continue")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(canAccept ? Color.white : Color.white.opacity(0.28))
                            .cornerRadius(14)
                    }
                    .disabled(!canAccept)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled(true)
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            Text("🔒")
                .font(.system(size: 40))
            Text(consent.language == .kannada ? "ಗೌಪ್ಯತೆ ಮತ್ತು ಸಮ್ಮತಿ" : "Privacy notice")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)
            Text(consent.language == .kannada
                 ? "ಆ್ಯಪ್ ಬಳಸುವ ಮೊದಲು ಈ ಸೂಚನೆಯನ್ನು ಓದಿ. ಸ್ಕಿಪ್ ಮಾಡಲು ಸಾಧ್ಯವಿಲ್ಲ."
                 : "Please read this notice before using the app. This step cannot be skipped.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
    
    private func docLinkLabel(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(14)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
    
    private func consentCheckbox(isOn: Binding<Bool>, title: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(isOn.wrappedValue ? .white : .white.opacity(0.35))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}
