import SwiftUI
import Combine

struct EventDetailView: View {
    let event: AppEvent
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var quantities: [String: Int] = [:]
    @State private var showBasket = false

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE d MMMM yyyy"
        return f.string(from: event.date)
    }

    private var doorsString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "Doors \(f.string(from: event.doorsOpen))"
    }

    var hasSelections: Bool {
        quantities.values.contains { $0 > 0 }
    }

    var selectionTotal: Int {
        quantities.compactMap { id, qty -> Int? in
            guard qty > 0, let tier = event.tiers.first(where: { $0.id == id }) else { return nil }
            return tier.totalWithFee * qty
        }.reduce(0, +)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Artwork header
                    ZStack(alignment: .bottomLeading) {
                        if let urlStr = event.headerImageURL, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                default:
                                    LinearGradient(colors: event.artworkGradient.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                                }
                            }
                            .frame(height: 280)
                            .clipped()
                        } else {
                            LinearGradient(
                                colors: event.artworkGradient.map { Color(hex: $0) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: 280)
                        }

                        LinearGradient(
                            colors: [.clear, Color.appBackground],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .frame(height: 280)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.name)
                                .font(.displayLarge).textCase(.uppercase).tracking(0)
                                .foregroundColor(.white)
                            Text(dateString)
                                .font(.bodyMedium)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(20)
                    }

                    VStack(alignment: .leading, spacing: 24) {
                        // Meta info
                        HStack(spacing: 20) {
                            InfoChip(icon: "calendar", text: dateString)
                            InfoChip(icon: "clock", text: doorsString)
                        }
                        InfoChip(icon: "mappin", text: event.venue)
                        InfoChip(icon: "person.fill", text: "\(event.ageRestriction)+ only")

                        Divider().background(Color.divider)

                        Text(event.description)
                            .font(.bodyLarge)
                            .foregroundColor(.textSecondary)
                            .lineSpacing(6)

                        Divider().background(Color.divider)

                        // Tickets
                        Text("TICKETS")
                            .font(.titleLarge).textCase(.uppercase).tracking(0)
                            .foregroundColor(.white)

                        VStack(spacing: 12) {
                            ForEach(event.tiers.filter { $0.isVisible }) { tier in
                                TierPickerRow(
                                    tier: tier,
                                    quantity: Binding(
                                        get: { quantities[tier.id] ?? 0 },
                                        set: { quantities[tier.id] = $0 }
                                    )
                                )
                            }
                        }
                    }
                    .padding(20)

                    Spacer().frame(height: 160)
                }
            }

            // Back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.titleMedium)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(.top, 52)
            .padding(.leading, 16)

            // Basket button if items in basket
            if appState.basketItemCount > 0 {
                HStack {
                    Spacer()
                    Button { showBasket = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "basket.fill")
                                .font(.title3)
                                .foregroundColor(.brand)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                            Text("\(appState.basketItemCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 16, height: 16)
                                .background(Color.brand)
                                .clipShape(Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 52)
            }

            // CTA
            VStack {
                Spacer()
                if hasSelections {
                    Button(action: addToBasket) {
                        HStack {
                            Text("Add to Basket")
                                .font(.titleMedium).foregroundColor(.white)
                            Spacer()
                            Text("£\(String(format: "%.2f", Double(selectionTotal) / 100))")
                                .font(.titleMedium).foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 54)
                        .background(Color.brand)
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 90)
                } else {
                    Text("Select tickets above")
                        .font(.bodyMedium).foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(Color.surface)
                        .cornerRadius(14)
                        .padding(.horizontal, 20).padding(.bottom, 30)
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showBasket) {
            BasketView()
        }
    }

    func addToBasket() {
        for (tierId, qty) in quantities where qty > 0 {
            if let tier = event.tiers.first(where: { $0.id == tierId }) {
                appState.addToBasket(tier: tier, quantity: qty)
            }
        }
        quantities = [:]
        showBasket = true
    }
}

// MARK: - Tier Picker Row

struct TierPickerRow: View {
    let tier: TicketTier
    @Binding var quantity: Int
    @State private var countdown = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.name)
                        .font(.titleMedium)
                        .foregroundColor(isDisabled ? .textSecondary : .white)
                    if !tier.description.isEmpty {
                        Text(tier.description)
                            .font(.caption).foregroundColor(.textSecondary)
                    }
                    HStack(spacing: 8) {
                        Text(tier.priceFormatted)
                            .font(.titleMedium)
                            .foregroundColor(isDisabled ? .textSecondary : .brand)
                        if tier.priceInPence > 0 {
                            Text("+ £\(String(format: "%.2f", Double(tier.bookingFee) / 100)) fee")
                                .font(.caption).foregroundColor(.textSecondary)
                        }
                    }
                }
                Spacer()

                if tier.isSoldOut {
                    Text("SOLD OUT")
                        .font(.caption).tracking(1).foregroundColor(.red)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                } else if tier.isPendingOnSale {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ON SALE IN")
                            .font(.caption).tracking(1).foregroundColor(.orange)
                        Text(countdown)
                            .font(.caption).foregroundColor(.orange)
                            .onReceive(timer) { _ in updateCountdown() }
                            .onAppear { updateCountdown() }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                } else {
                    // Quantity stepper
                    HStack(spacing: 0) {
                        Button {
                            if quantity > 0 { quantity -= 1 }
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 36, height: 36)
                                .foregroundColor(quantity == 0 ? .textSecondary : .white)
                        }
                        Text("\(quantity)")
                            .font(.titleMedium).foregroundColor(.white)
                            .frame(width: 32)
                        Button {
                            if quantity < tier.maxPerOrder { quantity += 1 }
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 36, height: 36)
                                .foregroundColor(quantity >= tier.maxPerOrder ? .textSecondary : .brand)
                        }
                    }
                    .background(Color.surfaceElevated)
                    .cornerRadius(10)
                }
            }
            .padding(14)
        }
        .background(quantity > 0 ? Color.brand.opacity(0.1) : Color.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(quantity > 0 ? Color.brand : Color.divider, lineWidth: quantity > 0 ? 1.5 : 1)
        )
        .opacity(isDisabled ? 0.5 : 1)
    }

    var isDisabled: Bool { tier.isSoldOut || tier.isPendingOnSale }

    func updateCountdown() {
        guard let start = tier.saleStartsAt else { return }
        let diff = start.timeIntervalSinceNow
        if diff <= 0 { countdown = "Now"; return }
        let h = Int(diff) / 3600
        let m = (Int(diff) % 3600) / 60
        let s = Int(diff) % 60
        if h > 24 {
            countdown = "\(Int(diff / 86400))d \(h % 24)h"
        } else {
            countdown = String(format: "%02d:%02d:%02d", h, m, s)
        }
    }
}

struct InfoChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.brand)
                .font(.label)
            Text(text)
                .font(.bodyMedium)
                .foregroundColor(.textSecondary)
        }
    }
}

#Preview {
    EventDetailView(event: MockData.events[0])
        .environmentObject(AppState())
}
