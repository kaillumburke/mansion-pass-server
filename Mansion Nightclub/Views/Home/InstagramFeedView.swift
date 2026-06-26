import SwiftUI

struct InstagramFeedView: View {
    var body: some View {
        Button(action: openInstagram) {
            HStack(spacing: 16) {
                Image(systemName: "camera")
                    .font(.title2)
                    .foregroundColor(.brand)

                VStack(alignment: .leading, spacing: 2) {
                    Text("@mansionliverpool")
                        .font(.titleMedium)
                        .foregroundColor(.white)
                    Text("Follow us on Instagram")
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.bodyMedium)
                    .foregroundColor(.brand)
            }
            .padding(20)
            .background(Color.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.brand.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 36)
    }

    private func openInstagram() {
        let appUrl = URL(string: "instagram://user?username=mansionliverpool")!
        let webUrl = URL(string: "https://www.instagram.com/mansionliverpool")!
        if UIApplication.shared.canOpenURL(appUrl) {
            UIApplication.shared.open(appUrl)
        } else {
            UIApplication.shared.open(webUrl)
        }
    }
}
