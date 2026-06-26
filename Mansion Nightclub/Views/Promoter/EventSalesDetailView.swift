import SwiftUI
import FirebaseFirestore

struct EventSalesDetailView: View {
    let event: AppEvent
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showEdit = false

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // Event header
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.name)
                            .font(.displayMedium).textCase(.uppercase).tracking(0)
                            .foregroundColor(.white)
                        HStack(spacing: 12) {
                            Label(event.date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            Label(event.venue, systemImage: "mappin")
                        }
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                        Label("\(event.ageRestriction)+", systemImage: "person.fill")
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surface)
                    .cornerRadius(14)

                    // Revenue breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("REVENUE")

                        VStack(spacing: 0) {
                            revenueRow(label: "Gross Revenue", value: event.grossRevenue, color: .white)
                            Divider().background(Color.divider)
                            revenueRow(label: "Booking Fees (10%)", value: event.totalBookingFees, color: .brand)
                            Divider().background(Color.divider)
                            revenueRow(label: "Merchant Fees (0.6% of BF)", value: -event.merchantFees, color: .red)
                            Divider().background(Color.divider)
                            revenueRow(label: "Net Booking Fees", value: event.netBookingFees, color: .green)
                            Divider().background(Color.divider)
                            revenueRow(label: "Promoter Payout", value: event.promoterRevenue, color: .brand, bold: true)
                        }
                        .background(Color.surface)
                        .cornerRadius(14)

                        if let payoutDate = event.payoutDate {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.brand)
                                Text("Payout scheduled: \(payoutDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.bodyMedium)
                                    .foregroundColor(.textSecondary)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.textSecondary)
                                Text("Payout available the Wednesday after the event")
                                    .font(.bodyMedium)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }

                    // Ticket tiers
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("TICKET TIERS")

                        ForEach(event.tiers) { tier in
                            TierSalesRow(tier: tier)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Sales Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showEdit = true }
                    .foregroundColor(.brand)
            }
        }
        .sheet(isPresented: $showEdit) {
            EventSetupView(editingEvent: event)
        }
    }

    func sectionHeader(_ text: String) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.brand).frame(width: 3, height: 14)
            Text(text)
                .font(.label)
                .tracking(3)
                .foregroundColor(.brand)
        }
    }

    func revenueRow(label: String, value: Int, color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? .titleMedium : .bodyMedium)
                .foregroundColor(bold ? .white : .textSecondary)
            Spacer()
            Text((value < 0 ? "-" : "") + "£\(String(format: "%.2f", Double(abs(value)) / 100))")
                .font(bold ? .titleMedium : .bodyMedium)
                .foregroundColor(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct TierSalesRow: View {
    let tier: TicketTier

    var soldPercent: Double {
        tier.quantity > 0 ? Double(tier.sold) / Double(tier.quantity) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.name)
                        .font(.titleMedium)
                        .foregroundColor(.white)
                    Text(tier.priceFormatted)
                        .font(.bodyMedium)
                        .foregroundColor(.brand)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(tier.sold) / \(tier.quantity)")
                        .font(.titleMedium)
                        .foregroundColor(.white)
                    Text("\(tier.available) remaining")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.divider).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tier.isSoldOut ? Color.textSecondary : Color.brand)
                        .frame(width: geo.size.width * soldPercent, height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text("Revenue: £\(String(format: "%.2f", Double(tier.priceInPence * tier.sold) / 100))")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                Spacer()
                if tier.isSoldOut {
                    Text("SOLD OUT")
                        .font(.caption)
                        .tracking(1)
                        .foregroundColor(.red)
                } else if tier.isPendingOnSale, let start = tier.saleStartsAt {
                    Text("ON SALE \(start.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .tracking(1)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(14)
        .background(Color.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brand.opacity(0.12), lineWidth: 1))
    }
}
