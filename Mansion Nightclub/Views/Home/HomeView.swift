import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedEvent: AppEvent? = nil

    var upcomingEvents: [AppEvent] {
        appState.events.filter { $0.status == .published && $0.name != "RAVE AT MANSION" }
    }

    var featuredEvent: AppEvent? { upcomingEvents.first }
    var remainingEvents: [AppEvent] { upcomingEvents.dropFirst().map { $0 } }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    upcomingSection
                    DrinksPackagesView(packages: MockData.drinksPackages)
                    InstagramFeedView()
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
    }

    // MARK: - Hero

    var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed photo
            GeometryReader { geo in
                Image("HeroBG")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: 580)
                    .clipped()
                    .opacity(0.45)
            }
            .frame(height: 580)

            // Big centred logo over the crowd image
            Image("MansionLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Dark gradient overlay — heavier at top and bottom
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.65), location: 0),
                    .init(color: Color.black.opacity(0.1), location: 0.35),
                    .init(color: Color.black.opacity(0.2), location: 0.55),
                    .init(color: Color.black.opacity(0.98), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 580)

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Text((appState.currentUser?.firstName.prefix(1) ?? "M").uppercased())
                            .font(.label)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 56)

                Spacer()

                CountdownView()
                    .padding(.bottom, 40)
            }
            .frame(height: 580)
        }
    }

    // MARK: - Upcoming

    var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.brand)
                            .frame(width: 3, height: 14)
                        Text("UPCOMING EVENTS")
                            .font(.label)
                            .tracking(3)
                            .foregroundColor(.brand)
                    }
}
                Spacer()
                Button("See all") {}
                    .font(.titleMedium)
                    .foregroundColor(.brand)
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 16)

            VStack(spacing: 12) {
                ForEach(remainingEvents) { event in
                    CompactEventRow(event: event)
                        .padding(.horizontal, 20)
                        .onTapGesture { selectedEvent = event }
                }
                // Also show featured in the list
                if let featured = featuredEvent {
                    CompactEventRow(event: featured)
                        .padding(.horizontal, 20)
                        .onTapGesture { selectedEvent = featured }
                }
            }
            .padding(.bottom, 36)
        }
    }
}

// MARK: - Compact Row

struct CompactEventRow: View {
    let event: AppEvent

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: event.date).uppercased()
    }

    private var lowestPrice: String {
        let available = event.tiers.filter { !$0.isSoldOut }
        guard let cheapest = available.min(by: { $0.priceInPence < $1.priceInPence }) else { return "Sold Out" }
        return "From \(cheapest.priceFormatted)"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if let urlStr = event.headerImageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            LinearGradient(
                                colors: event.artworkGradient.map { Color(hex: $0) },
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipped()
                    .cornerRadius(12)
                } else {
                    LinearGradient(
                        colors: event.artworkGradient.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 64, height: 64)
                    .cornerRadius(12)

                    Image("MansionLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .opacity(0.35)
                }

                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brand.opacity(0.25), lineWidth: 1)
                    .frame(width: 64, height: 64)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(event.name)
                    .font(.titleLarge).textCase(.uppercase).tracking(0)
                    .foregroundColor(.white)
                Text(dateString)
                    .font(.caption)
                    .tracking(1)
                    .foregroundColor(.textSecondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.divider)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(colors: [Color(hex: "#e8cb8e"), Color.brand], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * event.availabilityPercent, height: 3)
                    }
                }
                .frame(height: 3)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(lowestPrice)
                    .font(.titleMedium)
                    .foregroundColor(.brand)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(14)
        .background(Color.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brand.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView().environmentObject(AppState())
}
