import SwiftUI

// Search for Mac's colours (Design.swift there), light and dark: the same
// greys, so an empty tab looks the same on both.

enum Palette {
    /// The page and the field: white, or 11% white in the dark.
    static let ground = pair(1.0, 0.11)
    /// Text: neutral-900, or neutral-100 in the dark.
    static let ink = pair(0.09, 0.93)
    /// The field's edge: neutral-200, or neutral-800 in the dark.
    static let hairline = pair(0.91, 0.20)

    private static func pair(_ light: CGFloat, _ dark: CGFloat) -> Color {
        Color(UIColor { traits in
            UIColor(white: traits.userInterfaceStyle == .dark ? dark : light, alpha: 1)
        })
    }
}
