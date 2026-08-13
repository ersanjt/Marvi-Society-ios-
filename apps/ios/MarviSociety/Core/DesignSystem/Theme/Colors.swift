import SwiftUI

enum MarviColor {
    static let ink = Color(hex: "#F5F5F7")
    /// Dark text for light surfaces (map cards, white buttons).
    static let inkOnLight = Color(hex: "#1C1C1E")
    static let graphite = Color(hex: "#C8C8CC")
    /// OLED near-black — luxury base (matches landing).
    static let surface = Color(hex: "#000000")
    static let surfaceCool = Color(hex: "#07070A")
    static let panel = Color(hex: "#121214")
    static let panelElevated = Color(hex: "#1A1A1E")
    /// Success / confirmed only.
    static let emerald = Color(hex: "#34D399")
    /// Brand violet — matches landing gradient end.
    static let aubergine = Color(hex: "#8B5CF6")
    /// Highlight / pending — brand-aligned (not literal gold). Prefer `.rose` in new UI.
    static let gold = Color(hex: "#FF2D78")
    /// Brand pink — matches landing CTA / gradient start.
    static let rose = Color(hex: "#FF2D78")
    /// Error / destructive only.
    static let tomato = Color(hex: "#FF6B6B")
    /// Info — brand-aligned (not sky blue). Prefer `.aubergine` in new UI.
    static let blue = Color(hex: "#8B5CF6")
    static let muted = Color(hex: "#8E8E93")
    static let border = Color.white.opacity(0.08)
}
