import SwiftUI

enum AppTheme {
    static let background = dynamicColor(
        light: UIColor(red: 0.98, green: 0.95, blue: 0.9, alpha: 1),
        dark: UIColor(red: 0.1, green: 0.1, blue: 0.11, alpha: 1)
    )
    static let card = dynamicColor(
        light: UIColor(red: 0.99, green: 0.96, blue: 0.92, alpha: 1),
        dark: UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
    )
    static let cardSecondary = dynamicColor(
        light: UIColor(red: 0.985, green: 0.955, blue: 0.92, alpha: 1),
        dark: UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)
    )
    static let textPrimary = dynamicColor(
        light: UIColor(red: 0.28, green: 0.22, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.92, green: 0.92, blue: 0.93, alpha: 1)
    )
    static let textSecondary = dynamicColor(
        light: UIColor.black.withAlphaComponent(0.5),
        dark: UIColor.white.withAlphaComponent(0.6)
    )
    static let accentOrange = dynamicColor(
        light: UIColor(red: 0.98, green: 0.62, blue: 0.08, alpha: 1),
        dark: UIColor(red: 0.98, green: 0.62, blue: 0.08, alpha: 1)
    )
    static let accentGreen = dynamicColor(
        light: UIColor(red: 0.26, green: 0.7, blue: 0.38, alpha: 1),
        dark: UIColor(red: 0.36, green: 0.78, blue: 0.46, alpha: 1)
    )
    static let accentGold = dynamicColor(
        light: UIColor(red: 1.0, green: 0.78, blue: 0.1, alpha: 1),
        dark: UIColor(red: 1.0, green: 0.78, blue: 0.1, alpha: 1)
    )
    static let shadow = dynamicColor(
        light: UIColor.black.withAlphaComponent(0.08),
        dark: UIColor.black.withAlphaComponent(0.4)
    )
    static let statsBackgroundTop = dynamicColor(
        light: UIColor(red: 0.97, green: 0.93, blue: 0.88, alpha: 1),
        dark: UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
    )
    static let statsBackgroundBottom = dynamicColor(
        light: UIColor(red: 0.96, green: 0.92, blue: 0.88, alpha: 1),
        dark: UIColor(red: 0.1, green: 0.1, blue: 0.11, alpha: 1)
    )

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
