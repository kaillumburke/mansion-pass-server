import Foundation
import FirebaseFirestore
import Combine

// MARK: - Firestore Ticket (flat, serialisable)

struct FirestoreTicket: Identifiable, Codable {
    let id: String
    let orderId: String
    // Buyer identity
    let userId: String
    let userEmail: String
    let userName: String
    var userPhone: String?
    var userDOB: String?        // ISO "yyyy-MM-dd"
    // Event + tier
    let eventId: String
    let eventName: String
    let tierId: String
    let tierName: String
    let tierPriceInPence: Int
    // Ticket state
    let qrCode: String
    var status: String
    let createdAt: Date
    let eventDate: Date
    let doorsOpen: Date?
    var scannedAt: Date?
    // Co-brand (future)
    var cobrandRef: String?

    var statusEnum: TicketStatus {
        TicketStatus(rawValue: status.uppercased()) ?? .valid
    }
}

// MARK: - Ticket Service

final class TicketService {
    static let shared = TicketService()
    private let db = Firestore.firestore()
    private init() {}

    // MARK: - Save tickets after purchase

    func saveTickets(_ tickets: [FirestoreTicket]) async throws {
        let batch = db.batch()
        for ticket in tickets {
            let ref = db.collection("tickets").document(ticket.id)
            try batch.setData(from: ticket, forDocument: ref)
        }
        try await batch.commit()
    }

    // MARK: - Fetch all tickets (admin)

    func fetchAllTickets() async throws -> [FirestoreTicket] {
        let snapshot = try await db.collection("tickets")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FirestoreTicket.self) }
    }

    // MARK: - Fetch tickets for current user

    func fetchMyTickets(userId: String) async throws -> [FirestoreTicket] {
        let snapshot = try await db.collection("tickets")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FirestoreTicket.self) }
    }

    // MARK: - Validate and scan a QR code

    func scanQRCode(_ qrCode: String) async throws -> ScanOutcome {
        let snapshot = try await db.collection("tickets")
            .whereField("qrCode", isEqualTo: qrCode)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first,
              var ticket = try? doc.data(as: FirestoreTicket.self) else {
            return .invalid
        }

        if ticket.status == "used" {
            return .alreadyUsed(ticket)
        }

        // Mark as used
        try await db.collection("tickets").document(ticket.id).updateData([
            "status": "used",
            "scannedAt": Timestamp(date: Date())
        ])
        ticket.status = "used"
        ticket.scannedAt = Date()
        return .valid(ticket)
    }

    enum ScanOutcome {
        case valid(FirestoreTicket)
        case alreadyUsed(FirestoreTicket)
        case invalid
    }
}

// MARK: - Unique QR generator

extension TicketService {
    static func generateQRCode() -> String {
        "MNS-\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).uppercased())"
    }
}
