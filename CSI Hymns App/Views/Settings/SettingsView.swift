import SwiftUI

/// A premium, glassmorphic settings panel with native configurations.
public struct SettingsView: View {
    @State private var theme = ThemeManager.shared
    @State private var supabase = SupabaseService.instance
    @State private var christmas = ChristmasModeService.shared
    @State private var pageFlipVisibility = PageFlipVisibilityService.shared
    @State private var isShowingDeleteAlert = false
    @State private var isDeletingAccount = false
    @State private var isShowingClearCacheAlert = false
    @State private var isShowingClearHistoryAlert = false
    @State private var isClearing = false
    @State private var privacyAccepted = true
    @State private var updateInfo: AppStoreUpdateService.UpdateInfo?
    @State private var showUpToDateAlert = false
    
    // Core Preferences saved reactively via AppStorage
    @AppStorage("use_page_swipe_physics") private var usePageSwipe = true
    @AppStorage("enable_haptic_feedback") private var enableHaptics = true
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Adaptive theme background
            theme.backgroundColor
                .ignoresSafeArea()
            
            if theme.activeTheme != .amoled {
                theme.backgroundGradient
                    .ignoresSafeArea()
            }
            
            List {
                // Profile Header card
                Section {
                    profileCard
                    if supabase.isAuthenticated {
                        NavigationLink(destination: ProfileEditView()) {
                            settingsRowLabel(title: "Edit Profile", subtitle: "Change display name or delete account", iconName: "person.crop.circle")
                        }
                    }
                }
                .listRowBackground(theme.cardBackground)
                
                // Redesigned Theme Cards selector
                Section(header: Text("App Theme").foregroundColor(theme.textSecondary)) {
                    themeRedesignedPicker
                }
                .listRowBackground(Color.clear)
                
                // Redesigned Global Accent Swatches selector
                Section(header: Text("App Accent Color").foregroundColor(theme.textSecondary)) {
                    accentColorPicker
                }
                .listRowBackground(Color.clear)
                
                // App Preferences Toggles
                Section(header: Text("Appearance & Interaction").foregroundColor(theme.textSecondary)) {
                    if pageFlipVisibility.isVisible {
                        Toggle(isOn: $usePageSwipe) {
                            settingsRowLabel(title: "Page Swipe Transitions", subtitle: "Use swipable lyric sheets", iconName: "book.pages")
                        }
                        .tint(theme.accentColor)
                    }
                    
                    Toggle(isOn: $enableHaptics) {
                        settingsRowLabel(title: "Tactile Haptics", subtitle: "Dynamic vibration feedback", iconName: "waveform")
                    }
                    .tint(theme.accentColor)
                    
                    Toggle(isOn: christmasBinding) {
                        settingsRowLabel(title: "Christmas Mode", subtitle: "Enable festive theme and Christmas carols", iconName: "snowflake")
                    }
                    .tint(theme.accentColor)
                }
                .listRowBackground(theme.cardBackground)
                
                if supabase.isAuthenticated {
                    Section(header: Text("Privacy").foregroundColor(theme.textSecondary)) {
                        Toggle(isOn: $privacyAccepted) {
                            settingsRowLabel(title: "Privacy Policy Accepted", subtitle: "Sync consent to your profile", iconName: "hand.raised")
                        }
                        .tint(theme.accentColor)
                        .onChange(of: privacyAccepted) { _, accepted in
                            UserDefaults.standard.set(accepted ? 1 : 0, forKey: "csi_privacy_accepted_local")
                            Task { await supabase.setPrivacyPolicyAcceptedInProfile(accepted) }
                        }
                        
                        Link(destination: URL(string: "https://sites.google.com/view/csi-hymns-privacy-policy/home")!) {
                            settingsRowLabel(title: "Privacy Policy", subtitle: "View full policy online", iconName: "doc.text")
                        }
                    }
                    .listRowBackground(theme.cardBackground)
                }
                
                // Support & Issue Logs
                Section(header: Text("Support & Data").foregroundColor(theme.textSecondary)) {
                    NavigationLink(destination: TicketsListView()) {
                        settingsRowLabel(title: "Reported Issues Log", subtitle: "Track lyric corrections status", iconName: "exclamationmark.bubble")
                    }
                    
                    Button {
                        isShowingClearCacheAlert = true
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    } label: {
                        settingsRowLabel(title: "Clear App Caches", subtitle: "Flush cached JSONs, liturgies & media", iconName: "lineweight")
                            .foregroundColor(theme.textPrimary)
                    }
                    .disabled(isClearing)
                    
                    Button {
                        isShowingClearHistoryAlert = true
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    } label: {
                        settingsRowLabel(title: "Clear Playback History", subtitle: "Flush recent songs & searches", iconName: "clock.arrow.circlepath")
                            .foregroundColor(theme.textPrimary)
                    }
                    .disabled(isClearing)
                }
                .listRowBackground(theme.cardBackground)
                
                // About & Promos
                Section(header: Text("About").foregroundColor(theme.textSecondary)) {
                    NavigationLink(destination: AboutDeveloperView()) {
                        settingsRowLabel(title: "About Developer", subtitle: "Credits, mission, and privacy links", iconName: "person.crop.circle")
                    }
                    
                    NavigationLink(destination: PraiseAppPromoView()) {
                        settingsRowLabel(title: "Related Devotions", subtitle: "Download Praise App suite", iconName: "sparkles")
                    }
                    
                    Button {
                        Task {
                            updateInfo = await AppStoreUpdateService.checkForUpdate()
                            if updateInfo == nil {
                                showUpToDateAlert = true
                            }
                        }
                    } label: {
                        settingsRowLabel(title: "Check for Updates", subtitle: "Compare with App Store version", iconName: "arrow.down.circle")
                            .foregroundColor(theme.textPrimary)
                    }
                }
                .listRowBackground(theme.cardBackground)
                
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
                    .listRowBackground(Color.red.opacity(0.12))
                }
            }
            .scrollContentBackground(.hidden)
            .foregroundColor(theme.textPrimary)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.secondaryBackgroundColor, for: .navigationBar)
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar) // Hide Bottom Tabbar
        .alert("Delete Account?", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                Task {
                    await deleteAccountCascade()
                }
            }
        } message: {
            Text("This action cannot be undone. All your custom category lists, bookmarks, and account profiles will be wiped off Supabase servers instantly.")
        }
        .alert("Clear Caches?", isPresented: $isShowingClearCacheAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Everything", role: .destructive) {
                Task {
                    await clearCachesAsync()
                }
            }
        } message: {
            Text("This will delete all downloaded Sunday liturgies, cache indexes, and local song data. Offline songs will be auto-redownloaded when you go online. Your favorites and account settings are safe.")
        }
        .alert("Clear History?", isPresented: $isShowingClearHistoryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive) {
                Task {
                    await clearHistoryAsync()
                }
            }
        } message: {
            Text("This will wipe out all your recent song logs, viewed tracks, and search query history. Saved favorites will remain unchanged.")
        }
        .alert("Update Available", isPresented: Binding(
            get: { updateInfo != nil },
            set: { if !$0 { updateInfo = nil } }
        )) {
            Button("Later", role: .cancel) { updateInfo = nil }
            Button("Update") {
                if let url = updateInfo.flatMap({ URL(string: $0.trackViewUrl) }) {
                    UIApplication.shared.open(url)
                }
                updateInfo = nil
            }
        } message: {
            if let info = updateInfo {
                Text("Version \(info.storeVersion) is available on the App Store.")
            }
        }
        .alert("Up to Date", isPresented: $showUpToDateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You're on the latest App Store version.")
        }
        .onAppear {
            privacyAccepted = supabase.currentUser?.privacyPolicyAccepted ?? (UserDefaults.standard.integer(forKey: "csi_privacy_accepted_local") == 1)
        }
        .task {
            await supabase.refreshDisplayName()
        }
    }
    
    // MARK: - Bindings
    
    private var christmasBinding: Binding<Bool> {
        Binding(
            get: { christmas.isChristmasTime },
            set: { newValue in
                christmas.setChristmasMode(newValue)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                PostHogService.shared.track(event: "christmas_mode_toggled", properties: ["enabled": newValue])
            }
        )
    }
    
    // MARK: - Subviews
    
    private var themeRedesignedPicker: some View {
        HStack(spacing: 12) {
            ForEach(AppTheme.allCases) { appTheme in
                let isSelected = theme.activeTheme == appTheme
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        theme.activeTheme = appTheme
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(previewBgColor(for: appTheme))
                                .frame(height: 54)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? theme.accentColor : theme.cardStroke, lineWidth: isSelected ? 2.5 : 1)
                                )
                            
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(previewTextColor(for: appTheme))
                                    .frame(width: 24, height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(previewTextColor(for: appTheme).opacity(0.6))
                                    .frame(width: 16, height: 3)
                            }
                        }
                        
                        Text(appTheme.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func previewBgColor(for theme: AppTheme) -> Color {
        switch theme {
        case .light: return Color(hex: "FFFFFF")
        case .dark: return Color(hex: "1B263B")
        case .amoled: return Color.black
        }
    }
    
    private func previewTextColor(for theme: AppTheme) -> Color {
        switch theme {
        case .light: return Color(hex: "1F2937")
        case .dark, .amoled: return Color.white
        }
    }
    
    private var accentColorPicker: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 54))], spacing: 12) {
                ForEach(AppAccentColor.allCases) { accent in
                    let isSelected = theme.selectedAccent == accent
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            theme.selectedAccent = accent
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(accent.color)
                                .frame(width: 38, height: 38)
                                .shadow(color: accent.color.opacity(0.35), radius: 6, x: 0, y: 3)
                            
                            if isSelected {
                                Circle()
                                    .stroke(theme.textPrimary, lineWidth: 3)
                                    .frame(width: 46, height: 46)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 48, height: 48)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var profileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.surfaceColor)
                    .frame(width: 58, height: 58)
                    .overlay(Circle().stroke(theme.strokeColor, lineWidth: 1))
                
                Text(supabase.isAuthenticated ? "👤" : "🔒")
                    .font(.system(size: 26))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if supabase.isAuthenticated {
                    Text(supabase.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    Text(supabase.currentUserEmail ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                } else {
                    Text("Guest Account")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    Text("Sign in to merge custom categories")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
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
                        .background(theme.surfaceColor)
                        .cornerRadius(8)
                        .foregroundColor(theme.textPrimary)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                NavigationLink(destination: AuthView()) {
                    Text("Sign In")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.accentColor) // Uses app accent color!
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
                    .fill(theme.accentColor.opacity(0.12))
                    .frame(width: 34, height: 34)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.accentColor.opacity(0.25), lineWidth: 1))
                
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(theme.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
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
    
    private func clearCachesAsync() async {
        isClearing = true
        try? await Task.sleep(for: .seconds(0.8))
        
        let fileManager = FileManager.default
        if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            if let urls = try? fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
                for url in urls {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
        
        // Remove download cache entries but preserve preferences and auth keys
        UserDefaults.standard.removeObject(forKey: "orderOfServiceData")
        UserDefaults.standard.removeObject(forKey: "lastOrderOfServiceUpdate")
        UserDefaults.standard.removeObject(forKey: "csi_cached_liturgies_json")
        
        // Dynamic notification broadcast to update liturgy reader lists
        NotificationCenter.default.post(name: Notification.Name("csi_liturgies_refreshed"), object: nil)
        
        await MainActor.run {
            isClearing = false
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    private func clearHistoryAsync() async {
        isClearing = true
        try? await Task.sleep(for: .seconds(0.6))
        
        // Clear recent songs list
        RecentSongsService.shared.clearAllRecents()
        
        // Clear search history keys if any
        UserDefaults.standard.removeObject(forKey: "recent_searches")
        
        await MainActor.run {
            isClearing = false
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}
