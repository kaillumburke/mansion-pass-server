import Foundation

final class StripeService {
    static let shared = StripeService()
    private let baseURL = "https://web-production-d34cc.up.railway.app"
    private init() {}

    struct PaymentIntentResponse: Decodable {
        let clientSecret: String
        let paymentIntentId: String
    }

    func createPaymentIntent(
        amountInPence: Int,
        eventId: String,
        eventName: String,
        tierName: String,
        userEmail: String,
        quantity: Int
    ) async throws -> PaymentIntentResponse {
        guard let url = URL(string: "\(baseURL)/create-payment-intent") else {
            throw StripeServiceError.invalidURL
        }

        let payload: [String: Any] = [
            "amountInPence": amountInPence,
            "eventId": eventId,
            "eventName": eventName,
            "tierName": tierName,
            "userEmail": userEmail,
            "quantity": quantity,
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        req.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw StripeServiceError.serverError(body)
        }

        return try JSONDecoder().decode(PaymentIntentResponse.self, from: data)
    }
}

enum StripeServiceError: LocalizedError {
    case invalidURL
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .serverError(let msg): return "Payment error: \(msg)"
        }
    }
}
