import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let bestAttemptContent,
              let attachmentsDict = request.content.userInfo["attachments"] as? [String: String] ?? extractOneSignalAttachments(request.content.userInfo),
              let urlString = attachmentsDict.values.first,
              let url = URL(string: urlString) else {
            contentHandler(bestAttemptContent ?? request.content)
            return
        }

        downloadAndAttach(url: url, to: bestAttemptContent, contentHandler: contentHandler)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func extractOneSignalAttachments(_ userInfo: [AnyHashable: Any]) -> [String: String]? {
        // OneSignal puts attachments under "os_data" → "att"
        if let osData = userInfo["os_data"] as? [String: Any],
           let att = osData["att"] as? [String: String] {
            return att
        }
        return nil
    }

    private func downloadAndAttach(url: URL, to content: UNMutableNotificationContent, contentHandler: @escaping (UNNotificationContent) -> Void) {
        URLSession.shared.downloadTask(with: url) { tempURL, _, _ in
            guard let tempURL else {
                contentHandler(content)
                return
            }
            let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
            let destURL = tempURL.deletingLastPathComponent().appendingPathComponent("attachment.\(ext)")
            try? FileManager.default.moveItem(at: tempURL, to: destURL)

            if let attachment = try? UNNotificationAttachment(identifier: "image", url: destURL) {
                content.attachments = [attachment]
            }
            contentHandler(content)
        }.resume()
    }
}
