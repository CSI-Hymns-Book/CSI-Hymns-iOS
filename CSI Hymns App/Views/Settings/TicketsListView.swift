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
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Immersive Glass Background Gradients
            LinearGradient(
                colors: [Color(hex: "0D1B2A"), Color(hex: "1B263B")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
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
                .foregroundColor(.white.opacity(0.4))
            
            Text("No Reported Issues")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text("Any lyric corrections you submit will be displayed here for real-time status tracking.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
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
            
            Text(error)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            Button("Retry") {
                Task {
                    await viewModel.fetchTickets()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12))
            .cornerRadius(8)
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
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    statusCapsule(status: ticket.jiraStatus)
                }
                
                // Song reference
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(ticket.songType.capitalized) \(ticket.songNumber)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(ticket.songTitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Description details if any
                if let desc = ticket.description, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                        .padding(10)
                        .background(Color.white.opacity(0.04))
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
                .foregroundColor(.white.opacity(0.4))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
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
            color = Color(hex: "2196F3")
            bgColor = color.opacity(0.15)
        case "email sent", "pending":
            color = Color.white.opacity(0.6)
            bgColor = Color.white.opacity(0.08)
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
