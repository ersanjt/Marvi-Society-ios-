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
    @Binding var selectedWhen: String?
    @Binding var selectedWhere: String?
    @Binding var selectedEventType: String?

    var body: some View {
        HStack(spacing: 10) {
            axisMenu(icon: "calendar", title: "When", value: $selectedWhen, options: whenOptions)
            axisMenu(icon: "mappin.and.ellipse", title: "Where", value: $selectedWhere, options: whereOptions)
            axisMenu(icon: "sparkles", title: "Event type", value: $selectedEventType, options: eventTypes)
        }
    }

    private func axisMenu(
        icon: String,
        title: String,
        value: Binding<String?>,
        options: [String]
    ) -> some View {
        Menu {
            Button("Any \(title.lowercased())") { value.wrappedValue = nil }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Find and Explore Events")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(MarviColor.muted)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Upcoming Events in")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(MarviColor.ink)
                Text(city)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(MarviGradient.brand)
            }

            Text("\(eventCount) Events found")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MarviColor.rose)
        }
    }
}

struct SSFilterToolbar: View {
    var onFilters: (() -> Void)?
    var onSort: (() -> Void)?
    var onLocation: (() -> Void)?
    var onDate: (() -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let onFilters {
                    SSFilterChip(title: "Filters", icon: "slider.horizontal.3", action: onFilters)
                }
                if let onSort {
                    SSFilterChip(title: "Sort by", icon: "arrow.up.arrow.down", action: onSort)
                }
                if let onLocation {
                    SSFilterChip(title: "Location", icon: "mappin", action: onLocation)
                }
                if let onDate {
                    SSFilterChip(title: "Date", icon: "calendar", action: onDate)
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
