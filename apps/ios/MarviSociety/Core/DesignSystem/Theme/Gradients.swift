import SwiftUI

enum MarviGradient {
    static let brand = LinearGradient(
        colors: [MarviColor.rose, MarviColor.aubergine],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let brandVertical = LinearGradient(
        colors: [MarviColor.rose, MarviColor.aubergine, Color(hex: "#4C1D95")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warm = LinearGradient(
        colors: [MarviColor.rose.opacity(0.18), MarviColor.aubergine.opacity(0.14), MarviColor.surface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cool = LinearGradient(
        colors: [MarviColor.aubergine.opacity(0.16), MarviColor.rose.opacity(0.08), MarviColor.surface],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    static let heroOverlay = LinearGradient(
        colors: [.clear, MarviColor.surface.opacity(0.4), MarviColor.surface],
        startPoint: .top,
        endPoint: .bottom
    )
}
