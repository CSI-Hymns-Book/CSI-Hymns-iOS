import SwiftUI

/// Structured model representing a changelog version release.
public struct ChangelogRelease: Codable, Identifiable, Hashable, Sendable {
    public var id: String { version }
    public let title: String
    public let version: String
    public let date: String
    public let changes: [String]
    
    public init(title: String, version: String, date: String, changes: [String]) {
        self.title = title
        self.version = version
        self.date = date
        self.changes = changes
    }
}

/// A premium, immersive welcome and changelog alert overlay with ticket correction celebration sheets.
public struct WelcomeChangelogView: View {
    let release: ChangelogRelease
    @State private var unacknowledgedTickets: [ResolvedTicketAckItem] = []
    @State private var isLoadingTickets = true
    @State private var currentStep: DialogStep = .resolvedTickets
    
    public var onDismiss: () -> Void
    
    private enum DialogStep {
        case resolvedTickets
        case changelog
    }
    
    public init(release: ChangelogRelease, onDismiss: @escaping () -> Void) {
        self.release = release
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // High-end dark material background
            Color.black.opacity(0.65)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                if currentStep == .resolvedTickets && !unacknowledgedTickets.isEmpty {
                    resolvedTicketsCard
                        .transition(.asymmetric(insertion: .scale, removal: .opacity))
                } else {
                    changelogCard
                        .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            Task {
                await checkResolvedTickets()
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Dialog celebrating successfully resolved lyric corrections.
    private var resolvedTicketsCard: some View {
        VStack(spacing: 20) {
            // Celebratory Header Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "4CAF50").opacity(0.12))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(Color(hex: "4CAF50").opacity(0.35), lineWidth: 1.5))
                
                Text("🎉")
                    .font(.system(size: 40))
            }
            .padding(.top, 10)
            
            VStack(spacing: 6) {
                Text("Lyrics Corrected!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Your contribution made the app better.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(unacknowledgedTickets) { item in
                        HStack(spacing: 14) {
                            Text("✅")
                                .font(.system(size: 20))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(item.songType.capitalized) \(item.songNumber)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(item.songTitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            
                            Text(item.jiraStatus)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "4CAF50").opacity(0.2))
                                .cornerRadius(6)
                                .foregroundColor(Color(hex: "4CAF50"))
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxHeight: 180)
            
            Button {
                acknowledgeResolvedTickets()
            } label: {
                Text("Awesome!")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(12)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "132237"))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
    }
    
    /// Dialog showing standard what's new changelogs.
    private var changelogCard: some View {
        VStack(spacing: 20) {
            // Header Info
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 54, height: 54)
                        .overlay(Circle().stroke(Color.blue.opacity(0.35), lineWidth: 1))
                    
                    Text("🚀")
                        .font(.system(size: 26))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Version \(release.version) • \(release.date)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
            
            // Release title
            HStack {
                Text("🎊")
                Text(release.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)
            
            // What's New bullet points list
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(release.changes, id: \.self) { change in
                        HStack(alignment: .top, spacing: 12) {
                            Text(getEmojiForChange(change))
                                .font(.system(size: 18))
                            
                            Text(change)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 280)
            
            // Dismiss Button
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                onDismiss()
            } label: {
                Text("Let's Go!")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "0D1B2A"))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
    }
    
    // MARK: - Helpers & Data Methods
    
    private func checkResolvedTickets() async {
        let tickets = await TicketAcknowledgementService.shared.getUnacknowledgedResolvedTickets(syncFirst: true)
        
        await MainActor.run {
            self.unacknowledgedTickets = tickets
            self.isLoadingTickets = false
            if tickets.isEmpty {
                self.currentStep = .changelog
            } else {
                // Play notification haptic sound for congratulations
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
    
    private func acknowledgeResolvedTickets() {
        let keys = unacknowledgedTickets.map { $0.ticketKey }
        TicketAcknowledgementService.shared.markAcknowledged(keys: keys)
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            currentStep = .changelog
        }
    }
    
    private func getEmojiForChange(_ change: String) -> String {
        let lower = change.lowercased()
        if lower.contains("new") || lower.contains("added") { return "✨" }
        if lower.contains("improved") || lower.contains("better") || lower.contains("smooth") { return "🚀" }
        if lower.contains("fixed") || lower.contains("bug") || lower.contains("crash") { return "🐛" }
        if lower.contains("christmas") || lower.contains("carol") { return "🎄" }
        if lower.contains("audio") || lower.contains("music") { return "🎵" }
        if lower.contains("theme") || lower.contains("color") { return "🎨" }
        if lower.contains("login") || lower.contains("auth") { return "🔐" }
        if lower.contains("pdf") || lower.contains("document") { return "📄" }
        if lower.contains("search") || lower.contains("filter") || lower.contains("meter") { return "🔍" }
        return "•"
    }
}
