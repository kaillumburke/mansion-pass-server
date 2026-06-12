import Foundation

final class GuestlistService {
    static let shared = GuestlistService()
    private let signingBaseURL = "https://web-production-d34cc.up.railway.app"
    private init() {}

    func sendPass(name: String, email: String, event: AppEvent?) async throws {
        let ticketId = UUID().uuidString
        let qrCode = "MNS-GUEST-\(ticketId.prefix(8).uppercased())"
        let eventName = event?.name ?? "MANSION SATURDAYS"
        let eventDate = event?.date ?? Date()
        let doorsOpen = event?.doorsOpen ?? Date()

        let payload: [String: Any] = [
            "id": ticketId,
            "orderId": "GUESTLIST",
            "userId": "guestlist",
            "userEmail": email,
            "userName": name,
            "eventId": event?.id ?? "event-1",
            "eventName": eventName,
            "tierId": "ga",
            "tierName": "General Admission",
            "tierPriceInPence": 0,
            "qrCode": qrCode,
            "status": "valid",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "eventDate": ISO8601DateFormatter().string(from: eventDate),
            "doorsOpen": ISO8601DateFormatter().string(from: doorsOpen)
        ]

        guard let url = URL(string: "\(signingBaseURL)/guestlist") else { throw GuestlistError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        req.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ Guestlist error: \(body)")
            throw GuestlistError.passFailed
        }
    }
}

enum GuestlistError: LocalizedError {
    case invalidURL, passFailed
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .passFailed: return "Failed to send guestlist pass — please try again"
        }
    }
}
