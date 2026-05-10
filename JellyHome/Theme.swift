import SwiftUI

enum Theme {
    static let backgroundTop = Color(red: 0.06, green: 0.07, blue: 0.09)
    static let backgroundBottom = Color(red: 0.02, green: 0.03, blue: 0.04)
    static let accent = Color(red: 0.33, green: 0.92, blue: 0.62)
    static let accentSecondary = Color(red: 0.38, green: 0.78, blue: 0.95)
    static let cardBorder = Color.white.opacity(0.12)
    static let muted = Color.white.opacity(0.68)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func displayFont(_ size: CGFloat) -> Font {
        .custom("Avenir Next", size: size).weight(.semibold)
    }

    static func titleFont(_ size: CGFloat) -> Font {
        .custom("Avenir Next", size: size).weight(.bold)
    }

    static func bodyFont(_ size: CGFloat) -> Font {
        .custom("Avenir Next", size: size).weight(.regular)
    }
}

struct LiquidBackground: View {
    var body: some View {
        ZStack {
            Theme.backgroundGradient
                .ignoresSafeArea()

            Circle()
                .fill(Theme.accent.opacity(0.15))
                .frame(width: 260, height: 260)
                .blur(radius: 35)
                .offset(x: -140, y: -220)

            RoundedRectangle(cornerRadius: 180, style: .continuous)
                .fill(Theme.accentSecondary.opacity(0.12))
                .frame(width: 320, height: 220)
                .blur(radius: 40)
                .offset(x: 140, y: -60)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 55)
                .offset(x: 120, y: 240)
        }
    }
}
