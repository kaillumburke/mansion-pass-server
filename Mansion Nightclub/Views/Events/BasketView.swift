import SwiftUI
import StripePaymentSheet

struct BasketView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showConfirmation = false
    @State private var purchasedOrder: Order?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var clientSecret: String?
    @State private var showPayment = false
    @State private var pendingEvent: AppEvent?

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if appState.basket.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "basket")
                            .font(.system(size: 48))
                            .foregroundColor(.textSecondary)
                        Text("Your basket is empty")
                            .font(.titleMedium)
                            .foregroundColor(.textSecondary)
                    }
                } else {
                    VStack(spacing: 0) {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                ForEach(appState.basket) { item in
                                    BasketItemRow(item: item)
                                }

                                // Fee breakdown
                                VStack(spacing: 0) {
                                    feeRow("Tickets", pence: appState.basket.reduce(0) { $0 + $1.subtotalInPence })
                                    Divider().background(Color.divider)
                                    feeRow("Booking Fee", pence: appState.basket.reduce(0) { $0 + $1.bookingFeeInPence })
                                    Divider().background(Color.divider)
                                    HStack {
                                        Text("Total")
                                            .font(.titleMedium).foregroundColor(.white)
                                        Spacer()
                                        Text(formattedPence(appState.basketTotal))
                                            .font(.titleMedium).foregroundColor(.brand)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                }
                                .background(Color.surface)
                                .cornerRadius(14)
                            }
                            .padding(20)
                            .padding(.bottom, 120)
                        }

                        // Checkout button
                        VStack(spacing: 0) {
                            Divider().background(Color.divider)
                            if let err = errorMessage {
                                Text(err)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                            }
                            Button(action: checkout) {
                                ZStack {
                                    if isProcessing {
                                        ProgressView().tint(.white)
                                    } else {
                                        HStack {
                                            Text("Checkout")
                                                .font(.titleMedium).foregroundColor(.white)
                                            Spacer()
                                            Text(formattedPence(appState.basketTotal))
                                                .font(.titleMedium).foregroundColor(.white.opacity(0.8))
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                                .frame(height: 54)
                                .background(Color.brand)
                                .cornerRadius(14)
                                .padding(.horizontal, 20).padding(.vertical, 12)
                            }
                            .disabled(isProcessing)
                        }
                        .background(Color.appBackground)
                    }
                }
            }
            .navigationTitle("Basket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }.foregroundColor(.brand)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !appState.basket.isEmpty {
                        Button("Clear") { appState.clearBasket() }
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPayment) {
            if let secret = clientSecret, let event = pendingEvent {
                let preBasket = appState.basket
                let tierNames = preBasket.map { "\($0.quantity)x \($0.tier.name)" }.joined(separator: ", ")
                let totalAmt = preBasket.reduce(0) { $0 + $1.subtotalInPence }
                let totalBF = preBasket.reduce(0) { $0 + $1.bookingFeeInPence }
                let totalStr = formattedPence(appState.basketTotal)
                StripePaymentView(
                    clientSecret: secret,
                    total: totalStr,
                    tierName: tierNames,
                    eventName: event.name,
                    quantity: preBasket.reduce(0) { $0 + $1.quantity },
                    onSuccess: {
                        let tickets = preBasket.flatMap { item -> [Ticket] in
                            (0..<item.quantity).map { _ in
                                Ticket(id: UUID().uuidString, orderId: UUID().uuidString,
                                       tier: item.tier, event: event,
                                       qrCode: TicketService.generateQRCode(),
                                       status: .valid, createdAt: Date())
                            }
                        }
                        purchasedOrder = Order(id: UUID().uuidString, event: event, tickets: tickets,
                                               totalAmountInPence: totalAmt, bookingFeePaidInPence: totalBF,
                                               status: .completed, createdAt: Date())
                        appState.purchaseBasket(event: event)
                        showPayment = false
                        showConfirmation = true
                    },
                    onBack: { showPayment = false },
                    onError: { msg in errorMessage = msg; showPayment = false }
                )
                .environmentObject(appState)
            }
        }
        .sheet(isPresented: $showConfirmation) {
            if let order = purchasedOrder {
                OrderConfirmationView(order: order)
                    .environmentObject(appState)
            }
        }
        .onChange(of: showConfirmation) { isShowing in
            if !isShowing && purchasedOrder != nil {
                dismiss()
            }
        }
    }

    func checkout() {
        guard let tierId = appState.basket.first?.tier.id,
              let event = appState.events.first(where: { $0.tiers.contains(where: { $0.id == tierId }) }),
              let currentUser = appState.currentUser else {
            errorMessage = appState.currentUser == nil ? "Please log in to purchase tickets." : "Could not find event."
            return
        }

        isProcessing = true
        errorMessage = nil
        pendingEvent = event

        let tierNames = appState.basket.map { "\($0.quantity)x \($0.tier.name)" }.joined(separator: ", ")
        let totalQty = appState.basket.reduce(0) { $0 + $1.quantity }

        Task {
            do {
                let response = try await StripeService.shared.createPaymentIntent(
                    amountInPence: appState.basketTotal,
                    eventId: event.id,
                    eventName: event.name,
                    tierName: tierNames,
                    userEmail: currentUser.email,
                    quantity: totalQty
                )
                await MainActor.run {
                    clientSecret = response.clientSecret
                    isProcessing = false
                    showPayment = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    func feeRow(_ label: String, pence: Int) -> some View {
        HStack {
            Text(label).font(.bodyMedium).foregroundColor(.textSecondary)
            Spacer()
            Text(formattedPence(pence)).font(.bodyMedium).foregroundColor(.white)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    func formattedPence(_ pence: Int) -> String {
        "£\(String(format: "%.2f", Double(pence) / 100))"
    }
}

struct BasketItemRow: View {
    let item: BasketItem
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.tier.name)
                    .font(.titleMedium).foregroundColor(.white)
                Text("× \(item.quantity)")
                    .font(.bodyMedium).foregroundColor(.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("£\(String(format: "%.2f", Double(item.totalInPence) / 100))")
                    .font(.titleMedium).foregroundColor(.brand)
                Text("incl. booking fee")
                    .font(.caption).foregroundColor(.textSecondary)
            }
            Button {
                appState.removeFromBasket(id: item.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(14)
        .background(Color.surface)
        .cornerRadius(12)
    }
}
