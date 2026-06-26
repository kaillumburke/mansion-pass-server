import SwiftUI

struct OrderHistoryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var expanded: String? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if appState.myOrders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bag")
                            .font(.system(size: 40))
                            .foregroundColor(.brand)
                        Text("No orders yet")
                            .font(.titleMedium)
                            .foregroundColor(.white)
                        Text("Your ticket purchases will appear here.")
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(appState.myOrders) { order in
                                OrderCard(order: order, isExpanded: expanded == order.id) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        expanded = expanded == order.id ? nil : order.id
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Order History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.brand)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct OrderCard: View {
    let order: Order
    let isExpanded: Bool
    let onTap: () -> Void

    var statusColor: Color {
        switch order.status {
        case .completed: return Color(hex: "#4ade80")
        case .pending:   return Color.brand
        case .cancelled, .refunded: return Color(hex: "#f87171")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button(action: onTap) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.event.name)
                            .font(.titleMedium)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(order.totalFormatted)
                            .font(.titleMedium)
                            .foregroundColor(.brand)
                        Text(order.status.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(statusColor)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded ticket list
            if isExpanded {
                Divider().background(Color.divider)

                VStack(spacing: 0) {
                    ForEach(order.tickets) { ticket in
                        HStack(spacing: 12) {
                            Image(systemName: "ticket.fill")
                                .font(.caption)
                                .foregroundColor(.brand)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(ticket.tier.name)
                                    .font(.bodyLarge)
                                    .foregroundColor(.white)
                                Text("QR: \(ticket.qrCode.prefix(12))…")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                                    .fontDesign(.monospaced)
                            }

                            Spacer()

                            Text("£\(String(format: "%.2f", Double(ticket.tier.priceInPence) / 100))")
                                .font(.bodyMedium)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if ticket.id != order.tickets.last?.id {
                            Divider().background(Color.divider).padding(.leading, 48)
                        }
                    }

                    // Total row
                    Divider().background(Color.divider)
                    HStack {
                        Text("\(order.tickets.count) ticket\(order.tickets.count == 1 ? "" : "s")")
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                        Spacer()
                        Text(order.totalFormatted)
                            .font(.titleMedium)
                            .foregroundColor(.brand)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.divider, lineWidth: 1)
        )
    }
}
