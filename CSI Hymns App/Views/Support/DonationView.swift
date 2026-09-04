import SwiftUI

private enum DonationCurrency: String, CaseIterable, Identifiable {
    case inr = "INR"
    case usd = "USD"
    
    var id: String { rawValue }
    var symbol: String { self == .inr ? "₹" : "$" }
    var label: String { self == .inr ? "₹ INR" : "$ USD" }
    var tiers: [Int] { self == .inr ? [50, 100, 250, 500] : [2, 5, 10, 25] }
}

/// Support / donation screen with hosted web checkout (Android `DonationScreen` parity, Safari-based).
public struct DonationView: View {
    @Environment(\.openURL) private var openURL
    @State private var theme = ThemeManager.shared
    @State private var currency: DonationCurrency = .inr
    @State private var selectedTierIndex = 0
    @State private var customAmountText = ""
    @State private var gateways: [PaymentGatewayRow] = []
    @State private var selectedGateway: PaymentGatewayRow?
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var isSuccess: Bool?
    @State private var lastClickAt: Date = .distantPast
    
    public init() {}
    
    private var selectedAmount: Int {
        if let custom = Int(customAmountText), custom > 0 { return custom }
        let tiers = currency.tiers
        if selectedTierIndex >= 0, selectedTierIndex < tiers.count {
            return tiers[selectedTierIndex]
        }
        return tiers.first ?? 0
    }
    
    public var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            if theme.activeTheme != .amoled {
                theme.backgroundGradient.ignoresSafeArea()
            }
            
            ScrollView {
                VStack(spacing: 18) {
                    heroBanner
                    amountSection
                    if gateways.count > 1 {
                        gatewaySection
                    }
                    if let statusMessage {
                        statusBanner(statusMessage, success: isSuccess == true)
                    }
                    donateButton
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 12))
                        Text("Encrypted & Processed via Serverless Payment Gateways")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(theme.textSecondary)
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .navigationTitle("Support CSI Hymns")
        .navigationBarTitleDisplayMode(.inline)
        .csiGlassNavigationBar(theme: theme)
        .toolbar(.hidden, for: .tabBar)
        .task { await loadGateways() }
        .alert(
            isSuccess == true ? "Donation Received!" : "Payment Incomplete",
            isPresented: Binding(
                get: { isSuccess != nil },
                set: { if !$0 { isSuccess = nil; statusMessage = nil } }
            )
        ) {
            Button(isSuccess == true ? "Done" : "Try Again") {
                isSuccess = nil
                statusMessage = nil
            }
        } message: {
            if isSuccess == true {
                Text("Amount: \(currency.symbol)\(selectedAmount)\nThank you for keeping CSI Hymns free and ad-free.")
            } else {
                Text(statusMessage ?? "The payment process was cancelled or not completed.")
            }
        }
    }
    
    private var heroBanner: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(theme.accentColor).frame(width: 52, height: 52)
                Image(systemName: "heart")
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .bold))
            }
            Text("Keep CSI Hymns Free & Ad-Free")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Your voluntary contribution helps fund database servers, domain renewal, audio hosting, and continuous app improvements for the community.")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(theme.accentColor.opacity(0.12))
        .cornerRadius(24)
    }
    
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SELECT AMOUNT")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.1)
                    .foregroundColor(theme.accentColor)
                Spacer()
                HStack(spacing: 0) {
                    ForEach(DonationCurrency.allCases) { item in
                        Button {
                            currency = item
                            selectedTierIndex = 0
                            customAmountText = ""
                        } label: {
                            Text(item.label)
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .foregroundColor(currency == item ? .white : theme.textSecondary)
                                .background(currency == item ? theme.accentColor : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(theme.cardBackground)
                .clipShape(Capsule())
            }
            
            HStack(spacing: 8) {
                ForEach(Array(currency.tiers.enumerated()), id: \.offset) { index, amount in
                    let selected = selectedTierIndex == index && customAmountText.isEmpty
                    Button {
                        selectedTierIndex = index
                        customAmountText = ""
                    } label: {
                        Text("\(currency.symbol)\(amount)")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundColor(selected ? .white : theme.textPrimary)
                            .background(selected ? theme.accentColor : theme.cardBackground)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selected ? Color.clear : theme.cardStroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            TextField("Custom Amount (\(currency.symbol))", text: $customAmountText)
                .keyboardType(.numberPad)
                .padding(14)
                .background(theme.cardBackground)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardStroke, lineWidth: 1))
                .foregroundColor(theme.textPrimary)
                .onChange(of: customAmountText) { _, newValue in
                    customAmountText = newValue.filter(\.isNumber)
                    if !customAmountText.isEmpty { selectedTierIndex = -1 }
                }
        }
    }
    
    private var gatewaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PAYMENT METHOD")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.1)
                .foregroundColor(theme.accentColor)
            
            ForEach(gateways) { gateway in
                let selected = selectedGateway?.id == gateway.id || selectedGateway?.name == gateway.name
                Button {
                    selectedGateway = gateway
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(selected ? theme.accentColor : theme.accentColor.opacity(0.15))
                                .frame(width: 38, height: 38)
                            Image(systemName: iconName(for: gateway))
                                .foregroundColor(selected ? .white : theme.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(gateway.displayName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(theme.textPrimary)
                            if let description = gateway.description, !description.isEmpty {
                                Text(description)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        Spacer()
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.accentColor)
                        }
                    }
                    .padding(14)
                    .background(selected ? theme.accentColor.opacity(0.12) : theme.cardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selected ? theme.accentColor : theme.cardStroke, lineWidth: selected ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var donateButton: some View {
        Button {
            Task { await donate() }
        } label: {
            HStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "heart.fill")
                    Text("Donate \(currency.symbol)\(selectedAmount) via \(selectedGateway?.displayName.split(separator: " ").first.map(String.init) ?? "Gateway")")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(theme.accentColor)
            .cornerRadius(18)
        }
        .disabled(isLoading || selectedAmount <= 0)
        .buttonStyle(.plain)
    }
    
    private func statusBanner(_ message: String, success: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: success ? "checkmark.circle" : "info.circle")
            Text(message)
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .foregroundColor(success ? Color.green : Color.red)
        .padding(14)
        .background((success ? Color.green : Color.red).opacity(0.12))
        .cornerRadius(14)
    }
    
    private func iconName(for gateway: PaymentGatewayRow) -> String {
        switch (gateway.iconType ?? gateway.name).lowercased() {
        case "upi", "razorpay": return "bolt.fill"
        case "card", "adyen": return "creditcard.fill"
        default: return "wallet.pass.fill"
        }
    }
    
    private func loadGateways() async {
        let list = await ServerDrivenPaymentService.fetchEnabledGateways()
        await MainActor.run {
            gateways = list
            if currency == .inr {
                selectedGateway = list.first(where: { $0.name.lowercased() == "razorpay" }) ?? list.first
            } else {
                selectedGateway = list.first(where: { $0.name.lowercased() == "razorpay" })
                    ?? list.first(where: { $0.name.lowercased() == "adyen" })
                    ?? list.first
            }
        }
    }
    
    private func donate() async {
        let now = Date()
        guard now.timeIntervalSince(lastClickAt) >= 2 else { return }
        lastClickAt = now
        
        guard selectedAmount > 0 else {
            statusMessage = "Please enter a valid amount"
            isSuccess = false
            return
        }
        guard let gateway = selectedGateway ?? gateways.first else {
            statusMessage = "No active payment gateway available"
            isSuccess = false
            return
        }
        
        isLoading = true
        statusMessage = nil
        isSuccess = nil
        defer { isLoading = false }
        
        do {
            let url = try await ServerDrivenPaymentService.startCheckout(
                gateway: gateway,
                amount: Double(selectedAmount),
                currency: currency.rawValue
            )
            openURL(url)
        } catch {
            statusMessage = "Payment launch error: \(error.localizedDescription)"
            isSuccess = false
        }
    }
}
