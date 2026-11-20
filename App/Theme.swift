import SwiftUI

enum Theme {
    static let gold = Color(red: 1.0, green: 0.71, blue: 0.18)
    static let coral = Color(red: 0.96, green: 0.41, blue: 0.22)
    static let ink = Color(red: 0.055, green: 0.095, blue: 0.13)
    static let cream = Color(red: 1.0, green: 0.96, blue: 0.85)
    static let sea = Color(red: 0.27, green: 0.76, blue: 0.75)
    static let background = LinearGradient(
        colors: [coral, gold.opacity(0.65), ink],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let panel = Color(red: 0.045, green: 0.08, blue: 0.11).opacity(0.86)

    static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

struct GlassPanel: ViewModifier {
    var radius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

extension View {
    func cockpitPanel(radius: CGFloat = 18) -> some View {
        modifier(GlassPanel(radius: radius))
    }
}
