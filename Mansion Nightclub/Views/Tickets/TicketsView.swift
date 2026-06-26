import SwiftUI

struct TicketsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTicket: Ticket? = nil
    @State private var showPast = false

    var activeTickets: [Ticket] {
        appState.myTickets.filter { $0.status == .valid }
    }

    var pastTickets: [Ticket] {
        appState.myTickets.filter { $0.status != .valid }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if appState.myTickets.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            if !activeTickets.isEmpty {
                                sectionHeader("Upcoming")
                                VStack(spacing: 12) {
                                    ForEach(activeTickets) { ticket in
                                        TicketCardView(ticket: ticket)
                                            .onTapGesture { selectedTicket = ticket }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 28)
                            }

                            if !pastTickets.isEmpty {
                                // Collapsible past tickets folder
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) { showPast.toggle() }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "archivebox.fill")
                                            .font(.caption)
                                            .foregroundColor(.textSecondary)
                                        Text("OLD TICKETS")
                                            .font(.label)
                                            .tracking(2)
                                            .foregroundColor(.textSecondary)
                                        Text("\(pastTickets.count)")
                                            .font(.caption)
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.textSecondary)
                                            .cornerRadius(8)
                                        Spacer()
                                        Image(systemName: showPast ? "chevron.up" : "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.textSecondary)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.surface.opacity(0.5))
                                    .cornerRadius(12)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 8)
                                }

                                if showPast {
                                    VStack(spacing: 12) {
                                        ForEach(pastTickets) { ticket in
                                            TicketCardView(ticket: ticket, isPast: true)
                                                .onTapGesture { selectedTicket = ticket }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 28)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("My Tickets")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedTicket) { ticket in
                TicketDetailView(ticket: ticket)
            }
        }
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.titleMedium)
            .foregroundColor(.textSecondary)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "ticket")
                .font(.displayLarge).textCase(.uppercase).tracking(0)
                .foregroundColor(.textSecondary)
            Text("No tickets yet")
                .font(.titleLarge).textCase(.uppercase).tracking(0)
                .foregroundColor(.white)
            Text("Browse upcoming events and get your tickets")
                .font(.bodyMedium)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

struct TicketCardView: View {
    let ticket: Ticket
    var isPast: Bool = false

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: ticket.event.date).uppercased()
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(isPast ? Color.textSecondary.opacity(0.4) : Color.brand)
                .frame(width: 4)

            HStack(spacing: 14) {
                LinearGradient(
                    colors: ticket.event.artworkGradient.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 60, height: 60)
                .cornerRadius(10)
                .opacity(isPast ? 0.5 : 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.event.name)
                        .font(.titleMedium)
                        .foregroundColor(isPast ? .textSecondary : .white)
                    Text(ticket.tier.name)
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                    Text(dateString)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: isPast ? "checkmark.circle" : "qrcode")
                        .font(.title2)
                        .foregroundColor(isPast ? .textSecondary : .brand)
                    Text(isPast ? "USED" : "VALID")
                        .font(.caption)
                        .tracking(1)
                        .foregroundColor(isPast ? .textSecondary : .green)
                }
            }
            .padding(14)
        }
        .background(Color.surface)
        .cornerRadius(14)
        .opacity(isPast ? 0.55 : 1)
    }
}

#Preview {
    TicketsView().environmentObject(AppState())
}
