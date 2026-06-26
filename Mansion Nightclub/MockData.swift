import Foundation

struct MockData {

    static let user = AppUser(
        id: "user-1",
        firstName: "Alex",
        lastName: "Johnson",
        email: "alex@example.com",
        phone: "+447700900000",
        role: .customer,
        createdAt: Date()
    )

    static let promoter = AppUser(
        id: "promoter-1",
        firstName: "Eric",
        lastName: "McKenna",
        email: "eric@mansion.com",
        phone: "+447700900001",
        role: .admin,
        createdAt: Date()
    )

    static let events: [AppEvent] = [
        AppEvent(
            id: "event-1",
            name: "MANSION SATURDAYS",
            description: "Liverpool's biggest Saturday night returns to Mansion. Three rooms, eight hours, zero compromise. Featuring residents B2B alongside special guests from Berlin's finest clubs.",
            date: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 22))!,
            endTime: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 6))!,
            doorsOpen: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 22))!,
            lastEntry: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 2))!,
            venue: "Mansion Nightclub, Liverpool",
            ageRestriction: 18,
            artworkGradient: ["#1a0a00", "#3d1f00"],
            artworkImageName: nil,
            capacity: 500,
            status: .published,
            tiers: [
                // General Entry
                TicketTier(id: "tier-1a", eventId: "event-1", name: "Earlybird", description: "Discounted entry to Mansion Saturdays. Last entry Midnight.", priceInPence: 500, quantity: 100, sold: 72, saleStartsAt: nil, saleEndsAt: nil, dependsOnTierId: nil, minPerOrder: 1, maxPerOrder: 6, isVisible: true),
                TicketTier(id: "tier-1b", eventId: "event-1", name: "General Admission", description: "Guaranteed entry to Mansion.", priceInPence: 1000, quantity: 250, sold: 140, saleStartsAt: nil, saleEndsAt: nil, dependsOnTierId: nil, minPerOrder: 1, maxPerOrder: 6, isVisible: true),
                TicketTier(id: "tier-1c", eventId: "event-1", name: "Mansion & Vice", description: "Admission to Mansion & Vice afterhours.", priceInPence: 1500, quantity: 150, sold: 61, saleStartsAt: nil, saleEndsAt: nil, dependsOnTierId: nil, minPerOrder: 1, maxPerOrder: 6, isVisible: true),
                // Vice Afterhours
                TicketTier(id: "tier-1d", eventId: "event-1", name: "Vice Early Access", description: "Receive your Vice Stamp entry into Mansion from 2am. Last entry 3:30am.", priceInPence: 1000, quantity: 100, sold: 38, saleStartsAt: nil, saleEndsAt: nil, dependsOnTierId: nil, minPerOrder: 1, maxPerOrder: 6, isVisible: true),
                // Add-ons
                TicketTier(id: "tier-1e", eventId: "event-1", name: "5 Single Spirit Mixers", description: "5 single house spirit & mixers for just £20 instead of £32.50.", priceInPence: 2000, quantity: 200, sold: 14, saleStartsAt: nil, saleEndsAt: nil, dependsOnTierId: nil, minPerOrder: 1, maxPerOrder: 4, isVisible: true),
                TicketTier(id: "tier-1f", eventId: "event-1", name: "5 Double Spirit Mixers", description: "5 double house spirit & mixers for just £35 instead of £55.", priceInPence: 3500, quantity: 200, sold: 9, saleStartsAt: nil, saleEndsAt: nil, dependsOnTierId: nil, minPerOrder: 1, maxPerOrder: 4, isVisible: true),
                TicketTier(id: "tier-1g", eventId: "event-1", name: "5 Beers Deal", description: "5 bottled beers for just £25 instead of £30.", priceInPence: 2500, quantity: 200, sold: 7, saleStartsAt: nil, saleEndsAt: nil, dependsOnTierId: nil, minPerOrder: 1, maxPerOrder: 4, isVisible: true),
            ]
        ),
        AppEvent(
            id: "event-2",
            name: "BANK HOLIDAY SPECIAL",
            description: "Make the most of the bank holiday weekend. Doors open early, music plays late. Our biggest lineup of the year.",
            date: Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 21))!,
            endTime: Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 2, hour: 5))!,
            doorsOpen: Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 21))!,
            lastEntry: Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 2, hour: 1))!,
            venue: "Mansion Nightclub, Liverpool",
            ageRestriction: 18,
            artworkGradient: ["#0a0a0a", "#2a1f0a"],
            artworkImageName: nil,
            capacity: 500,
            status: .published,
            tiers: [
                TicketTier(id: "tier-2a", eventId: "event-2", name: "Early Bird", description: "Limited early bird tickets.", priceInPence: 1000, quantity: 80, sold: 55, saleStartsAt: nil, saleEndsAt: nil, dependsOnTierId: nil, minPerOrder: 1, maxPerOrder: 4, isVisible: true),
                TicketTier(id: "tier-2b", eventId: "event-2", name: "Standard", description: "General admission.", priceInPence: 1500, quantity: 220, sold: 90, saleStartsAt: nil, saleEndsAt: nil, dependsOnTierId: nil, minPerOrder: 1, maxPerOrder: 6, isVisible: true),
                TicketTier(id: "tier-2c", eventId: "event-2", name: "VIP", description: "VIP entry with queue jump.", priceInPence: 2500, quantity: 40, sold: 8, saleStartsAt: nil, saleEndsAt: nil, dependsOnTierId: nil, minPerOrder: 1, maxPerOrder: 4, isVisible: true)
            ]
        )
    ]

    static let myTickets: [Ticket] = [
        Ticket(
            id: "ticket-1",
            orderId: "order-1",
            tier: events[0].tiers[1], // General Admission
            event: events[0],
            qrCode: "MNS-1234-ABCD5678",
            status: .valid,
            createdAt: Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        )
    ]

    static let myOrders: [Order] = [
        Order(
            id: "order-1",
            event: events[0],
            tickets: myTickets,
            totalAmountInPence: 1000,
            bookingFeePaidInPence: 100,
            status: .completed,
            createdAt: Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        )
    ]

    static let drinksPackages: [DrinksPackage] = [
        DrinksPackage(id: "drinks-1", name: "5 Single Spirit Mixers", description: "5 single house spirit & mixers — save over £12 vs bar price.", includes: ["5 x single house spirit", "5 x mixer of choice", "Redeemable at any bar"], priceInPence: 2000, isPopular: false),
        DrinksPackage(id: "drinks-2", name: "5 Double Spirit Mixers", description: "5 double house spirit & mixers — save £20 vs bar price.", includes: ["5 x double house spirit", "5 x mixer of choice", "Redeemable at any bar"], priceInPence: 3500, isPopular: true),
        DrinksPackage(id: "drinks-3", name: "5 Beers Deal", description: "5 bottled beers — save £5 vs bar price.", includes: ["5 x bottled beer", "Redeemable at any bar"], priceInPence: 2500, isPopular: false)
    ]

    static let notifications: [AppNotification] = [
        AppNotification(id: "notif-1", title: "Tickets Confirmed!", body: "Your Standard ticket for MANSION SATURDAYS has been confirmed.", eventId: "event-1", sentAt: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, isRead: false),
        AppNotification(id: "notif-2", title: "Doors open at 10PM", body: "Show your QR code at entry. See you on the floor.", eventId: "event-1", sentAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, isRead: false)
    ]

    static let drinksVouchers: [DrinksVoucher] = [
        DrinksVoucher(id: "voucher-1", packageName: "5 Double Spirit Mixers", totalDrinks: 5, drinksUsed: 2, purchasedAt: Date())
    ]
}

