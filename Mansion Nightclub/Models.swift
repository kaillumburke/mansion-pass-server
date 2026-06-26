import Foundation

// MARK: - Enums

enum EventStatus: String, Codable {
    case draft = "DRAFT"
    case published = "PUBLISHED"
    case cancelled = "CANCELLED"
    case completed = "COMPLETED"
}

enum TicketStatus: String, Codable {
    case valid = "VALID"
    case used = "USED"
    case cancelled = "CANCELLED"
    case refunded = "REFUNDED"
}

enum OrderStatus: String, Codable {
    case pending = "PENDING"
    case completed = "COMPLETED"
    case refunded = "REFUNDED"
    case cancelled = "CANCELLED"
}

enum PayoutStatus {
    case pending       // event hasn't happened yet
    case processing    // event done, awaiting Wednesday
    case paid
}

// UserRole is defined in AuthService.swift (admin / customer / doorStaff)

// MARK: - Core Models

struct AppEvent: Identifiable {
    let id: String
    var name: String
    var description: String
    var date: Date           // event start date
    var endTime: Date
    var doorsOpen: Date
    var lastEntry: Date
    var venue: String
    var ageRestriction: Int  // e.g. 18
    var artworkGradient: [String]
    var artworkImageName: String?
    var headerImageURL: String?
    let capacity: Int
    var status: EventStatus
    var tiers: [TicketTier]

    var ticketsSold: Int { tiers.reduce(0) { $0 + $1.sold } }
    var availabilityPercent: Double { Double(ticketsSold) / Double(capacity) }
    var isSoldOut: Bool { tiers.filter { $0.isVisible }.allSatisfy { $0.available == 0 } }

    // Revenue calculations
    static let bookingFeePercent: Double = 0.10
    static let merchantFeePercent: Double = 0.006

    var grossRevenue: Int { tiers.reduce(0) { $0 + ($1.priceInPence * $1.sold) } }
    var totalBookingFees: Int { Int(Double(grossRevenue) * AppEvent.bookingFeePercent) }
    var merchantFees: Int { Int(Double(totalBookingFees) * AppEvent.merchantFeePercent / AppEvent.bookingFeePercent) }
    // Promoter receives face value only (booking fee is ours, merchant fee taken from booking fee)
    var promoterRevenue: Int { grossRevenue - totalBookingFees }
    // Our net after merchant fees
    var netBookingFees: Int { totalBookingFees - merchantFees }

    var payoutDate: Date? {
        guard status == .completed else { return nil }
        // Next Wednesday after event end
        var cal = Calendar.current
        cal.firstWeekday = 2
        let components = DateComponents(weekday: 4) // Wednesday
        return cal.nextDate(after: endTime, matching: components, matchingPolicy: .nextTime)
    }
}

struct TicketTier: Identifiable {
    let id: String
    let eventId: String
    var name: String
    var description: String
    var priceInPence: Int
    var quantity: Int        // allocation
    var sold: Int
    var saleStartsAt: Date?
    var saleEndsAt: Date?
    var dependsOnTierId: String?  // only available if another tier is sold out
    var minPerOrder: Int
    var maxPerOrder: Int
    var isVisible: Bool

    var available: Int { max(0, quantity - sold) }
    var isSoldOut: Bool { available == 0 }
    var isPendingOnSale: Bool {
        guard let start = saleStartsAt else { return false }
        return Date() < start
    }
    var priceFormatted: String {
        priceInPence == 0 ? "Free" : "£\(String(format: "%.2f", Double(priceInPence) / 100))"
    }
    var bookingFee: Int { Int(Double(priceInPence) * AppEvent.bookingFeePercent) }
    var totalWithFee: Int { priceInPence + bookingFee }
    var totalWithFeeFormatted: String {
        priceInPence == 0 ? "Free" : "£\(String(format: "%.2f", Double(totalWithFee) / 100))"
    }
}

struct Order: Identifiable {
    let id: String
    let event: AppEvent
    let tickets: [Ticket]
    let totalAmountInPence: Int      // face value only
    let bookingFeePaidInPence: Int
    let status: OrderStatus
    let createdAt: Date

    var totalFormatted: String {
        "£\(String(format: "%.2f", Double(totalAmountInPence + bookingFeePaidInPence) / 100))"
    }
}

struct Ticket: Identifiable {
    let id: String
    let orderId: String
    let tier: TicketTier
    let event: AppEvent
    let qrCode: String
    var status: TicketStatus
    let createdAt: Date
    var scannedAt: Date?
}

extension Ticket {
    var asFirestoreTicket: FirestoreTicket {
        FirestoreTicket(
            id: id, orderId: orderId,
            userId: "", userEmail: "", userName: "",
            eventId: event.id, eventName: event.name,
            tierId: tier.id, tierName: tier.name,
            tierPriceInPence: tier.priceInPence,
            qrCode: qrCode,
            status: status.rawValue.lowercased(),
            createdAt: createdAt, eventDate: event.date, doorsOpen: event.doorsOpen, scannedAt: scannedAt
        )
    }
}

struct AppNotification: Identifiable {
    let id: String
    let title: String
    let body: String
    let eventId: String?
    let sentAt: Date
    var isRead: Bool
}

// AppUser is now DBUser (defined in AuthService.swift)
typealias AppUser = DBUser

struct DrinksPackage: Identifiable {
    let id: String
    let name: String
    let description: String
    let includes: [String]
    let priceInPence: Int
    let isPopular: Bool

    var priceFormatted: String {
        "£\(String(format: "%.2f", Double(priceInPence) / 100))"
    }
}

// MARK: - Push Notifications (Admin)

enum NotificationAudience: String, CaseIterable {
    case everyone = "Everyone"
    case ticketHolders = "Ticket Holders"
    case vipOnly = "VIP Holders"
}

struct SentNotification: Identifiable {
    let id: String
    let title: String
    let body: String
    let audience: NotificationAudience
    let eventId: String?
    let sentAt: Date
    var recipientCount: Int
}

// MARK: - Basket

struct BasketItem: Identifiable {
    let id = UUID().uuidString
    let tier: TicketTier
    var quantity: Int

    var subtotalInPence: Int { tier.priceInPence * quantity }
    var bookingFeeInPence: Int { tier.bookingFee * quantity }
    var totalInPence: Int { subtotalInPence + bookingFeeInPence }
}

struct DrinksVoucher: Identifiable {
    let id: String
    let packageName: String
    let totalDrinks: Int
    var drinksUsed: Int
    let purchasedAt: Date

    var drinksRemaining: Int { totalDrinks - drinksUsed }
    var qrCode: String { "DRINKS-\(id.prefix(8).uppercased())" }
}
