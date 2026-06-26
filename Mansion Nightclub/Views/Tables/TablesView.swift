import SwiftUI

struct TablesView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // Hero
                        ZStack {
                            LinearGradient(
                                colors: [Color(hex: "#1a1200"), Color(hex: "#0d0900"), Color.appBackground],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 220)

                            VStack(spacing: 10) {
                                Text("🥂")
                                    .font(.system(size: 52))
                                Text("TABLE BOOKINGS")
                                    .font(.displayLarge)
                                    .tracking(6)
                                    .foregroundColor(.brand)
                                Rectangle()
                                    .fill(Color.brand)
                                    .frame(width: 40, height: 1.5)
                            }
                        }

                        VStack(spacing: 32) {

                            // Intro card
                            VStack(spacing: 16) {
                                Text("Book Your Table Now")
                                    .font(.titleLarge)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)

                                Text("Enjoy the full Mansion VIP experience. Reserve your table and arrive in style — bottle service, premium spirits, and the best seats in the venue.")
                                    .font(.bodyLarge)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 28)

                            // Divider
                            HStack {
                                Rectangle().fill(Color.divider).frame(height: 1)
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.brand)
                                Rectangle().fill(Color.divider).frame(height: 1)
                            }
                            .padding(.horizontal, 28)

                            // Info points
                            VStack(spacing: 14) {
                                InfoRow(icon: "checkmark.circle.fill", text: "Dedicated table host all evening")
                                InfoRow(icon: "checkmark.circle.fill", text: "Premium bottle packages available")
                                InfoRow(icon: "checkmark.circle.fill", text: "Best views of the main floor")
                                InfoRow(icon: "checkmark.circle.fill", text: "Priority entry included")
                            }
                            .padding(.horizontal, 28)

                            // Contact card
                            VStack(spacing: 16) {
                                HStack(spacing: 8) {
                                    Rectangle().fill(Color.brand).frame(width: 3, height: 14)
                                    Text("ALL ENQUIRIES")
                                        .font(.label).tracking(3).foregroundColor(.brand)
                                }

                                Text("Contact us directly on WhatsApp and our team will get back to you as soon as possible with availability and package options.")
                                    .font(.bodyMedium)
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(3)

                                Button(action: openWhatsApp) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "message.fill")
                                            .font(.system(size: 16))
                                        Text("Message Us on WhatsApp")
                                            .font(.titleMedium)
                                    }
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.brand)
                                    .cornerRadius(14)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 48)
                        }
                        .padding(.top, 32)
                    }
                }
            }
            .navigationTitle("Tables")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    func openWhatsApp() {
        if let url = URL(string: "https://wa.me/447442499401?text=Hi%20Mansion%2C%20I%27d%20like%20to%20book%20a%20table.") {
            UIApplication.shared.open(url)
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.brand)
                .font(.system(size: 15))
            Text(text)
                .font(.bodyLarge)
                .foregroundColor(.white)
            Spacer()
        }
    }
}

#Preview {
    TablesView()
}
