import SwiftUI

enum MarviColor {
    static let ink = Color(hex: "#F5F5F7")
    /// Dark text for light surfaces (map cards, white buttons).
    static let inkOnLight = Color(hex: "#1C1C1E")
    static let graphite = Color(hex: "#C8C8CC")
    /// OLED near-black — luxury base (not charcoal-grey).
    static let surface = Color(hex: "#000000")
    static let surfaceCool = Color(hex: "#07070A")
    static let panel = Color(hex: "#121214")
    static let panelElevated = Color(hex: "#1A1A1E")
    static let emerald = Color(hex: "#34D399")
    /// Slightly deeper violet for calmer luxury vs neon pop.
    static let aubergine = Color(hex: "#7C3AED")
    static let gold = Color(hex: "#F5C542")
    /// Softened magenta — still brand-pink, less neon.
    static let rose = Color(hex: "#E11D6A")
    static let tomato = Color(hex: "#FF6B6B")
    static let blue = Color(hex: "#60A5FA")
    static let muted = Color(hex: "#8E8E93")
    static let border = Color.white.opacity(0.08)
}
