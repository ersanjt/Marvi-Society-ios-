import SwiftUI

struct BookingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var proofBooking: Booking?

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        BrandLockup(subtitle: "Creator operations")

                        HStack(spacing: 10) {
                            MetricTile(value: "\(appState.activeBookings.count)", label: "active", icon: "calendar", tint: MarviColor.emerald)
                            MetricTile(value: "\(pendingProofCount)", label: "proof queue", icon: "tray.and.arrow.up", tint: MarviColor.gold)
                            MetricTile(value: appState.profile.proofRate, label: "delivery", icon: "checkmark.seal", tint: MarviColor.blue)
                        }

                        SectionTitle(
                            title: "Your invitations",
                            subtitle: "Check in, track deadlines, and submit campaign proof."
                        )

                        if appState.activeBookings.isEmpty {
                            MarviCard {
                                EmptyStateView(
                                    title: "No active bookings",
                                    subtitle: "Accept an invitation from Discover and it will appear here.",
                                    icon: "calendar.badge.plus"
                                )
                            }
                        } else {
                            ForEach(appState.activeBookings) { booking in
                                BookingCard(booking: booking) {
                                    appState.checkIn(booking)
                                } submitProof: {
                                    proofBooking = booking
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Bookings")
            .sheet(item: $proofBooking) { booking in
                ProofSubmissionSheet(booking: booking)
                    .environmentObject(appState)
            }
        }
    }

    private var pendingProofCount: Int {
        appState.activeBookings.filter { $0.proofStatus == .notStarted || $0.proofStatus == .pending }.count
    }
}

private struct BookingCard: View {
    let booking: Booking
    let checkIn: () -> Void
    let submitProof: () -> Void

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        StatusPill(text: booking.stage.rawValue, tint: stageTint, systemImage: "circle.fill")

                        Text(booking.offer.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MarviColor.ink)

                        Label("\(booking.offer.venue) - \(booking.offer.area)", systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(MarviColor.muted)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: booking.offer.category.icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(booking.offer.category.tint)
                        .frame(width: 46, height: 46)
                        .background(booking.offer.category.tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                HStack(spacing: 10) {
                    InfoBadge(icon: "calendar", text: booking.offer.dateLabel)
                    InfoBadge(icon: "clock", text: booking.offer.timeLabel)
                    InfoBadge(icon: "tray.and.arrow.up", text: booking.proofDeadline)
                }

                HStack(spacing: 10) {
                    StatusPill(text: "Code \(booking.checkInCode)", tint: MarviColor.aubergine, systemImage: "qrcode")
                    StatusPill(text: booking.proofStatus.rawValue, tint: proofTint, systemImage: "doc.text")
                }

                Divider()

                BookingTimeline(stage: booking.stage, proofStatus: booking.proofStatus)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Checklist")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MarviColor.ink)

                    ForEach(booking.checklist, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle")
                                .font(.caption)
                                .foregroundStyle(MarviColor.emerald)
                                .padding(.top, 3)

                            Text(item)
                                .font(.subheadline)
                                .foregroundStyle(MarviColor.graphite)
                        }
                    }
                }

                if !booking.proofLinks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Submitted proof")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MarviColor.ink)

                        ForEach(booking.proofLinks, id: \.self) { link in
                            Label(link, systemImage: "link")
                                .font(.caption)
                                .foregroundStyle(MarviColor.blue)
                                .lineLimit(1)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        checkIn()
                    } label: {
                        Label("Check in", systemImage: "checkmark.circle")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(canCheckIn ? .white : MarviColor.muted)
                    .background(canCheckIn ? MarviColor.emerald : MarviColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(!canCheckIn)

                    Button {
                        submitProof()
                    } label: {
                        Label("Proof", systemImage: "tray.and.arrow.up")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(MarviColor.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(booking.stage == .completed)
                    .opacity(booking.stage == .completed ? 0.55 : 1)
                }
            }
        }
    }

    private var canCheckIn: Bool {
        booking.stage == .confirmed || booking.stage == .invited
    }

    private var stageTint: Color {
        switch booking.stage {
        case .invited: MarviColor.gold
        case .confirmed: MarviColor.emerald
        case .checkedIn: MarviColor.blue
        case .proofDue: MarviColor.tomato
        case .completed: MarviColor.aubergine
        case .cancelled: MarviColor.muted
        }
    }

    private var proofTint: Color {
        switch booking.proofStatus {
        case .notStarted: MarviColor.muted
        case .pending: MarviColor.gold
        case .approved: MarviColor.emerald
        case .flagged: MarviColor.tomato
        }
    }
}

private struct BookingTimeline: View {
    let stage: BookingStage
    let proofStatus: ProofStatus

    var body: some View {
        HStack(spacing: 8) {
            TimelineStep(title: "Confirm", isDone: true)
            TimelineLine(isDone: stage != .invited)
            TimelineStep(title: "Check in", isDone: stage == .checkedIn || stage == .completed)
            TimelineLine(isDone: proofStatus == .pending || proofStatus == .approved)
            TimelineStep(title: "Proof", isDone: proofStatus == .pending || proofStatus == .approved)
        }
        .padding(10)
        .background(MarviColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TimelineStep: View {
    let title: String
    let isDone: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isDone ? MarviColor.emerald : MarviColor.muted)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MarviColor.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TimelineLine: View {
    let isDone: Bool

    var body: some View {
        Rectangle()
            .fill(isDone ? MarviColor.emerald : Color.black.opacity(0.08))
            .frame(width: 22, height: 2)
    }
}

private struct ProofSubmissionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let booking: Booking

    @State private var storyLink = "https://instagram.com/stories/example"
    @State private var postLink = "https://instagram.com/reel/example"
    @State private var reviewLink = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(
                        title: "Submit proof",
                        subtitle: "\(booking.offer.venue) needs evidence for the agreed deliverables."
                    )

                    MarviCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Instagram story link", text: $storyLink)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)

                            TextField("Instagram post or Reel link", text: $postLink)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)

                            TextField("Google or venue review link", text: $reviewLink)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    DetailListCardPreview(items: booking.offer.deliverables)

                    if !canSubmit {
                        Label("Add at least one valid proof link before sending.", systemImage: "exclamationmark.triangle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MarviColor.tomato)
                    }

                    PrimaryActionButton(
                        title: "Send proof",
                        systemImage: "paperplane.fill",
                        isDisabled: !canSubmit
                    ) {
                        let links = proofLinks
                        appState.submitProof(for: booking, links: links)
                        dismiss()
                    }
                }
                .padding(16)
            }
            .background(MarviColor.surface.ignoresSafeArea())
            .navigationTitle("Proof")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !appState.autoSaveProofLinks else { return }
                storyLink = ""
                postLink = ""
                reviewLink = ""
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var proofLinks: [String] {
        [storyLink, postLink, reviewLink]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
    }

    private var canSubmit: Bool {
        !proofLinks.isEmpty
    }
}

private struct DetailListCardPreview: View {
    let items: [String]

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Required deliverables")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MarviColor.ink)

                ForEach(items, id: \.self) { item in
                    Label(item, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(MarviColor.graphite)
                }
            }
        }
    }
}
