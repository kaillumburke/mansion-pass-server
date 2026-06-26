import SwiftUI
import StripePaymentSheet

struct DrinksPackagesView: View {
    let packages: [DrinksPackage]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.brand)
                            .frame(width: 3, height: 14)
                        Text("DRINKS PACKAGES")
                            .font(.label)
                            .tracking(3)
                            .foregroundColor(.brand)
                    }
                    Text("Book your table")
                        .font(.titleMedium)
                        .foregroundColor(.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(packages) { package in
                        DrinksPackageCard(package: package)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 36)
    }
}

struct DrinksPackageCard: View {
    let package: DrinksPackage
    @State private var showCheckout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top — name + popular badge
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(package.name)
                        .font(.titleLarge).textCase(.uppercase).tracking(0)
                        .foregroundColor(.white)
                    Spacer()
                    if package.isPopular {
                        Text("POPULAR")
                            .font(.caption)
                            .tracking(1)
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.brand)
                            .cornerRadius(6)
                    }
                }

                Text(package.description)
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
            }
            .padding(16)

            Divider().background(Color.divider)

            // Includes list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(package.includes, id: \.self) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.brand)
                            .frame(width: 4, height: 4)
                        Text(item)
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .padding(16)

            Spacer()

            Divider().background(Color.divider)

            // Price + CTA
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("From")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Text(package.priceFormatted)
                        .font(.displayMedium).textCase(.uppercase).tracking(0)
                        .foregroundColor(.brand)
                }
                Spacer()
                Button { showCheckout = true } label: {
                    Text("GET YOURS")
                        .font(.label)
                        .tracking(1)
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.brand)
                        .cornerRadius(10)
                }
            }
            .padding(16)
        }
        .frame(width: 260)
        .background(Color.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(package.isPopular ? Color.brand.opacity(0.5) : Color.brand.opacity(0.12), lineWidth: package.isPopular ? 1.5 : 1)
        )
        .sheet(isPresented: $showCheckout) {
            DrinksCheckoutView(package: package)
        }
    }
}

// MARK: - Checkout Sheet

struct DrinksCheckoutView: View {
    let package: DrinksPackage
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var quantity = 1
    @State private var purchased = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var clientSecret: String?
    @State private var showPayment = false

    private let bookingFee = 0.10

    var faceValue: Int { package.priceInPence * quantity }
    var fee: Int { Int(Double(faceValue) * bookingFee) }
    var total: Int { faceValue + fee }
    var totalFormatted: String { "£\(String(format: "%.2f", Double(total) / 100))" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if purchased {
                    confirmationView
                } else if showPayment {
                    StripePaymentView(
                        clientSecret: clientSecret ?? "",
                        total: totalFormatted,
                        tierName: package.name,
                        eventName: "Drinks Package",
                        quantity: quantity,
                        onSuccess: { withAnimation { purchased = true } },
                        onBack: { showPayment = false },
                        onError: { msg in errorMessage = msg; showPayment = false }
                    )
                } else {
                    summaryView
                }
            }
            .navigationTitle("Book Package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !showPayment && !purchased {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
    }

    var summaryView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Package header
                    VStack(alignment: .leading, spacing: 6) {
                        Text(package.name)
                            .font(.displayMedium).textCase(.uppercase).tracking(0)
                            .foregroundColor(.white)
                        Text(package.description)
                            .font(.bodyMedium)
                            .foregroundColor(.textSecondary)
                    }

                    Divider().background(Color.divider)

                    // Includes
                    VStack(alignment: .leading, spacing: 10) {
                        Text("INCLUDES")
                            .font(.label).tracking(2)
                            .foregroundColor(.brand)
                        ForEach(package.includes, id: \.self) { item in
                            HStack(spacing: 10) {
                                Circle().fill(Color.brand).frame(width: 4, height: 4)
                                Text(item).font(.bodyMedium).foregroundColor(.white)
                            }
                        }
                    }

                    Divider().background(Color.divider)

                    // Quantity
                    HStack {
                        Text("QUANTITY")
                            .font(.label).tracking(2)
                            .foregroundColor(.textSecondary)
                        Spacer()
                        HStack(spacing: 16) {
                            Button {
                                if quantity > 1 { quantity -= 1 }
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(quantity > 1 ? .white : .textSecondary)
                                    .frame(width: 32, height: 32)
                                    .background(Color.surface)
                                    .cornerRadius(8)
                            }
                            Text("\(quantity)")
                                .font(.titleMedium)
                                .foregroundColor(.white)
                                .frame(minWidth: 24)
                            Button {
                                quantity += 1
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.brand)
                                    .cornerRadius(8)
                            }
                        }
                    }

                    Divider().background(Color.divider)

                    // Fee breakdown
                    VStack(spacing: 10) {
                        feeRow(label: "\(package.name) × \(quantity)", value: faceValue)
                        feeRow(label: "Booking fee (10%)", value: fee)
                        Divider().background(Color.divider)
                        HStack {
                            Text("TOTAL")
                                .font(.label).tracking(2)
                                .foregroundColor(.white)
                            Spacer()
                            Text(formatPence(total))
                                .font(.titleMedium)
                                .foregroundColor(.brand)
                        }
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.bodyMedium)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
            }

            // Pay button
            VStack(spacing: 0) {
                Divider().background(Color.divider)
                Button(action: proceedToPayment) {
                    ZStack {
                        if isProcessing {
                            ProgressView().tint(.black)
                        } else {
                            Text("PAY \(formatPence(total))")
                                .font(.label)
                                .tracking(1.5)
                                .foregroundColor(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.brand)
                    .cornerRadius(4)
                }
                .disabled(isProcessing)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color.appBackground)
        }
    }

    var confirmationView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.brand)
            Text("YOU'RE BOOKED")
                .font(.displayMedium)
                .tracking(2)
                .foregroundColor(.white)
            Text("Your \(package.name) has been confirmed.\nShow this at the bar.")
                .font(.bodyMedium)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("DONE") { dismiss() }
                .font(.label)
                .tracking(1.5)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.brand)
                .cornerRadius(4)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
    }

    private func proceedToPayment() {
        guard let currentUser = appState.currentUser else {
            errorMessage = "Please log in to purchase a drinks package."
            return
        }
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let response = try await StripeService.shared.createPaymentIntent(
                    amountInPence: total,
                    eventId: "drinks-\(package.id)",
                    eventName: "Drinks Package",
                    tierName: package.name,
                    userEmail: currentUser.email,
                    quantity: quantity
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

    @ViewBuilder
    private func feeRow(label: String, value: Int) -> some View {
        HStack {
            Text(label).font(.bodyMedium).foregroundColor(.textSecondary)
            Spacer()
            Text(formatPence(value)).font(.bodyMedium).foregroundColor(.white)
        }
    }

    private func formatPence(_ pence: Int) -> String {
        "£\(String(format: "%.2f", Double(pence) / 100))"
    }
}
