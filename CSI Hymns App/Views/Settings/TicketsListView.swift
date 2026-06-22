import SwiftUI
import Observation

/// View model driving the Jira tickets list view and status sync operations.
@Observable
public final class TicketsListViewModel {
    public var tickets: [JiraTicket] = []
    public var isLoading = true
    public var errorMessage: String? = nil
    
    public init() {}
    
    public func fetchTickets() async {
        isLoading = true
        errorMessage = nil
        do {
            // Light status sync first for unresolved items
            await TicketsService.shared.syncActiveTicketStatuses()
            let fetched = try await TicketsService.shared.getMyTickets()
            
            await MainActor.run {
                self.tickets = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

/// A premium, glassmorphic issue tracking screen.
public struct TicketsListView: View {
    @State private var viewModel = TicketsListViewModel()
    @State private var theme = ThemeManager.shared
    
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
            
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(theme.textPrimary)
                        .frame(maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    errorStateView(error)
                } else if viewModel.tickets.isEmpty {
                    emptyStateView
                } else {
                    ticketsList
                }
            }
        }
        .navigationTitle("Lyric Corrections Log")
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            Task {
                await viewModel.fetchTickets()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 54))
                .foregroundColor(theme.textSecondary.opacity(0.6))
            
            Text("No Reported Issues")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text("Any lyric corrections you submit will be displayed here for real-time status tracking.")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func errorStateView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("Failed to Load Logs")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text(error)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Button("Retry") {
                Task {
                    await viewModel.fetchTickets()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(theme.surfaceColor)
            .cornerRadius(8)
            .foregroundColor(theme.textPrimary)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var ticketsList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.tickets) { ticket in
                    ticketCard(ticket)
                }
            }
            .padding(16)
        }
    }
    
    private func ticketCard(_ ticket: JiraTicket) -> some View {
        Button {
            guard let url = URL(string: ticket.ticketUrl) else { return }
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            // Launch in Safari
            UIApplication.shared.open(url)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                // Header row
                HStack {
                    Text(ticket.ticketKey)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.accentColor)
                    
                    Spacer()
                    
                    statusCapsule(status: ticket.jiraStatus)
                }
                
                // Song reference
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(ticket.songType.capitalized) \(ticket.songNumber)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                    
                    Text(ticket.songTitle)
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
                
                // Description details if any
                if let desc = ticket.description, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                        .padding(10)
                        .background(theme.surfaceColor)
                        .cornerRadius(8)
                }
                
                // Footer date
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(formatDate(ticket.createdAt))
                        .font(.system(size: 11))
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                }
                .foregroundColor(theme.textSecondary.opacity(0.7))
            }
            .padding(18)
            .background(theme.cardBackground)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(theme.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func statusCapsule(status: String) -> some View {
        let clean = status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let color: Color
        let bgColor: Color
        
        switch clean {
        case "done", "resolved", "closed":
            color = Color(hex: "4CAF50")
            bgColor = color.opacity(0.15)
        case "in progress", "active":
            color = theme.accentColor
            bgColor = theme.accentColor.opacity(0.15)
        case "email sent", "pending":
            color = theme.textSecondary
            bgColor = theme.surfaceColor
        default: // To Do, Open, etc.
            color = Color(hex: "FF9800")
            bgColor = color.opacity(0.15)
        }
        
        return Text(status)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bgColor)
            .cornerRadius(6)
            .foregroundColor(color)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
