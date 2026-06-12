import Foundation
#if canImport(OneSignalFramework)
import OneSignalFramework
#endif

// MARK: - Configuration

struct OneSignalConfig {
    static let appId = "9698bd39-6e4d-40b0-8dfc-1432d7921143"

    // REST API Key from: OneSignal Dashboard → Settings → Keys & IDs
    static var restApiKey = "os_v2_app_s2ml2olojvalbdp4cqznpeqripsqjeshtrcuu3n5seueu3akj67cyff6ayyupmohbly5ge77byggij3ha4kaqhes3avh77qeyncbj5a"

    static var isConfigured: Bool { !restApiKey.isEmpty }

    // Persisted subscription IDs collected from devices that have opened the app.
    // Using these lets OneSignal route to the correct APNs environment per device.
    private static let udKey = "os_known_subscription_ids"

    static var knownSubscriptionIds: [String] {
        UserDefaults.standard.stringArray(forKey: udKey) ?? []
    }

    static func registerSubscriptionId(_ id: String) {
        var ids = knownSubscriptionIds
        if !ids.contains(id) {
            ids.append(id)
            UserDefaults.standard.set(ids, forKey: udKey)
        }
    }
}

// MARK: - Audience → OneSignal segment mapping
// These segment names must exist in your OneSignal dashboard.
// Dashboard → Audience → Segments → New Segment
extension NotificationAudience {
    var oneSignalSegment: String {
        switch self {
        case .everyone:      return "Total Subscriptions"
        case .ticketHolders: return "Ticket Holders"
        case .vipOnly:       return "VIP Holders"
        }
    }
}

// MARK: - Centralized Manager

final class OneSignalManager {
    static let shared = OneSignalManager()
    private init() {}

    func initialize() {
        #if canImport(OneSignalFramework)
        OneSignal.Debug.setLogLevel(.LL_WARN)
        OneSignal.initialize(OneSignalConfig.appId, withLaunchOptions: nil)
        // Pre-seed known subscription IDs so REST API can target them immediately.
        // Add any new device IDs from OneSignal Dashboard → Audience → Subscriptions.
        let seedIds = [
            "a731d9e5-adba-4749-850c-7402da35a7be",
            "476ad52a-26fc-4c86-a085-8d08adc9c417",
            "bc7fce7e-2c68-498f-9886-be0ceb571c53",
            "d1b6e297-ed1e-4ee1-964c-2f5e0efff641",
            "fe37b183-bb90-465b-949d-1714d919dea1",
        ]
        seedIds.forEach { OneSignalConfig.registerSubscriptionId($0) }
        // Also register this device's current ID
        if let id = OneSignal.User.pushSubscription.id, !id.isEmpty {
            OneSignalConfig.registerSubscriptionId(id)
        }
        #endif
    }

    func requestPermission() {
        #if canImport(OneSignalFramework)
        OneSignal.Notifications.requestPermission({ _ in }, fallbackToSettings: true)
        #endif
    }

    func login(externalId: String) {
        #if canImport(OneSignalFramework)
        OneSignal.login(externalId)
        #endif
    }

    func logout() {
        #if canImport(OneSignalFramework)
        OneSignal.logout()
        #endif
    }

    func setEmail(_ email: String) {
        #if canImport(OneSignalFramework)
        OneSignal.User.addEmail(email)
        #endif
    }

    func setTag(key: String, value: String) {
        #if canImport(OneSignalFramework)
        OneSignal.User.addTag(key: key, value: value)
        #endif
    }

    func tagTicketPurchase(eventId: String, tierName: String) {
        setTag(key: "has_ticket", value: "true")
        setTag(key: "last_event_id", value: eventId)
        if tierName.lowercased().contains("vip") {
            setTag(key: "tier", value: "vip")
        }
    }

    /// Returns the current device's OneSignal subscription ID, or nil if not yet registered.
    var subscriptionId: String? {
        #if canImport(OneSignalFramework)
        return OneSignal.User.pushSubscription.id
        #else
        return nil
        #endif
    }
}

// MARK: - REST API (send from admin)

enum OneSignalError: LocalizedError {
    case notConfigured
    case networkError(Error)
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Add your REST API Key to OneSignalConfig in OneSignalService.swift."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .serverError(let code, let msg):
            return "OneSignal error \(code): \(msg)"
        }
    }
}

private struct OneSignalResponse: Decodable {
    let recipients: Int?
    let errors: [String]?
}

extension OneSignalManager {

    func sendNotification(
        title: String,
        body: String,
        audience: NotificationAudience,
        eventId: String?
    ) async throws -> Int {
        guard OneSignalConfig.isConfigured else { throw OneSignalError.notConfigured }

        var request = URLRequest(url: URL(string: "https://onesignal.com/api/v1/notifications")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Key \(OneSignalConfig.restApiKey)", forHTTPHeaderField: "Authorization")

        var payload: [String: Any] = [
            "app_id": OneSignalConfig.appId,
            "headings": ["en": title],
            "contents": ["en": body],
            "ios_attachments": ["logo": "https://web-production-d34cc.up.railway.app/notification-icon.png"],
            "mutable_content": true,
        ]

        switch audience {
        case .everyone:
            payload["included_segments"] = ["Total Subscriptions"]
        case .ticketHolders:
            payload["filters"] = [["field": "tag", "key": "has_ticket", "relation": "=", "value": "true"]]
        case .vipOnly:
            payload["filters"] = [["field": "tag", "key": "tier", "relation": "=", "value": "vip"]]
        }

        if let eventId {
            payload["data"] = ["eventId": eventId]
            payload["url"] = "mansion://events/\(eventId)"
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OneSignalError.serverError(0, "No HTTP response")
        }

        let responseBody = String(data: data, encoding: .utf8) ?? ""
        print("🔔 OneSignal response [\(http.statusCode)]: \(responseBody)")

        guard (200...299).contains(http.statusCode) else {
            throw OneSignalError.serverError(http.statusCode, responseBody)
        }

        let result = try? JSONDecoder().decode(OneSignalResponse.self, from: data)
        return result?.recipients ?? 0
    }
}
