import SwiftUI

struct CustomerEventsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showBasket = false

    var publishedEvents: [AppEvent] {
        appState.events
            .filter { $0.status == .published || $0.status == .completed }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(publishedEvents) { event in
                            NavigationLink(destination: EventDetailView(event: event)) {
                                PublicEventCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if appState.basketItemCount > 0 {
                        Button {
                            showBasket = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "basket.fill")
                                    .foregroundColor(.brand)
                                Text("\(appState.basketItemCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(width: 16, height: 16)
                                    .background(Color.brand)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showBasket) {
            BasketView()
        }
    }
}

struct PublicEventCard: View {
    let event: AppEvent

    var lowestTier: TicketTier? {
        event.tiers
            .filter { $0.isVisible && !$0.isSoldOut && !$0.isPendingOnSale }
            .min { $0.priceInPence < $1.priceInPence }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Artwork banner
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: event.artworkGradient.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 140)

                LinearGradient(colors: [.clear, Color.appBackground.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.name)
                            .font(.titleLarge).textCase(.uppercase).tracking(0)
                            .foregroundColor(.white)
                        Text(event.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.bodyMedium).foregroundColor(.textSecondary)
                    }
                    Spacer()
                    if event.isSoldOut {
                        Text("SOLD OUT")
                            .font(.caption).tracking(2)
                            .foregroundColor(.red)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(6)
                    }
                }
                .padding(14)
            }
            .clipped()

            // Info row
            HStack(spacing: 16) {
                Label(event.venue, systemImage: "mappin")
                    .font(.caption).foregroundColor(.textSecondary)
                    .lineLimit(1)
                Spacer()
                if let tier = lowestTier {
                    Text("From \(tier.priceFormatted)")
                        .font(.titleMedium).foregroundColor(.brand)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Color.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brand.opacity(0.12), lineWidth: 1))
    }
}
