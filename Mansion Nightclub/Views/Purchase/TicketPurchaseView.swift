import SwiftUI
import PassKit
import StripePaymentSheet

struct TicketPurchaseView: View {
    let event: AppEvent
    let tier: TicketTier
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var quantity = 1
    @State private var step: PurchaseStep = .summary
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var clientSecret: String?
    @State private var paymentIntentId: String?

    enum PurchaseStep {
        case summary, payment, confirmation
    }

    var total: Int { tier.priceInPence * quantity }
    var totalFormatted: String {
        total == 0 ? "Free" : "£\(String(format: "%.2f", Double(total) / 100))"
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                switch step {
                case .summary:
                    summaryView
                case .payment:
                    paymentView
                case .confirmation:
                    confirmationView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step == .summary {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(.brand)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(step == .confirmation ? "Confirmed" : "Checkout")
                        .font(.titleMedium)
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    var summaryView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Event header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.name)
                            .font(.titleLarge).textCase(.uppercase)
                            .foregroundColor(.white)
                        let f = DateFormatter()
                        let _ = { f.dateFormat = "EEE d MMM · h:mm a" }()
                        Text(f.string(from: event.date))
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                        Text(event.venue)
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surface)
                    .cornerRadius(14)

                    // Tier + quantity
                    VStack(spacing: 0) {
                        HStack {
                            Text(tier.name)
                                .font(.titleMedium)
                                .foregroundColor(.white)
                            Spacer()
                            Text(tier.priceFormatted)
                                .font(.titleMedium)
                                .foregroundColor(.brand)
                        }
                        .padding(16)

                        Divider().background(Color.divider)

                        HStack {
                            Text("Quantity")
                                .font(.bodyMedium)
                                .foregroundColor(.textSecondary)
                            Spacer()
                            HStack(spacing: 16) {
                                Button(action: { if quantity > 1 { quantity -= 1 } }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(quantity > 1 ? .brand : .textSecondary)
                                }
                                Text("\(quantity)")
                                    .font(.titleMedium)
                                    .foregroundColor(.white)
                                    .frame(width: 24)
                                Button(action: { if quantity < min(4, tier.available) { quantity += 1 } }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(quantity < min(4, tier.available) ? .brand : .textSecondary)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .background(Color.surface)
                    .cornerRadius(14)

                    // Total
                    HStack {
                        Text("Total")
                            .font(.titleMedium)
                            .foregroundColor(.white)
                        Spacer()
                        Text(totalFormatted)
                            .font(.displayMedium).textCase(.uppercase)
                            .foregroundColor(.brand)
                    }
                    .padding(16)
                    .background(Color.surface)
                    .cornerRadius(14)

                    // Booking fee note
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text("A 10% booking fee is included in the price shown.")
                            .font(.caption)
                    }
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 4)
                }
                .padding(20)
            }

            Button(action: proceedToPayment) {
                ZStack {
                    if isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue to Payment")
                            .font(.titleMedium)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.brand)
                .cornerRadius(14)
            }
            .disabled(isProcessing)
            .padding(20)
        }
    }

    var paymentView: some View {
        StripePaymentView(
            clientSecret: clientSecret ?? "",
            total: totalFormatted,
            tierName: tier.name,
            eventName: event.name,
            quantity: quantity,
            onSuccess: {
                appState.purchaseTickets(event: event, tier: tier, quantity: quantity)
                step = .confirmation
            },
            onBack: { step = .summary },
            onError: { msg in errorMessage = msg; step = .summary }
        )
    }

    var confirmationView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.brand.opacity(0.2))
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark")
                        .font(.displayLarge)
                        .foregroundColor(.brand)
                }

                VStack(spacing: 8) {
                    Text("You're going!")
                        .font(.displayMedium).textCase(.uppercase)
                        .foregroundColor(.white)
                    Text("\(quantity)x \(tier.name) ticket\(quantity > 1 ? "s" : "") confirmed for")
                        .font(.bodyLarge)
                        .foregroundColor(.textSecondary)
                    Text(event.name)
                        .font(.titleLarge).textCase(.uppercase)
                        .foregroundColor(.brand)
                    Text("Your ticket has been emailed to you with an Apple Wallet pass.")
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)

            Button(action: { dismiss() }) {
                Text("View My Tickets")
                    .font(.titleMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.brand)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func proceedToPayment() {
        guard let currentUser = appState.currentUser else { return }
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let response = try await StripeService.shared.createPaymentIntent(
                    amountInPence: total,
                    eventId: event.id,
                    eventName: event.name,
                    tierName: tier.name,
                    userEmail: currentUser.email,
                    quantity: quantity
                )
                await MainActor.run {
                    clientSecret = response.clientSecret
                    paymentIntentId = response.paymentIntentId
                    isProcessing = false
                    step = .payment
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Stripe Native Payment Sheet

struct StripePaymentView: View {
    let clientSecret: String
    let total: String
    let tierName: String
    let eventName: String
    let quantity: Int
    let onSuccess: () -> Void
    let onBack: () -> Void
    let onError: (String) -> Void

    @State private var paymentSheet: PaymentSheet?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Order recap
                VStack(spacing: 8) {
                    Text(eventName)
                        .font(.titleMedium)
                        .foregroundColor(.white)
                    Text("\(quantity)x \(tierName)")
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                    Text(total)
                        .font(.displayMedium)
                        .foregroundColor(.brand)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.surface)
                .cornerRadius(14)
                .padding(.horizontal, 20)

                if isLoading {
                    ProgressView()
                        .tint(Color.brand)
                        .padding()
                }
            }

            Spacer()

            VStack(spacing: 12) {
                if let sheet = paymentSheet {
                    PaymentSheet.PaymentButton(
                        paymentSheet: sheet,
                        onCompletion: handleResult
                    ) {
                        Text("Pay \(total)")
                            .font(.titleMedium)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.brand)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 20)
                }

                Button(action: onBack) {
                    Text("Back")
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                }
                .padding(.bottom, 8)
            }
            .padding(.bottom, 20)
        }
        .background(Color.appBackground)
        .onAppear { preparePaymentSheet() }
    }

    private func preparePaymentSheet() {
        STPAPIClient.shared.publishableKey = "pk_test_51TiDyxLKrlN8iiicyEwh9dlVYaXSV11VLtEPie2rkHRe8zvFODQN6YPTyzTBbxkSilC2i8ddEpCzPSDGwjw04yhp00IQM1gmlP"

        var config = PaymentSheet.Configuration()
        config.merchantDisplayName = "Mansion Nightclub"
        config.appearance = stripeAppearance()
        config.allowsDelayedPaymentMethods = false
        config.applePay = .init(
            merchantId: "merchant.com.mansionnightclub.liverpool",
            merchantCountryCode: "GB"
        )

        paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: config)
        isLoading = false
    }

    private func handleResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            onSuccess()
        case .canceled:
            break
        case .failed(let error):
            onError(error.localizedDescription)
        }
    }

    private func stripeAppearance() -> PaymentSheet.Appearance {
        var appearance = PaymentSheet.Appearance()
        appearance.colors.background = UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
        appearance.colors.componentBackground = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
        appearance.colors.componentBorder = UIColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1)
        appearance.colors.primary = UIColor(red: 0.788, green: 0.659, blue: 0.298, alpha: 1)
        appearance.colors.text = .white
        appearance.colors.textSecondary = UIColor(red: 0.53, green: 0.53, blue: 0.53, alpha: 1)
        appearance.cornerRadius = 12
        return appearance
    }
}


#Preview {
    TicketPurchaseView(event: MockData.events[0], tier: MockData.events[0].tiers[1])
        .environmentObject(AppState())
}
