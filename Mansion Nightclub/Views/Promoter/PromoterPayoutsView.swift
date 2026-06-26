import SwiftUI

struct PromoterPayoutsView: View {
    @EnvironmentObject var appState: AppState

    var completedEvents: [AppEvent] {
        appState.events.filter { $0.status == .completed }.sorted { $0.date > $1.date }
    }

    var upcomingEvents: [AppEvent] {
        appState.events.filter { $0.status == .published }.sorted { $0.date < $1.date }
    }

    var totalPaid: Int {
        completedEvents.filter { $0.payoutDate != nil && $0.payoutDate! <= Date() }
            .reduce(0) { $0 + $1.promoterRevenue }
    }

    var totalPending: Int {
        completedEvents.filter { $0.payoutDate == nil || $0.payoutDate! > Date() }
            .reduce(0) { $0 + $1.promoterRevenue }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        // Summary cards
                        HStack(spacing: 12) {
                            PayoutSummaryCard(label: "Total Paid Out", value: totalPaid, icon: "checkmark.circle.fill", color: .green)
                            PayoutSummaryCard(label: "Pending", value: totalPending, icon: "clock.fill", color: .orange)
                        }

                        if !completedEvents.isEmpty {
                            sectionHeader("COMPLETED EVENTS")
                            VStack(spacing: 12) {
                                ForEach(completedEvents) { event in
                                    PayoutEventRow(event: event)
                                }
                            }
                        }

                        if !upcomingEvents.isEmpty {
                            sectionHeader("UPCOMING")
                            VStack(spacing: 12) {
                                ForEach(upcomingEvents) { event in
                                    UpcomingRevenueRow(event: event)
                                }
                            }
                        }

                        if completedEvents.isEmpty && upcomingEvents.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "banknote")
                                    .font(.system(size: 44))
                                    .foregroundColor(.textSecondary)
                                Text("No payouts yet")
                                    .font(.titleMedium).foregroundColor(.textSecondary)
                                Text("Payouts are released the Wednesday after each completed event.")
                                    .font(.bodyMedium).foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Revenue")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    func sectionHeader(_ text: String) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.brand).frame(width: 3, height: 14)
            Text(text).font(.label).tracking(3).foregroundColor(.brand)
        }
    }
}

struct PayoutSummaryCard: View {
    let label: String
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundColor(color).font(.title3)
            Text("£\(String(format: "%.2f", Double(value) / 100))")
                .font(.displayMedium).foregroundColor(.white)
            Text(label).font(.caption).foregroundColor(.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

struct PayoutEventRow: View {
    let event: AppEvent

    var isPaid: Bool {
        guard let d = event.payoutDate else { return false }
        return d <= Date()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.name)
                        .font(.titleMedium).textCase(.uppercase).tracking(0)
                        .foregroundColor(.white)
                    Text(event.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundColor(.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("£\(String(format: "%.2f", Double(event.promoterRevenue) / 100))")
                        .font(.titleMedium).foregroundColor(.brand)
                    if isPaid {
                        Text("PAID").font(.caption).tracking(1).foregroundColor(.green)
                    } else if let date = event.payoutDate {
                        Text("Due \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundColor(.orange)
                    } else {
                        Text("LOCKED").font(.caption).tracking(1).foregroundColor(.textSecondary)
                    }
                }
            }
            .padding(14)

            Divider().background(Color.divider)

            HStack(spacing: 0) {
                miniStat("Gross", value: event.grossRevenue)
                Divider().background(Color.divider)
                miniStat("Booking Fees", value: event.netBookingFees)
                Divider().background(Color.divider)
                miniStat("Tickets", value: event.ticketsSold, isCurrency: false)
            }
        }
        .background(Color.surface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brand.opacity(0.12), lineWidth: 1))
    }

    func miniStat(_ label: String, value: Int, isCurrency: Bool = true) -> some View {
        VStack(spacing: 3) {
            Text(isCurrency ? "£\(String(format: "%.2f", Double(value) / 100))" : "\(value)")
                .font(.bodyMedium).foregroundColor(.white)
            Text(label).font(.caption).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

struct UpcomingRevenueRow: View {
    let event: AppEvent

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.titleMedium).textCase(.uppercase).tracking(0)
                    .foregroundColor(.white)
                Text(event.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundColor(.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("£\(String(format: "%.2f", Double(event.promoterRevenue) / 100))")
                    .font(.titleMedium).foregroundColor(.brand)
                Text("\(event.ticketsSold) sold")
                    .font(.caption).foregroundColor(.textSecondary)
            }
        }
        .padding(14)
        .background(Color.surface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.divider, lineWidth: 1))
    }
}
