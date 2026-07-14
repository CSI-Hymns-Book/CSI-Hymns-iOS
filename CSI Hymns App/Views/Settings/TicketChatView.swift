import SwiftUI

@Observable
final class TicketChatViewModel {
    var messages: [TicketMessage] = []
    var isLoading = false
    var replyText = ""
    var isSending = false
    
    func loadMessages(ticket: JiraTicket, sync: Bool = true) async {
        isLoading = true
        if sync {
            await TicketsService.shared.syncTicketComments(ticketId: ticket.id, ticketKey: ticket.ticketKey)
        }
        do {
            let fetched = try await TicketsService.shared.getTicketMessages(ticketKey: ticket.ticketKey)
            await MainActor.run {
                self.messages = fetched
                self.isLoading = false
            }
        } catch {
            print("TicketChatViewModel: Error fetching messages: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    func sendMessage(ticket: JiraTicket) async {
        guard !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSending = true
        let textToSend = replyText
        replyText = ""
        
        do {
            if let sent = try await TicketsService.shared.sendTicketMessage(ticketId: ticket.id, ticketKey: ticket.ticketKey, message: textToSend) {
                await MainActor.run {
                    self.messages.append(sent)
                    self.isSending = false
                }
            } else {
                await MainActor.run {
                    self.isSending = false
                }
            }
        } catch {
            print("TicketChatViewModel: Error sending message: \(error)")
            await MainActor.run {
                self.isSending = false
            }
        }
    }
}

public struct TicketChatView: View {
    let ticket: JiraTicket
    @State private var viewModel = TicketChatViewModel()
    @State private var theme = ThemeManager.shared
    
    public init(ticket: JiraTicket) {
        self.ticket = ticket
    }
    
    public var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            
            if theme.activeTheme != .amoled {
                theme.backgroundGradient.ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Summary Header
                summaryHeaderCard
                
                if viewModel.isLoading {
                    ProgressView()
                        .tint(theme.textPrimary)
                        .frame(maxHeight: .infinity)
                } else {
                    messageList
                }
                
                // Input Row
                inputRow
            }
        }
        .navigationTitle(ticket.ticketKey)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.loadMessages(ticket: ticket, sync: true)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(theme.textPrimary)
                    }
                    
                    Button {
                        if let url = URL(string: ticket.ticketUrl) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(theme.textPrimary)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadMessages(ticket: ticket, sync: true)
            }
        }
    }
    
    private var summaryHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(ticket.songType.capitalized) \(ticket.songNumber)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                Text(ticket.jiraStatus)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.accentColor.opacity(0.15))
                    .cornerRadius(6)
                    .foregroundColor(theme.accentColor)
            }
            
            Text(ticket.songTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            
            if let desc = ticket.description, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
                    .padding(8)
                    .background(theme.surfaceColor)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(theme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var messageList: some View {
        ScrollView {
            ScrollViewReader { scrollProxy in
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { msg in
                        messageBubble(msg)
                            .id(msg.id ?? msg.message)
                    }
                }
                .padding()
                .onChange(of: viewModel.messages) { _, newMessages in
                    if let last = newMessages.last {
                        withAnimation {
                            scrollProxy.scrollTo(last.id ?? last.message, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let last = viewModel.messages.last {
                        scrollProxy.scrollTo(last.id ?? last.message, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func messageBubble(_ msg: TicketMessage) -> some View {
        let isUser = msg.sender == "user"
        return HStack {
            if isUser { Spacer() }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(msg.message)
                    .font(.system(size: 15))
                    .foregroundColor(isUser ? Color.white : theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? theme.accentColor : theme.cardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(theme.strokeColor, lineWidth: 1)
                    )
                
                if let date = msg.createdAt {
                    Text(formatDate(date))
                        .font(.system(size: 10))
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                }
            }
            
            if !isUser { Spacer() }
        }
    }
    
    private var inputRow: some View {
        HStack(spacing: 12) {
            TextField("Type a reply...", text: $viewModel.replyText)
                .padding(12)
                .background(theme.surfaceColor)
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(theme.strokeColor, lineWidth: 1)
                )
                .foregroundColor(theme.textPrimary)
            
            Button {
                Task {
                    await viewModel.sendMessage(ticket: ticket)
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundColor(viewModel.replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.textSecondary : theme.accentColor)
                    .padding(12)
                    .background(theme.surfaceColor)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(theme.strokeColor, lineWidth: 1)
                    )
            }
            .disabled(viewModel.replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(theme.backgroundColor.opacity(0.95))
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(theme.strokeColor),
            alignment: .top
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
