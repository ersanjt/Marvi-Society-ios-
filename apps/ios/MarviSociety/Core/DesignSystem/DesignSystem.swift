import SwiftUI

enum MarviColor {
    static let ink = Color(hex: "#15171A")
    static let graphite = Color(hex: "#2C3036")
    static let surface = Color(hex: "#F4F1EA")
    static let surfaceCool = Color(hex: "#EEF3F4")
    static let panel = Color.white
    static let emerald = Color(hex: "#0E7C66")
    static let aubergine = Color(hex: "#5C315E")
    static let gold = Color(hex: "#C69A32")
    static let rose = Color(hex: "#B85C7A")
    static let tomato = Color(hex: "#D25D3D")
    static let blue = Color(hex: "#316D9E")
    static let muted = Color(hex: "#747A82")
}

enum MarviGradient {
    static let brand = LinearGradient(
        colors: [MarviColor.ink, MarviColor.emerald, MarviColor.aubergine],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warm = LinearGradient(
        colors: [MarviColor.gold.opacity(0.22), MarviColor.tomato.opacity(0.12), .white.opacity(0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cool = LinearGradient(
        colors: [MarviColor.blue.opacity(0.18), MarviColor.emerald.opacity(0.12), .white.opacity(0.24)],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let red: UInt64
        let green: UInt64
        let blue: UInt64

        switch hex.count {
        case 6:
            (red, green, blue) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (red, green, blue) = (21, 23, 26)
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: 1
        )
    }
}

struct MarviCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(MarviColor.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 18, x: 0, y: 8)
    }
}

struct MarviScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            MarviColor.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                Rectangle()
                    .fill(MarviGradient.cool)
                    .frame(height: 170)
                    .blur(radius: 20)
                    .opacity(0.9)
                    .ignoresSafeArea()

                Spacer()
            }

            content
        }
    }
}

struct BrandMark: View {
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MarviGradient.brand)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)

            Text("M")
                .font(.system(size: size * 0.48, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Marvi Society")
    }
}

struct BrandLockup: View {
    var subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            BrandMark(size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("Marvi Society")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MarviColor.ink)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MarviColor.muted)
                    .lineLimit(1)
            }

            Spacer()
        }
    }
}

struct StatusPill: View {
    let text: String
    let tint: Color
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            }

            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct InfoBadge: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(MarviColor.graphite)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(MarviColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MetricTile: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(MarviColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MarviColor.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background {
            if isDisabled {
                MarviColor.muted
            } else {
                MarviGradient.brand
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.72 : 1)
    }
}

struct SecondaryActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MarviColor.ink)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(MarviColor.ink)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(MarviColor.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProgressBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.07))

                Capsule()
                    .fill(tint)
                    .frame(width: max(8, proxy.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 7)
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(MarviColor.emerald)

            Text(title)
                .font(.headline)
                .foregroundStyle(MarviColor.ink)

            Text(subtitle)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(MarviColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}
