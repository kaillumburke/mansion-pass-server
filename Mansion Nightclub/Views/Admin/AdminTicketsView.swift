import SwiftUI

struct AdminTicketsView: View {
    @State private var tickets: [FirestoreTicket] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var filterStatus: String? = nil

    private var filtered: [FirestoreTicket] {
        tickets.filter { ticket in
            let matchesSearch = searchText.isEmpty ||
                ticket.userName.localizedCaseInsensitiveContains(searchText) ||
                ticket.userEmail.localizedCaseInsensitiveContains(searchText) ||
                ticket.qrCode.localizedCaseInsensitiveContains(searchText) ||
                ticket.tierName.localizedCaseInsensitiveContains(searchText) ||
                ticket.eventName.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = filterStatus == nil || ticket.status == filterStatus
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Stats bar
                if !tickets.isEmpty {
                    HStack(spacing: 0) {
                        statCell(value: "\(tickets.count)", label: "TOTAL")
                        Divider().frame(height: 36).background(Color.divider)
                        statCell(value: "\(tickets.filter { $0.status == "valid" }.count)", label: "VALID")
                        Divider().frame(height: 36).background(Color.divider)
                        statCell(value: "\(tickets.filter { $0.status == "used" }.count)", label: "SCANNED")
                    }
                    .padding(.vertical, 12)
                    .background(Color.surface)

                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip(label: "All", value: nil)
                            filterChip(label: "Valid", value: "valid")
                            filterChip(label: "Scanned", value: "used")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.surface)

                    Divider().background(Color.divider)
                }

                if isLoading {
                    Spacer()
                    ProgressView().tint(Color.brand)
                    Spacer()
                } else if filtered.isEmpty {
                    Spacer()
                    Text(tickets.isEmpty ? "No tickets sold yet" : "No results")
                        .font(.bodyMedium).foregroundColor(.textSecondary)
                    Spacer()
                } else {
                    List {
                        ForEach(filtered) { ticket in
                            AdminTicketRow(ticket: ticket)
                                .listRowBackground(Color.surface)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Search by name, email or QR code")
                }
            }
        }
        .navigationTitle("All Tickets")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            let result = try await TicketService.shared.fetchAllTickets()
            await MainActor.run {
                tickets = result
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    @ViewBuilder
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.titleMedium).foregroundColor(.white)
            Text(label)
                .font(.caption).tracking(1.5).foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func filterChip(label: String, value: String?) -> some View {
        Button { filterStatus = value } label: {
            Text(label)
                .font(.caption).tracking(1)
                .foregroundColor(filterStatus == value ? .black : .textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(filterStatus == value ? Color.brand : Color.appBackground)
                .cornerRadius(20)
        }
    }
}

// MARK: - Ticket Row

struct AdminTicketRow: View {
    let ticket: FirestoreTicket
    @State private var expanded = false

    var statusColor: Color {
        ticket.status == "used" ? .orange : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } } label: {
                HStack(spacing: 12) {
                    // Status dot
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(ticket.userName)
                            .font(.bodyMedium).foregroundColor(.white)
                        Text("\(ticket.tierName) — \(ticket.eventName)")
                            .font(.caption).foregroundColor(.textSecondary)
                    }

                    Spacer()

                    Text(ticket.status == "used" ? "SCANNED" : "VALID")
                        .font(.caption).tracking(1)
                        .foregroundColor(statusColor)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().background(Color.divider)

                    detailRow(label: "QR Code", value: ticket.qrCode)
                    detailRow(label: "Email", value: ticket.userEmail)
                    detailRow(label: "Ticket ID", value: String(ticket.id.prefix(8).uppercased()))
                    detailRow(label: "Order ID", value: String(ticket.orderId.prefix(8).uppercased()))
                    detailRow(label: "Price", value: "£\(String(format: "%.2f", Double(ticket.tierPriceInPence) / 100))")
                    detailRow(label: "Purchased", value: ticket.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if let scanned = ticket.scannedAt {
                        detailRow(label: "Scanned at", value: scanned.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption).tracking(0.5).foregroundColor(.textSecondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.caption).foregroundColor(.white)
                .lineLimit(1)
        }
    }
}
