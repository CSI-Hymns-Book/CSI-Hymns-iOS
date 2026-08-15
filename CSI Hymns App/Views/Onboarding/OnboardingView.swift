import SwiftUI

/// Structured model representing a single onboarding slide.
struct OnboardingSlide: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let description: String
    let emoji: String
    let accentColor: Color
}

/// A spectacular glassmorphic onboarding walkthrough screen.
public struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    
    private let slides = [
        OnboardingSlide(
            title: "Bilingual Devotions",
            description: "Read traditional hymns and keerthanes seamlessly in both Kannada and English translation sheets.",
            emoji: "📖",
            accentColor: Color(hex: "1976D2")
        ),
        OnboardingSlide(
            title: "Tactile Page Flip",
            description: "Swipe lyric sheets smoothly to simulate realistic page turns. Configured for high refresh rates.",
            emoji: "✨",
            accentColor: Color(hex: "E040FB")
        ),
        OnboardingSlide(
            title: "Custom Collections",
            description: "Group favorite songs in custom folders and sync them safely to the cloud to prevent data loss.",
            emoji: "📂",
            accentColor: Color(hex: "FF9800")
        ),
        OnboardingSlide(
            title: "Interactive Audios",
            description: "Stream MIDI accompaniments in the background. Supports playback rate speeds and repeat loops.",
            emoji: "🎵",
            accentColor: Color(hex: "4CAF50")
        )
    ]
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Immersive Deep Blue background
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Skip Button
                HStack {
                    Spacer()
                    Button("Skip tour") {
                        completeOnboarding()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                
                // Sliding walkthrough pages
                TabView(selection: $currentIndex) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        slideCardView(slides[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                
                // Bottom Stepper Controllers
                HStack {
                    if currentIndex < slides.count - 1 {
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                currentIndex += 1
                            }
                        } label: {
                            Text("Next")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                    } else {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Get Started")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - Subviews
    
    private func slideCardView(_ slide: OnboardingSlide) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(slide.accentColor.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .overlay(Circle().stroke(slide.accentColor.opacity(0.3), lineWidth: 1))
                
                Text(slide.emoji)
                    .font(.system(size: 64))
            }
            .padding(.top, 20)
            
            VStack(spacing: 12) {
                Text(slide.title)
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)
                
                Text(slide.description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 24)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Handlers
    
    private func completeOnboarding() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        UserDefaults.standard.set(true, forKey: "csi_has_seen_onboarding_v1")
        UserDefaults.standard.set(true, forKey: "csi_pending_menu_showcase")
        dismiss()
    }
}
