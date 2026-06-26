import SwiftUI
import Combine
import FirebaseFirestore

class AppState: ObservableObject {
    // Auth is delegated to AuthService — observe it here for SwiftUI bindings
    let auth = AuthService.shared

    @Published var myTickets: [Ticket] = MockData.myTickets
    @Published var myOrders: [Order] = MockData.myOrders
    @Published var myDrinksVouchers: [DrinksVoucher] = MockData.drinksVouchers
    @Published var notifications: [AppNotification] = MockData.notifications
    @Published var events: [AppEvent] = []
    @Published var basket: [BasketItem] = []
    @Published var selectedTab: Int = 0
    @Published var sentNotifications: [SentNotification] = []
    @Published var guestlistEntries: [GuestEntry] = []

    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()
    private var eventsListener: ListenerRegistration?

    init() {
        auth.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        startEventsListener()
    }

    deinit { eventsListener?.remove() }

    private func startEventsListener() {
        eventsListener = db.collection("events")
            .addSnapshotListener { [weak self] snap, error in
                if let error {
                    print("❌ Events listener error: \(error)")
                    return
                }
                guard let self, let snap else { return }
                print("✅ Events synced: \(snap.documents.count) events")
                self.events = snap.documents.compactMap { Self.parseEvent($0) }
                    .sorted { $0.date < $1.date }
            }
    }

    static func parseEvent(_ doc: DocumentSnapshot) -> AppEvent? {
        let d = doc.data() ?? [:]
        guard let name = d["name"] as? String,
              let dateTs = d["date"] as? Timestamp else { return nil }

        let doorsTs = (d["doorsOpen"] as? Timestamp) ?? dateTs
        let lastTs  = (d["lastEntry"] as? Timestamp) ?? dateTs
        let endTs   = (d["endTime"] as? Timestamp) ?? dateTs
        let statusRaw = (d["status"] as? String) ?? "DRAFT"

        let eventId = doc.documentID
        let tierDocs = (d["tiers"] as? [[String: Any]]) ?? []
        let tiers: [TicketTier] = tierDocs.compactMap { t in
            guard let id    = t["id"] as? String,
                  let tname = t["name"] as? String else { return nil }
            // Firestore stores JS numbers as Double — handle both Int and Double
            func asInt(_ key: String) -> Int? {
                if let v = t[key] as? Int { return v }
                if let v = t[key] as? Double { return Int(v) }
                return nil
            }
            guard let price = asInt("priceInPence"),
                  let alloc = asInt("allocation") else { return nil }
            let sold = asInt("sold") ?? 0
            return TicketTier(
                id: id, eventId: eventId, name: tname,
                description: (t["description"] as? String) ?? "",
                priceInPence: price, quantity: alloc, sold: sold,
                saleStartsAt: nil, saleEndsAt: nil, dependsOnTierId: nil,
                minPerOrder: 1, maxPerOrder: 4, isVisible: true
            )
        }

        return AppEvent(
            id: doc.documentID,
            name: name,
            description: (d["description"] as? String) ?? "",
            date: dateTs.dateValue(),
            endTime: endTs.dateValue(),
            doorsOpen: doorsTs.dateValue(),
            lastEntry: lastTs.dateValue(),
            venue: (d["venue"] as? String) ?? "Mansion, Liverpool",
            ageRestriction: (d["ageRestriction"] as? Int) ?? 18,
            artworkGradient: (d["artworkGradient"] as? [String]) ?? ["#1a0a00", "#2d1200"],
            artworkImageName: nil,
            headerImageURL: d["headerImageURL"] as? String,
            capacity: (d["capacity"] as? Int) ?? 500,
            status: EventStatus(rawValue: statusRaw) ?? .draft,
            tiers: tiers
        )
    }

    // MARK: - Convenience accessors

    var currentUser: DBUser? { auth.currentUser }
    var isAuthenticated: Bool { auth.isAuthenticated }
    var isLoading: Bool { auth.isLoading }
    var isAdmin: Bool { auth.currentUser?.role == .admin }
    var isPromoter: Bool { auth.currentUser?.role == .admin } // admin == promoter for tab routing
    var isDoorStaff: Bool { auth.currentUser?.role == .doorStaff }

    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var basketTotal: Int { basket.reduce(0) { $0 + $1.totalInPence } }
    var basketItemCount: Int { basket.reduce(0) { $0 + $1.quantity } }

    // MARK: - Auth (delegates to AuthService)

    func login(email: String, password: String, remember: Bool = true) {
        Task {
            try await auth.login(email: email, password: password)
        }
    }

    func register(firstName: String, lastName: String, email: String, password: String, phone: String) {
        Task {
            try await auth.register(firstName: firstName, lastName: lastName, email: email, password: password, phone: phone)
        }
    }

    func logout() {
        try? auth.logout()
        basket = []
    }

    // MARK: - Notifications

    func markNotificationRead(id: String) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead = true
        }
    }

    func markAllNotificationsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
    }

    // MARK: - Basket

    func addToBasket(tier: TicketTier, quantity: Int) {
        if let index = basket.firstIndex(where: { $0.tier.id == tier.id }) {
            basket[index].quantity += quantity
        } else {
            basket.append(BasketItem(tier: tier, quantity: quantity))
        }
    }

    func removeFromBasket(id: String) {
        basket.removeAll { $0.id == id }
    }

    func clearBasket() {
        basket = []
    }

    // MARK: - Purchase

    func purchaseBasket(event: AppEvent) {
        let user = auth.currentUser
        let orderId = UUID().uuidString
        var newTickets: [Ticket] = []
        var firestoreTickets: [FirestoreTicket] = []
        var totalFaceValue = 0
        var totalBookingFees = 0

        for item in basket {
            totalFaceValue += item.subtotalInPence
            totalBookingFees += item.bookingFeeInPence
            for _ in 0..<item.quantity {
                let ticketId = UUID().uuidString
                let qrCode = TicketService.generateQRCode()

                let ticket = Ticket(
                    id: ticketId,
                    orderId: orderId,
                    tier: item.tier,
                    event: event,
                    qrCode: qrCode,
                    status: .valid,
                    createdAt: Date()
                )
                newTickets.append(ticket)

                let ft = FirestoreTicket(
                    id: ticketId,
                    orderId: orderId,
                    userId: user?.id ?? "guest",
                    userEmail: user?.email ?? "",
                    userName: user?.fullName ?? "Guest",
                    userPhone: user?.phone,
                    userDOB: user?.dob,
                    eventId: event.id,
                    eventName: event.name,
                    tierId: item.tier.id,
                    tierName: item.tier.name,
                    tierPriceInPence: item.tier.priceInPence,
                    qrCode: qrCode,
                    status: "valid",
                    createdAt: Date(),
                    eventDate: event.date,
                    doorsOpen: event.doorsOpen,
                    scannedAt: nil
                )
                firestoreTickets.append(ft)
            }
            if let eIdx = events.firstIndex(where: { $0.id == event.id }),
               let tIdx = events[eIdx].tiers.firstIndex(where: { $0.id == item.tier.id }) {
                events[eIdx].tiers[tIdx].sold += item.quantity
            }
        }

        myTickets.append(contentsOf: newTickets)
        let order = Order(
            id: orderId,
            event: event,
            tickets: newTickets,
            totalAmountInPence: totalFaceValue,
            bookingFeePaidInPence: totalBookingFees,
            status: .completed,
            createdAt: Date()
        )
        myOrders.insert(order, at: 0)
        clearBasket()

        // Persist to Firestore
        Task {
            do {
                try await TicketService.shared.saveTickets(firestoreTickets)
                print("✅ Tickets saved to Firestore: \(firestoreTickets.count) ticket(s)")
            } catch {
                print("❌ Failed to save tickets to Firestore: \(error)")
            }
        }

        for item in newTickets {
            OneSignalManager.shared.tagTicketPurchase(eventId: event.id, tierName: item.tier.name)
        }
    }

    func purchaseTickets(event: AppEvent, tier: TicketTier, quantity: Int) {
        addToBasket(tier: tier, quantity: quantity)
        purchaseBasket(event: event)
    }

    // MARK: - Admin Push Notifications

    @MainActor
    func broadcastNotification(title: String, body: String, audience: NotificationAudience, eventId: String?) async throws {
        let recipients = try await OneSignalManager.shared.sendNotification(
            title: title, body: body, audience: audience, eventId: eventId
        )
        let sent = SentNotification(
            id: UUID().uuidString, title: title, body: body,
            audience: audience, eventId: eventId, sentAt: Date(), recipientCount: recipients
        )
        sentNotifications.insert(sent, at: 0)
        let preview = AppNotification(
            id: UUID().uuidString, title: title, body: body,
            eventId: eventId, sentAt: Date(), isRead: true
        )
        notifications.insert(preview, at: 0)
    }

    // MARK: - Event Management

    func createEvent(_ event: AppEvent) { events.append(event) }
    func updateEvent(_ event: AppEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) { events[index] = event }
    }
    func deleteEvent(id: String) { events.removeAll { $0.id == id } }
}
