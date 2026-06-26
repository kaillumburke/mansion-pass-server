import SwiftUI

struct OrderConfirmationView: View {
    let order: Order
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    Spacer().frame(height: 20)

                    // Checkmark
                    ZStack {
                        Circle()
                            .fill(Color.brand.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "checkmark")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.brand)
                    }

                    VStack(spacing: 8) {
                        Text("YOU'RE IN")
                            .font(.displayMedium).textCase(.uppercase).tracking(0)
                            .foregroundColor(.white)
                        Text("Your tickets have been confirmed")
                            .font(.bodyLarge).foregroundColor(.textSecondary)
                    }

                    // Order summary
                    VStack(spacing: 0) {
                        HStack {
                            Text("Event")
                                .font(.bodyMedium).foregroundColor(.textSecondary)
                            Spacer()
                            Text(order.event.name)
                                .font(.titleMedium).foregroundColor(.white)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)

                        Divider().background(Color.divider)

                        HStack {
                            Text("Date")
                                .font(.bodyMedium).foregroundColor(.textSecondary)
                            Spacer()
                            Text(order.event.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.bodyMedium).foregroundColor(.white)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)

                        Divider().background(Color.divider)

                        HStack {
                            Text("Tickets")
                                .font(.bodyMedium).foregroundColor(.textSecondary)
                            Spacer()
                            Text("\(order.tickets.count)")
                                .font(.titleMedium).foregroundColor(.brand)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)

                        Divider().background(Color.divider)

                        HStack {
                            Text("Total Paid")
                                .font(.titleMedium).foregroundColor(.white)
                            Spacer()
                            Text(order.totalFormatted)
                                .font(.titleMedium).foregroundColor(.brand)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                    .background(Color.surface)
                    .cornerRadius(14)
                    .padding(.horizontal, 20)

                    // QR codes preview
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Rectangle().fill(Color.brand).frame(width: 3, height: 14)
                            Text("YOUR TICKETS")
                                .font(.label).tracking(3).foregroundColor(.brand)
                        }
                        .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(order.tickets.prefix(3)) { ticket in
                                    MiniTicketCard(ticket: ticket)
                                }
                                if order.tickets.count > 3 {
                                    Text("+\(order.tickets.count - 3) more")
                                        .font(.bodyMedium).foregroundColor(.textSecondary)
                                        .frame(width: 80, height: 100)
                                        .background(Color.surface)
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    Button {
                        appState.selectedTab = 2
                        dismiss()
                    } label: {
                        Text("View My Tickets")
                            .font(.titleMedium).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(Color.brand)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct MiniTicketCard: View {
    let ticket: Ticket

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "qrcode")
                .font(.system(size: 40))
                .foregroundColor(.brand)
            Text(ticket.tier.name)
                .font(.caption).foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(width: 100, height: 100)
        .background(Color.surface)
        .cornerRadius(12)
    }
}
