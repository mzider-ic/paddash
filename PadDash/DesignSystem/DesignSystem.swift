import SwiftUI

// MARK: - Design Tokens

enum DS {

    // MARK: Colors
    enum Color {
        static let background       = SwiftUI.Color(hex: "#0A0A0F")
        static let surface          = SwiftUI.Color(hex: "#13131A")
        static let surfaceRaised    = SwiftUI.Color(hex: "#1C1C26")
        static let border           = SwiftUI.Color(white: 1, opacity: 0.07)
        static let borderStrong     = SwiftUI.Color(white: 1, opacity: 0.14)

        static let textPrimary      = SwiftUI.Color(white: 1, opacity: 0.95)
        static let textSecondary    = SwiftUI.Color(white: 1, opacity: 0.45)
        static let textTertiary     = SwiftUI.Color(white: 1, opacity: 0.25)

        // Accent palette — one per timer slot + global
        static let accentBlue       = SwiftUI.Color(hex: "#4A9EFF")
        static let accentMint       = SwiftUI.Color(hex: "#3DFFD0")
        static let accentAmber      = SwiftUI.Color(hex: "#FFB347")

        static let danger           = SwiftUI.Color(hex: "#FF4D6A")
        static let success          = SwiftUI.Color(hex: "#3DFFD0")
    }

    // MARK: Radius
    enum Radius {
        static let sm: CGFloat  = 10
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
    }

    // MARK: Spacing
    enum Space {
        static let xs: CGFloat  = 6
        static let sm: CGFloat  = 12
        static let md: CGFloat  = 20
        static let lg: CGFloat  = 28
        static let xl: CGFloat  = 40
    }

    // MARK: Animation
    enum Animation {
        static let snappy   = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.72)
        static let smooth   = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let tick     = SwiftUI.Animation.linear(duration: 1)
    }
}

// MARK: - Color hex init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Reusable surface card
struct DashCard<Content: View>: View {
    var content: () -> Content

    var body: some View {
        content()
            .padding(DS.Space.md)
            .background(DS.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(DS.Color.border, lineWidth: 1)
            )
    }
}
