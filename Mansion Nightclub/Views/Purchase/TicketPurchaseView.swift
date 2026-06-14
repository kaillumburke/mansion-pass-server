import SwiftUI
import PassKit

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
            onBack: { step = .summary }
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

// MARK: - Stripe Payment Web View

import WebKit

struct StripePaymentView: View {
    let clientSecret: String
    let total: String
    let tierName: String
    let eventName: String
    let quantity: Int
    let onSuccess: () -> Void
    let onBack: () -> Void

    @State private var cardNumber = ""
    @State private var expiry = ""
    @State private var cvc = ""
    @State private var nameOnCard = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Order recap
                    HStack {
                        Text("\(quantity)x \(tierName) — \(eventName)")
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                        Spacer()
                        Text(total)
                            .font(.titleMedium)
                            .foregroundColor(.white)
                    }
                    .padding(16)
                    .background(Color.surface)
                    .cornerRadius(12)

                    // Card form
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Card Details")
                            .font(.titleMedium)
                            .foregroundColor(.white)

                        CardInputField(label: "Card number", placeholder: "1234 5678 9012 3456", text: $cardNumber)
                            .keyboardType(.numberPad)
                        HStack(spacing: 12) {
                            CardInputField(label: "Expiry", placeholder: "MM/YY", text: $expiry)
                                .keyboardType(.numberPad)
                            CardInputField(label: "CVC", placeholder: "123", text: $cvc)
                                .keyboardType(.numberPad)
                        }
                        CardInputField(label: "Name on card", placeholder: "Your name", text: $nameOnCard)
                    }
                    .padding(16)
                    .background(Color.surface)
                    .cornerRadius(14)

                    if let error = errorMessage {
                        Text(error)
                            .font(.bodyMedium)
                            .foregroundColor(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                        Text("Payments secured by Stripe")
                    }
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                }
                .padding(20)
            }

            VStack(spacing: 12) {
                Button(action: processPayment) {
                    ZStack {
                        if isProcessing {
                            ProgressView().tint(.white)
                        } else {
                            Text("Pay \(total)")
                                .font(.titleMedium)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.brand)
                    .cornerRadius(14)
                }
                .disabled(isProcessing || cardNumber.isEmpty || expiry.isEmpty || cvc.isEmpty)

                Button(action: onBack) {
                    Text("Back")
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(20)
        }
        .background(Color.appBackground)
    }

    private func processPayment() {
        isProcessing = true
        errorMessage = nil
        // Stripe SDK payment sheet will be integrated here once SPM package is added.
        // For now simulate success after brief delay so UX flow is testable.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isProcessing = false
            onSuccess()
        }
    }
}

struct CardInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.label)
                .foregroundColor(.textSecondary)
            TextField(placeholder, text: $text)
                .font(.bodyLarge)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color.surfaceElevated)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.divider, lineWidth: 1))
        }
    }
}

#Preview {
    TicketPurchaseView(event: MockData.events[0], tier: MockData.events[0].tiers[1])
        .environmentObject(AppState())
}
