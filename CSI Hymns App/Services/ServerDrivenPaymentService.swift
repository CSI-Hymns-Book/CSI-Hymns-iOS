import Foundation

#if canImport(Supabase)
import Supabase
#endif

public struct PaymentGatewayRow: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let displayName: String
    public let description: String?
    public let edgeFunctionUrl: String?
    public let isEnabled: Bool
    public let iconType: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case displayName = "display_name"
        case edgeFunctionUrl = "edge_function_url"
        case isEnabled = "is_enabled"
        case iconType = "icon_type"
    }
    
    public init(
        id: String,
        name: String,
        displayName: String,
        description: String?,
        edgeFunctionUrl: String?,
        isEnabled: Bool,
        iconType: String?
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.description = description
        self.edgeFunctionUrl = edgeFunctionUrl
        self.isEnabled = isEnabled
        self.iconType = iconType
    }
}

/// Opens hosted checkout URLs from Supabase edge functions (no native Adyen Drop-In).
public enum ServerDrivenPaymentService {
    private static let fallbackRazorpay = "https://vvlyyysdfpsikayymeyv.supabase.co/functions/v1/razorpay-checkout"
    private static let fallbackAdyen = "https://vvlyyysdfpsikayymeyv.supabase.co/functions/v1/adyen-checkout"
    
    public static func defaultGateways() -> [PaymentGatewayRow] {
        [
            PaymentGatewayRow(
                id: "razorpay",
                name: "razorpay",
                displayName: "Razorpay (UPI, GPay, PhonePe, Cards)",
                description: "UPI, QR Code, Netbanking & International Cards/PayPal",
                edgeFunctionUrl: fallbackRazorpay,
                isEnabled: true,
                iconType: "upi"
            ),
            PaymentGatewayRow(
                id: "adyen",
                name: "adyen",
                displayName: "Adyen Global Payments",
                description: "International Credit & Debit Cards",
                edgeFunctionUrl: fallbackAdyen,
                isEnabled: true,
                iconType: "card"
            )
        ]
    }
    
    @MainActor
    public static func fetchEnabledGateways() async -> [PaymentGatewayRow] {
        let config = AppConfigService.shared.config
        var list: [PaymentGatewayRow] = []
        
        #if canImport(Supabase)
        do {
            let rows: [PaymentGatewayRow] = try await SupabaseService.instance.client
                .from("payment_gateways")
                .select()
                .eq("is_enabled", value: true)
                .execute()
                .value
            list = rows
        } catch {
            print("ServerDrivenPaymentService: gateway fetch failed: \(error)")
        }
        #endif
        
        if list.isEmpty {
            list = defaultGateways()
        }
        
        return list.filter { gateway in
            switch gateway.name.lowercased() {
            case "adyen":
                return config.isAdyenEnabled == true
            case "razorpay":
                return config.isRazorpayEnabled != false
            default:
                return gateway.isEnabled
            }
        }
    }
    
    public static func startCheckout(
        gateway: PaymentGatewayRow,
        amount: Double,
        currency: String
    ) async throws -> URL {
        let rawUrl = gateway.edgeFunctionUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        let edgeUrl: String
        if let rawUrl, !rawUrl.isEmpty {
            edgeUrl = rawUrl
        } else if gateway.name.lowercased() == "razorpay" {
            edgeUrl = fallbackRazorpay
        } else {
            edgeUrl = fallbackAdyen
        }
        
        guard let url = URL(string: edgeUrl) else {
            throw NSError(domain: "Payment", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid checkout URL"])
        }
        
        let body: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "returnUrl": "https://csihymns.app/donation_result",
            "callback_url": "https://csihymns.app/donation_result",
            "description": "CSI Hymns Support Donation"
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 20
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "Payment", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }
        if !(200...299).contains(http.statusCode) {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(
                domain: "Payment",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: msg ?? "Server request failed (HTTP \(http.statusCode))"]
            )
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Payment", code: 3, userInfo: [NSLocalizedDescriptionKey: "Malformed checkout response"])
        }
        let hosted = (json["hostedUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? (json["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let hosted, !hosted.isEmpty, let hostedURL = URL(string: hosted) else {
            throw NSError(domain: "Payment", code: 4, userInfo: [NSLocalizedDescriptionKey: "Payment URL missing from response"])
        }
        return hostedURL
    }
}
