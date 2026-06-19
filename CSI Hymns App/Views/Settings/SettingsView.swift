import SwiftUI

/// A premium, glassmorphic settings panel with native configurations.
public struct SettingsView: View {
    @State private var supabase = SupabaseService.instance
    @State private var isShowingDeleteAlert = false
    @State private var isDeletingAccount = false
    
    // Core Preferences saved reactively via AppStorage
    @AppStorage("use_page_swipe_physics") private var usePageSwipe = true
    @AppStorage("enable_amoled_mode") private var enableAmoled = false
    @AppStorage("enable_haptic_feedback") private var enableHaptics = true
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // AMOLED dark style matching user preference selections
                Group {
                    if enableAmoled {
                        Color.black
                    } else {
                        LinearGradient(
                            colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .ignoresSafeArea()
                
                List {
                    // Profile Header card
                    Section {
                        profileCard
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                    
                    // App Preferences Toggles
                    Section(header: Text("Appearance & Interaction").foregroundColor(.white.opacity(0.6))) {
                        Toggle(isOn: $usePageSwipe) {
                            settingsRowLabel(title: "Page Swipe Transitions", subtitle: "Use Swipable lyric sheets", iconName: "book.pages")
                        }
                        
                        Toggle(isOn: $enableAmoled) {
                            settingsRowLabel(title: "AMOLED Black Mode", subtitle: "Pure black color styles for OLEDs", iconName: "moon.stars")
                        }
                        
                        Toggle(isOn: $enableHaptics) {
                            settingsRowLabel(title: "Tactile Haptics", subtitle: "Dynamic vibration feedback", iconName: "waveform")
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                    
                    // Support & Issue Logs
                    Section(header: Text("Support & Data").foregroundColor(.white.opacity(0.6))) {
                        NavigationLink(destination: TicketsListView()) {
                            settingsRowLabel(title: "Reported Issues Log", subtitle: "Track lyric corrections status", iconName: "exclamationmark.bubble")
                        }
                        
                        Button {
                            // Clear Caches & History logs
                            RecentSongsService.shared.clearAllRecents()
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        } label: {
                            settingsRowLabel(title: "Clear Caches & History", subtitle: "Flush local indices and logs", iconName: "trash")
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                    
                    // About & Promos
                    Section(header: Text("About").foregroundColor(.white.opacity(0.6))) {
                        NavigationLink(destination: AboutDeveloperView()) {
                            settingsRowLabel(title: "About Developer", subtitle: "Credits, mission, and privacy links", iconName: "person.crop.circle")
                        }
                        
                        NavigationLink(destination: PraiseAppPromoView()) {
                            settingsRowLabel(title: "Related Devotions", subtitle: "Download Praise App suite", iconName: "sparkles")
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                    
                    // Account deletion option
                    if supabase.isAuthenticated {
                        Section {
                            Button(role: .destructive) {
                                isShowingDeleteAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    if isDeletingAccount {
                                        ProgressView()
                                            .tint(.red)
                                    } else {
                                        Text("Delete Account")
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .listRowBackground(Color.red.opacity(0.1))
                    }
                }
                .scrollContentBackground(.hidden)
                .foregroundColor(.white)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete Account?", isPresented: &isShowingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Everything", role: .destructive) {
                    Task {
                        await deleteAccountCascade()
                    }
                }
            } message: {
                Text("This action cannot be undone. All your custom category lists, bookmarks, and account profiles will be wiped off Supabase servers instantly.")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var profileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 58, height: 58)
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                
                Text(supabase.isAuthenticated ? "👤" : "🔒")
                    .font(.system(size: 26))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if supabase.isAuthenticated {
                    Text(supabase.currentUser?.fullName ?? "CSI Devotional User")
                        .font(.system(size: 16, weight: .bold))
                    Text(supabase.currentUserEmail ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("Guest Account")
                        .font(.system(size: 16, weight: .bold))
                    Text("Sign in to merge custom categories")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Spacer()
            
            if supabase.isAuthenticated {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    Task {
                        try? await supabase.signOut()
                    }
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                NavigationLink(destination: AuthView()) {
                    Text("Sign In")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
    
    private func settingsRowLabel(title: String, subtitle: String, iconName: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 34, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
                
                Image(systemName: iconName)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    private func deleteAccountCascade() async {
        isDeletingAccount = true
        do {
            try await supabase.deleteUserAccount()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("SettingsView: Deletion failed: \(error)")
        }
        isDeletingAccount = false
    }
}
