import Foundation
import PassKit

final class WalletService: NSObject {
    static let shared = WalletService()

    private let signingBaseURL = "https://web-production-d34cc.up.railway.app"
    private var addCompletion: ((Bool) -> Void)?

    private override init() {}

    // MARK: - Availability

    var isWalletAvailable: Bool {
        PKAddPassesViewController.canAddPasses()
    }

    // MARK: - Generate & add pass

    func addToWallet(ticket: FirestoreTicket, from viewController: UIViewController) async throws -> Bool {
        let passData = try await fetchPass(for: ticket)
        let pass = try PKPass(data: passData)

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let vc = PKAddPassesViewController(pass: pass) else {
                    continuation.resume(returning: false)
                    return
                }
                vc.delegate = self
                self.addCompletion = { added in
                    continuation.resume(returning: added)
                }
                // Present from the topmost presented VC to avoid sheet conflicts
                var presenter = viewController
                while let presented = presenter.presentedViewController {
                    presenter = presented
                }
                presenter.present(vc, animated: true)
            }
        }
    }

    // MARK: - Check if already in wallet

    func isInWallet(ticket: FirestoreTicket) -> Bool {
        PKPassLibrary().passes().contains { $0.serialNumber == ticket.id }
    }

    // MARK: - Private

    private func fetchPass(for ticket: FirestoreTicket) async throws -> Data {
        guard let url = URL(string: "\(signingBaseURL)/pass") else {
            throw WalletError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ticket)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WalletError.serverError
        }

        return data
    }
}

// MARK: - PKAddPassesViewControllerDelegate

extension WalletService: PKAddPassesViewControllerDelegate {
    func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
        controller.dismiss(animated: true)
        // Check if the pass actually landed in the library
        let added = PKPassLibrary().passes().contains { _ in true }
        addCompletion?(added)
        addCompletion = nil
    }
}

enum WalletError: LocalizedError {
    case invalidURL
    case serverError
    case walletUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid signing service URL"
        case .serverError: return "Pass signing failed"
        case .walletUnavailable: return "Apple Wallet is not available on this device"
        }
    }
}
