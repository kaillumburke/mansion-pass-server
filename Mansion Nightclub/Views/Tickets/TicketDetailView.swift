import SwiftUI
import PassKit

struct TicketDetailView: View {
    let ticket: Ticket
    @Environment(\.dismiss) var dismiss
    @State private var brightness: Double = 1.0
    @State private var isAddingToWallet = false
    @State private var walletError: String?
    @State private var showWalletError = false
    @State private var inWallet = false

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE d MMMM yyyy"
        return f.string(from: ticket.event.date)
    }

    private var doorsString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: ticket.event.doorsOpen)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.divider)
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Ticket card
                        VStack(spacing: 0) {
                            // Top half — event info
                            LinearGradient(
                                colors: ticket.event.artworkGradient.map { Color(hex: $0) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay(
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(ticket.event.name)
                                        .font(.displayMedium).textCase(.uppercase).tracking(0)
                                        .foregroundColor(.white)
                                    Text(ticket.tier.name.uppercased())
                                        .font(.label)
                                        .tracking(3)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(20),
                                alignment: .bottomLeading
                            )
                            .frame(height: 160)

                            // Perforated divider
                            HStack(spacing: 0) {
                                Color.appBackground
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                    .offset(x: -12)
                                Rectangle()
                                    .fill(Color.divider)
                                    .frame(height: 1)
                                    .background(
                                        GeometryReader { geo in
                                            Path { path in
                                                var x: CGFloat = 0
                                                while x < geo.size.width {
                                                    path.move(to: CGPoint(x: x, y: 0))
                                                    path.addLine(to: CGPoint(x: x + 6, y: 0))
                                                    x += 12
                                                }
                                            }
                                            .stroke(Color.divider, lineWidth: 1)
                                        }
                                    )
                                Color.appBackground
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                    .offset(x: 12)
                            }
                            .frame(height: 24)
                            .background(Color.surface)

                            // Bottom half — details + QR
                            VStack(spacing: 20) {
                                HStack(spacing: 0) {
                                    TicketInfoCell(label: "DATE", value: dateString)
                                    Divider().background(Color.divider)
                                    TicketInfoCell(label: "DOORS", value: doorsString)
                                }
                                HStack(spacing: 0) {
                                    TicketInfoCell(label: "VENUE", value: ticket.event.venue)
                                    Divider().background(Color.divider)
                                    TicketInfoCell(label: "ORDER", value: "#\(ticket.orderId.prefix(8).uppercased())")
                                }

                                Divider().background(Color.divider).padding(.horizontal, 16)

                                // QR code
                                VStack(spacing: 12) {
                                    QRCodeView(content: ticket.qrCode)
                                        .frame(width: 180, height: 180)
                                        .padding(16)
                                        .background(Color.white)
                                        .cornerRadius(12)

                                    Text(ticket.qrCode)
                                        .font(.caption)
                                        .foregroundColor(.textSecondary)

                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(ticket.status == .valid ? Color.green : Color.orange)
                                            .frame(width: 8, height: 8)
                                        Text(ticket.status == .valid ? "Valid — show at entry" : "Used")
                                            .font(.bodyMedium)
                                            .foregroundColor(ticket.status == .valid ? .green : .orange)
                                    }
                                }
                                .padding(.bottom, 20)
                            }
                            .background(Color.surface)
                        }
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                        .padding(.horizontal, 20)

                        // Add to wallet
                        if WalletService.shared.isWalletAvailable {
                            Button(action: addToWallet) {
                                HStack(spacing: 10) {
                                    if isAddingToWallet {
                                        ProgressView().tint(.white).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: inWallet ? "checkmark.circle.fill" : "wallet.pass.fill")
                                    }
                                    Text(inWallet ? "In Apple Wallet" : "Add to Apple Wallet")
                                }
                                .font(.titleMedium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(inWallet ? Color.green.opacity(0.3) : Color.surface)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(inWallet ? Color.green.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1)
                                )
                            }
                            .disabled(isAddingToWallet || inWallet)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                            .alert("Wallet Error", isPresented: $showWalletError) {
                                Button("OK", role: .cancel) {}
                            } message: {
                                Text(walletError ?? "Unknown error")
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            // Check if the local Ticket has a corresponding FirestoreTicket already in wallet
            inWallet = WalletService.shared.isInWallet(ticket: ticket.asFirestoreTicket)
        }
    }

    private func addToWallet() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let vc = windowScene.windows.first?.rootViewController else { return }

        isAddingToWallet = true
        Task {
            do {
                let added = try await WalletService.shared.addToWallet(ticket: ticket.asFirestoreTicket, from: vc)
                await MainActor.run {
                    inWallet = added
                    isAddingToWallet = false
                }
            } catch {
                await MainActor.run {
                    walletError = error.localizedDescription
                    showWalletError = true
                    isAddingToWallet = false
                }
            }
        }
    }
}

struct TicketInfoCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .tracking(2)
                .foregroundColor(.textSecondary)
            Text(value)
                .font(.label)
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Minimal QR code view using Core Image
struct QRCodeView: View {
    let content: String

    var qrImage: UIImage? {
        guard let data = content.data(using: .ascii),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    var body: some View {
        if let img = qrImage {
            Image(uiImage: img)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Color.gray
        }
    }
}

#Preview {
    TicketDetailView(ticket: MockData.myTickets[0])
}
