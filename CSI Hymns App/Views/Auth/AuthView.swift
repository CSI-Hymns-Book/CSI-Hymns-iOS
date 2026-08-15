import SwiftUI
import Observation

/// Auth view-model driver managing inputs, form validation, and Supabase integration.
@MainActor
@Observable
public final class AuthViewModel {
    public var email = ""
    public var password = ""
    public var fullName = ""
    public var isSignUp = false
    public var acceptPrivacy = false
    public var acceptTerms = false
    public var isLoading = false
    public var errorMessage: String? = nil
    public var resetEmailSent = false
    
    public init() {}
    
    public var isFormValid: Bool {
        guard !email.isEmpty, email.contains("@") else { return false }
        guard password.count >= 6 else { return false }
        if isSignUp {
            guard !fullName.isEmpty else { return false }
            guard acceptPrivacy, acceptTerms else { return false }
        } else {
            guard ConsentManager.shared.hasValidRequiredConsent else { return false }
        }
        return true
    }
    
    public func authenticate() async -> Bool {
        guard isFormValid else { return false }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let svc = SupabaseService.instance
            if isSignUp {
                try await svc.signUp(email: email, password: password, fullName: fullName)
            } else {
                try await svc.signIn(email: email, password: password)
            }
            await svc.syncConsentFromLocalPrefs()
            isLoading = false
            return true
        } catch {
            isLoading = false
            let nsError = error as NSError
            errorMessage = error.localizedDescription
            
            let generator = UINotificationFeedbackGenerator()
            if nsError.domain == "SupabaseService" && nsError.code == 201 {
                generator.notificationOccurred(.success)
            } else {
                generator.notificationOccurred(.error)
            }
            return false
        }
    }
    
    public func sendPasswordReset() async -> Bool {
        guard email.contains("@") else {
            errorMessage = "Enter your email address first."
            return false
        }
        isLoading = true
        errorMessage = nil
        do {
            try await SupabaseService.instance.sendPasswordResetEmail(email)
            resetEmailSent = true
            errorMessage = "Password reset email sent. Check your inbox."
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
}

/// A spectacular glassmorphic authentication terminal.
public struct AuthView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AuthViewModel()
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Immersive Dark Glass Background Gradients
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "132237"), Color(hex: "0D1B2A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                        .padding(.top, 40)
                    
                    formCard
                    
                    oAuthDividersRow
                    
                    oAuthButtonsStack
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image("app_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 10, y: 4)
            
            VStack(spacing: 4) {
                Text(viewModel.isSignUp ? "Create Account" : "Welcome Back")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                
                Text(viewModel.isSignUp ? "Join us to sync your custom collections" : "Sign in to keep your data synced")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var formCard: some View {
        VStack(spacing: 18) {
            if let error = viewModel.errorMessage {
                let isSuccess = error.contains("successful") || error.contains("successful!") || error.contains("Confirmation")
                HStack(spacing: 8) {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isSuccess ? Color.green : Color(hex: "F44336"))
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSuccess ? Color.green : Color(hex: "F44336"))
                        .lineLimit(4)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((isSuccess ? Color.green : Color(hex: "F44336")).opacity(0.12))
                .cornerRadius(12)
                .transition(.opacity)
            }
            
            // Name Field (Sign Up Only)
            if viewModel.isSignUp {
                customTextField(
                    placeholder: "Full Name",
                    text: $viewModel.fullName,
                    systemImage: "person"
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Email Field
            customTextField(
                placeholder: "Email Address",
                text: $viewModel.email,
                systemImage: "envelope",
                keyboardType: .emailAddress
            )
            
            // Password Field
            customSecureField(
                placeholder: "Password (Min 6 chars)",
                text: $viewModel.password,
                systemImage: "lock"
            )
            
            // Privacy + Terms (Sign Up — account data is additional processing)
            if viewModel.isSignUp {
                privacyAgreementRow
            }
            
            // Submit Button
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                
                Task {
                    if await viewModel.authenticate() {
                        Task {
                            await FavoritesManager.shared.syncWithRemote()
                            await CustomCategoriesViewModel.syncAfterSignIn()
                            await ConsentManager.shared.syncToProfile()
                            await ChristmasCarolsService.shared.syncAfterSignIn()
                        }
                        dismiss()
                    }
                }
            } label: {
                ZStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text(viewModel.isSignUp ? "Sign Up" : "Sign In")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.isFormValid ? Color.white : Color.white.opacity(0.3))
                .cornerRadius(14)
            }
            .disabled(!viewModel.isFormValid || viewModel.isLoading)
            
            if !viewModel.isSignUp {
                Button {
                    Task { _ = await viewModel.sendPasswordReset() }
                } label: {
                    Text("Forgot password?")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                }
                .disabled(viewModel.isLoading || viewModel.email.isEmpty)
            }
            
            // Toggle form state button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    viewModel.isSignUp.toggle()
                    viewModel.errorMessage = nil
                }
            } label: {
                Text(viewModel.isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
    
    private var privacyAgreementRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                viewModel.acceptPrivacy.toggle()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: viewModel.acceptPrivacy ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundColor(viewModel.acceptPrivacy ? .white : .white.opacity(0.4))
                    Text("I consent to processing of my account data as described in the Privacy Policy.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
            }
            Button {
                viewModel.acceptTerms.toggle()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: viewModel.acceptTerms ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundColor(viewModel.acceptTerms ? .white : .white.opacity(0.4))
                    Text("I accept the Terms of Use.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }
            }
            HStack(spacing: 16) {
                NavigationLink(destination: LegalDocumentView(kind: .privacy)) {
                    Text("Privacy Policy")
                        .font(.system(size: 12))
                        .underline()
                }
                NavigationLink(destination: LegalDocumentView(kind: .terms)) {
                    Text("Terms of Use")
                        .font(.system(size: 12))
                        .underline()
                }
            }
            .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
    
    private var oAuthDividersRow: some View {
        HStack {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            Text("or continue with")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 8)
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
        }
    }
    
    private var oAuthButtonsStack: some View {
        VStack(spacing: 12) {
            // Apple OAuth
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                
                Task {
                    viewModel.isLoading = true
                    viewModel.errorMessage = nil
                    do {
                        try await SupabaseService.instance.signInWithAppleNative()
                        await FavoritesManager.shared.syncWithRemote()
                        await CustomCategoriesViewModel.syncAfterSignIn()
                        await ConsentManager.shared.syncToProfile()
                        await ChristmasCarolsService.shared.syncAfterSignIn()
                        await SupabaseService.instance.refreshDisplayName()
                        viewModel.isLoading = false
                        dismiss()
                    } catch {
                        viewModel.isLoading = false
                        // Don't show cancel error message if user dismissed sheets
                        let errStr = error.localizedDescription
                        if !errStr.contains("canceled") && !errStr.contains("cancelled") {
                            viewModel.errorMessage = errStr
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.error)
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18))
                    Text("Sign in with Apple")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
            
            // Google OAuth
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                
                Task {
                    viewModel.isLoading = true
                    viewModel.errorMessage = nil
                    do {
                        try await SupabaseService.instance.signInWithProvider("google")
                        await FavoritesManager.shared.syncWithRemote()
                        await CustomCategoriesViewModel.syncAfterSignIn()
                        await ConsentManager.shared.syncToProfile()
                        await ChristmasCarolsService.shared.syncAfterSignIn()
                        await SupabaseService.instance.refreshDisplayName()
                        viewModel.isLoading = false
                        dismiss()
                    } catch {
                        viewModel.isLoading = false
                        let errStr = error.localizedDescription
                        if !errStr.contains("canceled") && !errStr.contains("cancelled") {
                            viewModel.errorMessage = errStr
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.error)
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                    Text("Continue with Google")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
        }
    }
    
    // MARK: - Reusable Custom Fields
    
    private func customTextField(
        placeholder: String,
        text: Binding<String>,
        systemImage: String,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 20)
            
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.35)))
                .foregroundColor(.white)
                .accentColor(.white)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.none)
                .autocorrectionDisabled()
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
    
    private func customSecureField(
        placeholder: String,
        text: Binding<String>,
        systemImage: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 20)
            
            SecureField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.35)))
                .foregroundColor(.white)
                .accentColor(.white)
                .textInputAutocapitalization(.none)
                .autocorrectionDisabled()
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}
