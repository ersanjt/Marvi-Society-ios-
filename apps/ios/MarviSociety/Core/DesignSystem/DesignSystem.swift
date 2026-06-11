import SwiftUI

// Theme tokens: Core/DesignSystem/Theme/*
// Shared components: Core/DesignSystem/Components/*

struct MarviCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(MarviColor.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MarviColor.border, lineWidth: 1)
            )
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
                Ellipse()
                    .fill(MarviGradient.brandVertical)
                    .frame(height: 280)
                    .blur(radius: 80)
                    .opacity(0.35)
                    .offset(y: -80)
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MarviGradient.brand)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)

            Text("M")
                .font(.system(size: size * 0.48, weight: .bold, design: .serif))
                .foregroundStyle(.white)
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

                Text(subtitle.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
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
        .background(tint.opacity(0.16))
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
            .background(MarviColor.panelElevated)
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
        .background(MarviColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MarviColor.border, lineWidth: 1)
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
                MarviColor.muted.opacity(0.4)
            } else {
                MarviGradient.brand
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        .background(MarviColor.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MarviColor.border, lineWidth: 1)
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
                    .fill(Color.white.opacity(0.08))

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
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(MarviColor.rose)

            Text(title)
                .font(.headline)
                .foregroundStyle(MarviColor.ink)

            Text(subtitle)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(MarviColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MarviColor.rose)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct SyncErrorBanner: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(MarviColor.tomato)

            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MarviColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button("Retry", action: onRetry)
                .font(.caption.weight(.bold))
                .foregroundStyle(MarviColor.rose)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MarviColor.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(MarviColor.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MarviColor.tomato.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct MembershipStatusBanner: View {
    let status: MembershipStatus

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MarviColor.ink)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(MarviColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }

    private var title: String {
        switch status {
        case .underReview: "Application under review"
        case .approved: "Membership approved"
        case .paused: "Membership paused"
        }
    }

    private var message: String {
        switch status {
        case .underReview:
            "You can browse events while we verify your profile. Accepting invitations may be limited until approval."
        case .approved:
            "Your creator profile is active. Accept invitations and submit proof after each visit."
        case .paused:
            "Your account is paused. Contact support to restore access."
        }
    }

    private var icon: String {
        switch status {
        case .underReview: "hourglass"
        case .approved: "checkmark.seal.fill"
        case .paused: "pause.circle.fill"
        }
    }

    private var tint: Color {
        switch status {
        case .underReview: MarviColor.gold
        case .approved: MarviColor.emerald
        case .paused: MarviColor.tomato
        }
    }
}

struct OfferListSkeleton: View {
    var body: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MarviColor.panel)
                    .frame(height: 96)
                    .overlay(
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(MarviColor.panelElevated)
                                .frame(width: 72, height: 80)
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(MarviColor.panelElevated)
                                    .frame(width: 120, height: 10)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(MarviColor.panelElevated)
                                    .frame(height: 14)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(MarviColor.panelElevated)
                                    .frame(width: 90, height: 10)
                            }
                            Spacer()
                        }
                        .padding(14)
                    )
            }
        }
        .redacted(reason: .placeholder)
    }
}

struct BootstrapSplashView: View {
    var body: some View {
        ZStack {
            MarviColor.surface.ignoresSafeArea()
            VStack(spacing: 20) {
                BrandMark(size: 72)
                ProgressView()
                    .tint(MarviColor.rose)
                Text("Loading your workspace…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MarviColor.muted)
            }
        }
    }
}

// MARK: - Premium components (Secret Society style)

struct HomeHeader: View {
    let greeting: String
    let subtitle: String
    var onSearch: (() -> Void)?
    var onNotifications: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                MarviGradient.brand
                Text(String(greeting.prefix(1)))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Hi, \(greeting)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MarviColor.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(MarviColor.muted)
            }

            Spacer()

            if let onSearch {
                HeaderIconButton(icon: "magnifyingglass", action: onSearch)
            }
            if let onNotifications {
                HeaderIconButton(icon: "bell", action: onNotifications)
            }
        }
    }
}

struct HeaderIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(MarviColor.ink)
                .frame(width: 40, height: 40)
                .background(MarviColor.panel)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct FilterPillRow: View {
    let items: [String]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items, id: \.self) { item in
                    Button {
                        selected = selected == item ? nil : item
                    } label: {
                        Text(item)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selected == item ? .white : MarviColor.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selected == item ? AnyShapeStyle(MarviGradient.brand) : AnyShapeStyle(MarviColor.panel))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(MarviColor.border, lineWidth: selected == item ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct EventCalendarStrip: View {
    @Binding var selectedDay: Int?
    let days: [CalendarDay]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(days) { day in
                    Button {
                        selectedDay = selectedDay == day.id ? nil : day.id
                    } label: {
                        VStack(spacing: 6) {
                            Text(day.weekday)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(selectedDay == day.id ? .white : MarviColor.muted)

                            Text(day.label)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(selectedDay == day.id ? .white : MarviColor.ink)
                        }
                        .frame(width: 52, height: 64)
                        .background(selectedDay == day.id ? AnyShapeStyle(MarviGradient.brand) : AnyShapeStyle(MarviColor.panel))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(MarviColor.border, lineWidth: selectedDay == day.id ? 0 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct CalendarDay: Identifiable {
    let id: Int
    let weekday: String
    let label: String
    var date: Date?
}

struct StatusBadgeGrid: View {
    let badges: [StatusBadge]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(badges) { badge in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(badge.count)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(badge.tint)

                    Text(badge.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MarviColor.muted)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(badge.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

struct StatusBadge: Identifiable {
    let id = UUID()
    let title: String
    let count: Int
    let tint: Color
}

struct GradientCTA: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.subheadline.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(MarviGradient.brand)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ProfileHealthRing: View {
    let score: Int
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 10)

            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(MarviGradient.brand, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(MarviColor.rose.opacity(0.35), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(6)

            VStack(spacing: 2) {
                Text("\(score)%")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(MarviColor.ink)

                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MarviColor.muted)
            }
        }
        .frame(width: 110, height: 110)
    }
}

struct MarviTextField: View {
    let placeholder: String
    @Binding var text: String
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        TextField(placeholder, text: $text)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .padding(12)
            .foregroundStyle(MarviColor.ink)
            .background(MarviColor.panelElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MarviColor.border, lineWidth: 1)
            )
    }
}

struct StudioStatusGrid: View {
    let onCreate: () -> Void
    let onSwipe: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            StudioGridTile(title: "Under\nReview", icon: "clock", tint: MarviColor.gold)
            StudioGridTile(title: "Upcoming\nEvents", icon: "calendar", tint: MarviColor.blue)
            StudioGridTile(title: "Open for\nswipe", icon: "hand.draw", tint: MarviColor.rose, action: onSwipe)
            StudioGridTile(title: "Happening", icon: "sparkles", tint: MarviColor.emerald)
            StudioGridTile(title: "Past", icon: "archivebox", tint: MarviColor.muted)
            StudioGridTile(title: "Create", icon: "plus", tint: MarviColor.aubergine, action: onCreate)
        }
    }
}

private struct StudioGridTile: View {
    let title: String
    let icon: String
    let tint: Color
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.caption2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MarviColor.muted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background(MarviColor.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MarviColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

enum MarviL10n {
    static func t(_ key: Key, language: AppLanguage) -> String {
        switch language {
        case .english: english[key] ?? key.rawValue
        case .turkish: turkish[key] ?? english[key] ?? key.rawValue
        }
    }

    enum Key: String {
        case explore, myEvents, profile, studio, inbox, account, admin
        case acceptInvitation, rsvpEvent, confirmGift, useNow
        case shippingAddress, guestCount, saveProfile, syncFromServer
        case openAdminConsole, inboxTitle, inboxEmpty
    }

    private static let english: [Key: String] = [
        .explore: "Explore",
        .myEvents: "My Events",
        .profile: "Profile",
        .studio: "Studio",
        .inbox: "Inbox",
        .account: "Account",
        .admin: "Admin",
        .acceptInvitation: "Accept invitation",
        .rsvpEvent: "Confirm RSVP",
        .confirmGift: "Confirm gift delivery",
        .useNow: "Use now",
        .shippingAddress: "Shipping address",
        .guestCount: "Guest count",
        .saveProfile: "Save to account",
        .syncFromServer: "Sync from server",
        .openAdminConsole: "Open admin console",
        .inboxTitle: "Inbox",
        .inboxEmpty: "Inbox is clear"
    ]

    private static let turkish: [Key: String] = [
        .explore: "Keşfet",
        .myEvents: "Etkinliklerim",
        .profile: "Profil",
        .studio: "Stüdyo",
        .inbox: "Gelen Kutusu",
        .account: "Hesap",
        .admin: "Admin",
        .acceptInvitation: "Daveti kabul et",
        .rsvpEvent: "RSVP onayla",
        .confirmGift: "Hediye gönderimini onayla",
        .useNow: "Hemen kullan",
        .shippingAddress: "Teslimat adresi",
        .guestCount: "Misafir sayısı",
        .saveProfile: "Hesaba kaydet",
        .syncFromServer: "Sunucudan senkronize et",
        .openAdminConsole: "Admin konsolunu aç",
        .inboxTitle: "Gelen Kutusu",
        .inboxEmpty: "Gelen kutusu boş"
    ]
}
