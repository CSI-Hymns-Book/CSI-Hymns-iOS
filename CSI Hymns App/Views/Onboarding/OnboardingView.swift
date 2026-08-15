import SwiftUI

/// First-run walkthrough aligned with Android onboarding, plus an in-app privacy step.
public struct OnboardingView: View {
    @Bindable private var consent = ConsentManager.shared
    @State private var currentIndex = 0
    @State private var openedLegal: LegalDocumentKind?
    @State private var welcomeVisible = false
    @State private var featureVisibleCount = 0
    
    private var needsConsent: Bool { !consent.hasValidRequiredConsent }
    private var isPolicyUpdateOnly: Bool { needsConsent && consent.hasCompletedTour }
    private var pageCount: Int {
        if isPolicyUpdateOnly { return 1 }
        return needsConsent ? 3 : 2
    }
    private var isLastPage: Bool { currentIndex >= pageCount - 1 }
    private var isPrivacyPage: Bool { needsConsent && isLastPage }
    
    private let features: [(icon: String, tint: Color, title: String, body: String)] = [
        ("book.closed.fill", Color(hex: "7EB8FF"), "Hymns & Keerthane", "Bilingual lyrics, meter sorting, and page-flip reading."),
        ("square.stack.fill", Color(hex: "F5C16C"), "Collections", "Occasions, custom folders, and songs you used recently."),
        ("music.note.list", Color(hex: "8CE0B3"), "Audio & favorites", "MIDI playback in the background — save the songs you love."),
        ("sparkles", Color(hex: "D4B5FF"), "Built for worship", "AirPlay, reports, and tools that stay out of the way.")
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "0D1B2A"), Color(hex: "163152"), Color(hex: "0D1B2A")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isPolicyUpdateOnly {
                        privacyPage
                    } else {
                        TabView(selection: $currentIndex) {
                            welcomePage.tag(0)
                            featuresPage.tag(1)
                            if needsConsent {
                                privacyPage.tag(2)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut(duration: 0.35), value: currentIndex)
                    }
                    
                    if !isPrivacyPage {
                        tourBottomBar
                            .padding(.horizontal, 20)
                            .padding(.bottom, 18)
                            .padding(.top, 8)
                    }
                }
            }
            .navigationDestination(item: $openedLegal) { kind in
                LegalDocumentView(kind: kind)
            }
            .onAppear {
                animatePage(currentIndex)
            }
            .onChange(of: currentIndex) { _, page in
                animatePage(page)
            }
        }
        .interactiveDismissDisabled(needsConsent)
    }
    
    // MARK: - Pages
    
    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()
            Image("app_logo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Color.black.opacity(0.35), radius: 18, y: 10)
                .opacity(welcomeVisible ? 1 : 0)
                .offset(y: welcomeVisible ? 0 : -36)
            
            VStack(spacing: 8) {
                Text("Welcome to")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))
                Text("CSI Hymns Book")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)
            .opacity(welcomeVisible ? 1 : 0)
            .offset(y: welcomeVisible ? 0 : 18)
            
            Text("Kannada hymns, keerthane, collections, and worship tools — organized for church and home.")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .opacity(welcomeVisible ? 1 : 0)
            
            Spacer()
        }
        .padding(.horizontal, 8)
    }
    
    private var featuresPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Everything you need")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.top, 28)
                
                Text("Browse, search, favorite, and listen — without leaving the hymn book.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.bottom, 10)
                
                ForEach(Array(features.enumerated()), id: \.offset) { index, item in
                    featureRow(icon: item.icon, tint: item.tint, title: item.title, body: item.body)
                        .opacity(featureVisibleCount > index ? 1 : 0)
                        .offset(y: featureVisibleCount > index ? 0 : 16)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 12)
        }
    }
    
    private var privacyPage: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Image("app_logo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.3), radius: 14, y: 8)
            
            Text(isPolicyUpdateOnly
                 ? (consent.language == .kannada ? "ನೀತಿ ನವೀಕರಣ" : "Policy update")
                 : (consent.language == .kannada ? "ಮುಂದುವರಿಯಿರಿ" : "One more step"))
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(.white)
                .padding(.top, 24)
            
            Text(consent.language == .kannada
                 ? "ಒಪ್ಪಿ ಒತ್ತುವ ಮೂಲಕ ನೀವು ನಮ್ಮ ಗೌಪ್ಯತಾ ನೀತಿ ಮತ್ತು ನಿಯಮಗಳನ್ನು ಒಪ್ಪುತ್ತೀರಿ."
                 : "By tapping Agree, you accept our Privacy Policy and Terms of Use.")
                .font(.system(size: 17))
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 10)
            
            HStack(spacing: 20) {
                Button {
                    openedLegal = .privacy
                } label: {
                    Text(consent.language == .kannada ? "ಗೌಪ್ಯತಾ ನೀತಿ" : "Privacy Policy")
                        .underline()
                }
                Button {
                    openedLegal = .terms
                } label: {
                    Text(consent.language == .kannada ? "ನಿಯಮಗಳು" : "Terms of Use")
                        .underline()
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color(hex: "8CE0B3"))
            .padding(.top, 18)
            
            Picker("Language", selection: $consent.language) {
                ForEach(ConsentManager.LegalLanguage.allCases) { lang in
                    Text(lang.label).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 48)
            .padding(.top, 28)
            
            Spacer()
            
            HStack(spacing: 12) {
                if !isPolicyUpdateOnly {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation { currentIndex = max(0, currentIndex - 1) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    finish()
                } label: {
                    Text(consent.language == .kannada ? "ಒಪ್ಪಿ" : "Agree")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
    }
    
    // MARK: - Bottom bar
    
    private var tourBottomBar: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentIndex ? Color.white : Color.white.opacity(0.22))
                        .frame(width: index == currentIndex ? 28 : 8, height: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentIndex)
                }
            }
            
            if !isLastPage {
                HStack {
                    Button("Skip tour") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if needsConsent {
                            withAnimation { currentIndex = pageCount - 1 }
                        } else {
                            finish()
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                    Spacer()
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { currentIndex = max(0, currentIndex - 1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .disabled(currentIndex == 0)
                .opacity(currentIndex == 0 ? 0.35 : 1)
                
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if isLastPage {
                        finish()
                    } else {
                        withAnimation { currentIndex += 1 }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isLastPage {
                            Text("Let's Go")
                            Image(systemName: "arrow.up.right")
                        } else {
                            Text("Continue")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }
    
    // MARK: - Rows
    
    private func featureRow(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(spacing: 14) {
            iconBadge(icon, tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(body)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private func iconBadge(_ icon: String, _ tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.18))
                .frame(width: 44, height: 44)
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
        }
    }
    
    // MARK: - Actions
    
    private func animatePage(_ page: Int) {
        if page == 0 {
            welcomeVisible = false
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05)) {
                welcomeVisible = true
            }
        } else if page == 1 {
            featureVisibleCount = 0
            for index in 0..<features.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08 * Double(index)) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
                        featureVisibleCount = index + 1
                    }
                }
            }
        }
    }
    
    private func finish() {
        if needsConsent {
            consent.acceptCurrentPolicy()
        }
        consent.markTourCompleted()
    }
}
