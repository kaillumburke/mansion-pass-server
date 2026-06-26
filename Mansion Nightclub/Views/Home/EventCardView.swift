import SwiftUI

struct EventCardView: View {
    let event: AppEvent

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: event.date).uppercased()
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: event.doorsOpen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Artwork area
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
                    .frame(height: 180)
                    .clipped()
                } else {
                    LinearGradient(
                        colors: event.artworkGradient.map { Color(hex: $0) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 180)
                }

                // Availability pill
                HStack(spacing: 6) {
                    if event.isSoldOut {
                        Text("SOLD OUT")
                            .font(.label)
                            .tracking(1)
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .cornerRadius(20)
                    } else {
                        let lowestPrice = event.tiers.filter { !$0.isSoldOut }.min(by: { $0.priceInPence < $1.priceInPence })
                        if let tier = lowestPrice {
                            Text("FROM \(tier.priceFormatted)")
                                .font(.label)
                                .tracking(1)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.brand)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(12)
            }
            .cornerRadius(16, corners: [.topLeft, .topRight])

            // Info
            VStack(alignment: .leading, spacing: 10) {
                Text(event.name)
                    .font(.titleLarge).textCase(.uppercase).tracking(0)
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    Label(dateString, systemImage: "calendar")
                    Label(timeString, systemImage: "clock")
                }
                .font(.bodyMedium)
                .foregroundColor(.textSecondary)

                // Capacity bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(event.ticketsSold) sold")
                        Spacer()
                        Text("\(event.capacity - event.ticketsSold) remaining")
                    }
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.divider)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(event.availabilityPercent > 0.8 ? Color.orange : Color.brand)
                                .frame(width: geo.size.width * event.availabilityPercent, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(16)
            .background(Color.surface)
            .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    EventCardView(event: MockData.events[0])
        .padding()
        .background(Color.appBackground)
}
