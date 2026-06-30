import SwiftUI

// MARK: - Secret Society UI primitives (screenshot parity)

struct SSSegmentedTabs<T: Hashable>: View {
    let options: [T]
    let title: (T) -> String
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = option }
                } label: {
                    Text(title(option).uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(selection == option ? .white : MarviColor.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selection == option
                                ? AnyShapeStyle(MarviGradient.brand)
                                : AnyShapeStyle(Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(MarviColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MarviColor.border, lineWidth: 1)
        )
    }
}

struct SSToggleTabs: View {
    let leftTitle: String
    let rightTitle: String
    @Binding var isRightSelected: Bool

    var body: some View {
        HStack(spacing: 0) {
            toggleButton(title: leftTitle, isSelected: !isRightSelected) {
                withAnimation(.easeInOut(duration: 0.2)) { isRightSelected = false }
            }
            toggleButton(title: rightTitle, isSelected: isRightSelected) {
                withAnimation(.easeInOut(duration: 0.2)) { isRightSelected = true }
            }
        }
        .padding(4)
        .background(MarviColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MarviColor.border, lineWidth: 1)
        )
    }

    private func toggleButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? .white : MarviColor.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    isSelected
                        ? AnyShapeStyle(MarviGradient.brand)
                        : AnyShapeStyle(Color.clear)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SSSelectableStatusGrid: View {
    let badges: [StatusBadge]
    @Binding var selectedID: UUID?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(badges) { badge in
                let isSelected = selectedID == badge.id
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedID = isSelected ? nil : badge.id
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(badge.count)")
                            .font(.title.weight(.bold))
                            .foregroundStyle(isSelected ? .white : badge.tint)

                        Text(badge.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? .white.opacity(0.9) : MarviColor.muted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        isSelected
                            ? AnyShapeStyle(MarviGradient.brand)
                            : AnyShapeStyle(MarviColor.panel)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? Color.clear : MarviColor.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SSDiscoverAxisPills: View {
    let whenOptions: [String]
    let whereOptions: [String]
    let eventTypes: [String]
    var language: AppLanguage = .turkish
    @Binding var selectedWhen: String?
    @Binding var selectedWhere: String?
    @Binding var selectedEventType: String?

    var body: some View {
        HStack(spacing: 10) {
            axisMenu(icon: "calendar", title: MarviL10n.t(.when, language: language), resetLabel: MarviL10n.t(.anyWhen, language: language), value: $selectedWhen, options: whenOptions)
            axisMenu(icon: "mappin.and.ellipse", title: MarviL10n.t(.whereAxis, language: language), resetLabel: MarviL10n.t(.anyWhere, language: language), value: $selectedWhere, options: whereOptions)
            axisMenu(icon: "sparkles", title: MarviL10n.t(.eventTypeAxis, language: language), resetLabel: MarviL10n.t(.anyType, language: language), value: $selectedEventType, options: eventTypes)
        }
    }

    private func axisMenu(
        icon: String,
        title: String,
        resetLabel: String,
        value: Binding<String?>,
        options: [String]
    ) -> some View {
        Menu {
            Button(resetLabel) { value.wrappedValue = nil }
            Divider()
            ForEach(options, id: \.self) { option in
                Button(option) { value.wrappedValue = option }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MarviColor.rose)
                Text(value.wrappedValue ?? title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MarviColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(MarviColor.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        value.wrappedValue != nil
                            ? MarviGradient.brand
                            : LinearGradient(colors: [MarviColor.border], startPoint: .leading, endPoint: .trailing),
                        lineWidth: value.wrappedValue != nil ? 2 : 1
                    )
            )
        }
    }
}

struct SSExploreHeader: View {
    let city: String
    let eventCount: Int
    var language: AppLanguage = .turkish

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(MarviL10n.t(.findExploreEvents, language: language))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(MarviColor.muted)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(MarviL10n.t(.upNextInCity, language: language))
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(MarviColor.ink)
                Text(city)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(MarviGradient.brand)
            }

            Text(String(format: MarviL10n.t(.eventsFound, language: language), eventCount))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MarviColor.rose)
        }
    }
}

struct SSFilterToolbar: View {
    let language: AppLanguage
    var onFilters: (() -> Void)?
    var onSort: (() -> Void)?
    var onLocation: (() -> Void)?
    var onDate: (() -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let onFilters {
                    SSFilterChip(title: MarviL10n.t(.filters, language: language), icon: "slider.horizontal.3", action: onFilters)
                }
                if let onSort {
                    SSFilterChip(title: MarviL10n.t(.sortBy, language: language), icon: "arrow.up.arrow.down", action: onSort)
                }
                if let onLocation {
                    SSFilterChip(title: MarviL10n.t(.location, language: language), icon: "mappin", action: onLocation)
                }
                if let onDate {
                    SSFilterChip(title: MarviL10n.t(.date, language: language), icon: "calendar", action: onDate)
                }
            }
        }
    }
}

struct SSFilterChip: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(MarviColor.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(MarviColor.panel)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MarviColor.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct SSAvatarRing: View {
    let initials: String
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            Circle()
                .stroke(MarviGradient.brand, lineWidth: 3)
                .frame(width: size + 8, height: size + 8)

            Circle()
                .stroke(MarviColor.blue.opacity(0.5), lineWidth: 1)
                .frame(width: size + 14, height: size + 14)

            ZStack {
                MarviGradient.brandVertical
                Text(initials)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
    }
}

struct SSManagementButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.subheadline.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(MarviGradient.brand)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SSFeaturedEventsCarousel<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(MarviColor.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    content()
                }
            }
        }
    }
}

struct SSDeclineAcceptRow: View {
    let declineTitle: String
    let acceptTitle: String
    let onDecline: () -> Void
    let onAccept: () -> Void
    var acceptDisabled: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onDecline) {
                Text(declineTitle)
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(MarviColor.ink)
            .background(MarviColor.panelElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MarviColor.border, lineWidth: 1)
            )

            Button(action: onAccept) {
                Text(acceptTitle)
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(acceptDisabled ? AnyShapeStyle(MarviColor.muted.opacity(0.4)) : AnyShapeStyle(MarviGradient.brand))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(acceptDisabled)
        }
    }
}

// MARK: - Social sign-in

/// Subtle scale + dim while pressed, used for the social auth buttons.
struct SocialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Faithful four-colour Google "G" rendered as arcs inside a white tile.
struct GoogleGLogo: View {
    var diameter: CGFloat = 20

    var body: some View {
        Canvas { context, size in
            let lineWidth = size.width * 0.26
            let radius = (size.width - lineWidth) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            func arc(from start: Double, to end: Double, color: Color) {
                var path = Path()
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(start),
                    endAngle: .degrees(end),
                    clockwise: false
                )
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            }

            let blue = Color(hex: "#4285F4")
            let green = Color(hex: "#34A853")
            let yellow = Color(hex: "#FBBC05")
            let red = Color(hex: "#EA4335")

            // 0° is at 3 o'clock; angles increase clockwise on screen.
            arc(from: -8, to: 56, color: blue)     // upper-right
            arc(from: 56, to: 138, color: green)   // bottom
            arc(from: 138, to: 213, color: yellow) // left
            arc(from: 213, to: 305, color: red)    // top
            arc(from: 305, to: 352, color: blue)   // right (closes toward the bar)

            // Horizontal blue bar of the G.
            let barHeight = lineWidth
            let bar = CGRect(
                x: center.x,
                y: center.y - barHeight / 2,
                width: radius + lineWidth / 2,
                height: barHeight
            )
            context.fill(Path(bar), with: .color(blue))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

private struct SocialAuthButtonLabel: View {
    enum Kind { case apple, google }

    let kind: Kind
    let title: String
    let isLoading: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                leadingMark
                Text(title)
                    .font(.headline.weight(.semibold))
            }
            .opacity(isLoading ? 0 : 1)

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(kind == .apple ? .white : MarviColor.ink)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .foregroundStyle(kind == .apple ? Color.white : MarviColor.ink)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: kind == .apple ? 0 : 1)
        )
        .shadow(color: Color.black.opacity(kind == .apple ? 0.18 : 0.06), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder private var leadingMark: some View {
        switch kind {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 19, weight: .medium))
        case .google:
            GoogleGLogo(diameter: 20)
        }
    }

    private var background: Color {
        kind == .apple ? Color.black : Color.white
    }

    private var borderColor: Color {
        kind == .apple ? .clear : Color(hex: "#DADCE0")
    }
}

/// Official-styled "Continue with Apple" button with an inline loading state.
struct AppleSignInButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SocialAuthButtonLabel(kind: .apple, title: title, isLoading: isLoading)
        }
        .buttonStyle(SocialButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled && !isLoading ? 0.55 : 1)
        .accessibilityLabel(title)
    }
}

/// Official-styled "Continue with Google" button with an inline loading state.
struct GoogleSignInButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SocialAuthButtonLabel(kind: .google, title: title, isLoading: isLoading)
        }
        .buttonStyle(SocialButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled && !isLoading ? 0.55 : 1)
        .accessibilityLabel(title)
    }
}

/// Styled divider used above the social sign-in buttons, e.g. "or continue with".
struct SocialDivider: View {
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(MarviColor.border).frame(height: 1)
            Text(label)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(MarviColor.muted)
                .fixedSize()
            Rectangle().fill(MarviColor.border).frame(height: 1)
        }
    }
}
