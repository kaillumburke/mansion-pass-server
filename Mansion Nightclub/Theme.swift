import SwiftUI

extension Color {
    static let brand = Color(hex: "#d1ae6c")
    static let brandDark = Color(hex: "#a8894e")
    static let brandSubtle = Color(hex: "#d1ae6c").opacity(0.15)
    static let appBackground = Color(hex: "#0a0a0a")
    static let surface = Color(hex: "#141414")
    static let surfaceElevated = Color(hex: "#1e1e1e")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#888888")
    static let divider = Color(hex: "#222222")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension Font {
    // Druk — headings
    static let displayLarge  = Font.custom("DrukTrial-Bold", size: 34)
    static let displayMedium = Font.custom("DrukTrial-Bold", size: 28)
    static let titleLarge    = Font.custom("DrukTrial-Bold", size: 22)

    // Mona Sans Bold — subheadings & UI labels
    static let titleMedium = Font.custom("Mona-Sans-Bold", size: 17)
    static let bodyLarge   = Font.custom("Mona-Sans-Regular", size: 17)
    static let bodyMedium  = Font.custom("Mona-Sans-Regular", size: 15)
    static let label       = Font.custom("Mona-Sans-Bold", size: 13)
    static let caption     = Font.custom("Mona-Sans-Regular", size: 12)
}
