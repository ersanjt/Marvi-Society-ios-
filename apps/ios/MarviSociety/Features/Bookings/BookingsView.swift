import PhotosUI
import SwiftUI

private enum EventBucket: CaseIterable, Identifiable {
    case requests, toConfirm, toReview, toVisit

    var id: Self { self }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .requests: MarviL10n.t(.requests, language: language)
        case .toConfirm: MarviL10n.t(.toConfirm, language: language)
        case .toReview: MarviL10n.t(.toReview, language: language)
        case .toVisit: MarviL10n.t(.toVisit, language: language)
        }
    }
}

struct BookingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var proofBooking: Booking?
    @State private var checkInBooking: Booking?
    @State private var selectedOffer: Offer?
    @State private var isShowingInbox = false
    @State private var isInterestMode = false
    @State private var selectedBucketID: UUID?
    @State private var selectedCategory: OfferCategory?

    private var statusBadges: [StatusBadge] {
        [
            StatusBadge(
                title: EventBucket.requests.title(for: appState.preferredLanguage),
                count: appState.pendingInviteBookings.count + appState.interestOffers.count,
                tint: MarviColor.rose
            ),
            StatusBadge(
                title: EventBucket.toConfirm.title(for: appState.preferredLanguage),
                count: appState.bookings.filter { $0.stage == .confirmed }.count,
                tint: MarviColor.aubergine
            ),
            StatusBadge(
                title: EventBucket.toReview.title(for: appState.preferredLanguage),
                count: appState.bookings.filter { $0.stage == .proofDue || $0.proofStatus == .pending }.count,
                tint: MarviColor.gold
            ),
            StatusBadge(
                title: EventBucket.toVisit.title(for: appState.preferredLanguage),
                count: appState.bookings.filter { $0.stage == .checkedIn }.count,
                tint: MarviColor.blue
            )
        ]
    }

    private var activeBucket: EventBucket? {
        guard let id = selectedBucketID,
              let index = statusBadges.firstIndex(where: { $0.id == id }),
              index < EventBucket.allCases.count else { return nil }
        return EventBucket.allCases[index]
    }

    private var displayedBookings: [Booking] {
        if isInterestMode { return [] }

        let base: [Booking]
        switch activeBucket {
        case .requests, .none:
            base = appState.pendingInviteBookings
        case .toConfirm:
            base = appState.bookings.filter { $0.stage == .confirmed }
        case .toReview:
            base = appState.bookings.filter { $0.stage == .proofDue || $0.proofStatus == .pending }
        case .toVisit:
            base = appState.bookings.filter { $0.stage == .checkedIn }
        }

        guard let selectedCategory else { return base }
        return base.filter { $0.offer.category == selectedCategory }
    }

    private var displayedInterestOffers: [Offer] {
        guard isInterestMode else { return [] }
        guard let selectedCategory else { return appState.interestOffers }
        return appState.interestOffers.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appState.t(.myEventsTitle))
                                    .font(.system(size: 34, weight: .bold, design: .serif))
                                    .foregroundStyle(MarviColor.ink)

                                Text(appState.t(.myEventsSub))
                                    .font(.subheadline)
                                    .foregroundStyle(MarviColor.muted)
                            }

                            Spacer()

                            Button { isShowingInbox = true } label: {
                                Image(systemName: "bell")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(MarviColor.ink)
                                    .frame(width: 40, height: 40)
                                    .background(MarviColor.panel)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 4)

                        SSSelectableStatusGrid(badges: statusBadges, selectedID: $selectedBucketID)

                        SSToggleTabs(
                            leftTitle: appState.t(.pendingInvites),
                            rightTitle: appState.t(.interestShown),
                            isRightSelected: $isInterestMode
                        )

                        SSFilterToolbar(
                            language: appState.preferredLanguage,
                            onFilters: { selectedCategory = nil },
                            onSort: nil,
                            onLocation: nil,
                            onDate: nil
                        )

                        if selectedCategory != nil || activeBucket != nil {
                            FilterPillRow(
                                items: OfferCategory.allCases.map(\.rawValue),
                                selected: Binding(
                                    get: { selectedCategory?.rawValue },
                                    set: { newValue in
                                        selectedCategory = OfferCategory.allCases.first { $0.rawValue == newValue }
                                    }
                                )
                            )
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    SSFilterChip(title: appState.t(.categoryLabel), icon: "tag") {
                                        selectedCategory = .dining
                                    }
                                }
                            }
                        }

                        if isInterestMode {
                            interestContent
                        } else {
                            bookingsContent
                        }
                    }
                    .padding(16)
                }
                .refreshable { await appState.refreshFromServer() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $proofBooking) { booking in
                ProofSubmissionSheet(booking: booking)
                    .environmentObject(appState)
            }
            .sheet(item: $checkInBooking) { booking in
                CheckInSheet(booking: booking)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $isShowingInbox) {
                NavigationStack {
                    InboxView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(appState.t(.done)) { isShowingInbox = false }
                            }
                        }
                }
            }
            .navigationDestination(item: $selectedOffer) { offer in
                OfferDetailView(offer: offer)
            }
            .onAppear {
                if selectedBucketID == nil {
                    selectedBucketID = statusBadges.first?.id
                }
            }
        }
    }

    @ViewBuilder
    private var interestContent: some View {
        if displayedInterestOffers.isEmpty {
            MarviCard {
                EmptyStateView(
                    title: appState.t(.noInterestShown),
                    subtitle: appState.t(.saveEventsExploreSub),
                    icon: "heart",
                    actionTitle: appState.t(.refresh),
                    action: { Task { await appState.refreshFromServer() } }
                )
            }
        } else {
            ForEach(displayedInterestOffers) { offer in
                InterestOfferCard(offer: offer) {
                    selectedOffer = offer
                } accept: {
                    appState.accept(offer)
                } decline: {
                    appState.toggleSaved(offer)
                }
            }
        }
    }

    @ViewBuilder
    private var bookingsContent: some View {
        if appState.isSyncing && displayedBookings.isEmpty {
            MarviCard {
                HStack {
                    Spacer()
                    ProgressView().tint(MarviColor.rose)
                    Spacer()
                }
                .padding(.vertical, 32)
            }
        } else if displayedBookings.isEmpty {
            MarviCard {
                EmptyStateView(
                    title: emptyTitle,
                    subtitle: emptySubtitle,
                    icon: "calendar.badge.plus",
                    actionTitle: appState.t(.refresh),
                    action: { Task { await appState.refreshFromServer() } }
                )
            }
        } else {
            ForEach(displayedBookings) { booking in
                BookingCard(booking: booking) {
                    selectedOffer = booking.offer
                } checkIn: {
                    checkInBooking = booking
                } submitProof: {
                    proofBooking = booking
                } decline: {
                    appState.decline(booking)
                } accept: {
                    if booking.stage == .invited {
                        appState.accept(booking.offer)
                    } else {
                        checkInBooking = booking
                    }
                }
            }
        }
    }

    private var emptyTitle: String {
        switch activeBucket {
        case .requests, .none: appState.t(.noPendingInvites)
        case .toConfirm: appState.t(.nothingToConfirm)
        case .toReview: appState.t(.nothingToReview)
        case .toVisit: appState.t(.noVisitsScheduled)
        }
    }

    private var emptySubtitle: String {
        switch activeBucket {
        case .requests, .none: appState.t(.emptyRequestsSub)
        case .toConfirm: appState.t(.emptyConfirmSub)
        case .toReview: appState.t(.emptyReviewSub)
        case .toVisit: appState.t(.emptyVisitSub)
        }
    }
}

private struct InterestOfferCard: View {
    @EnvironmentObject private var appState: AppState
    let offer: Offer
    let open: () -> Void
    let accept: () -> Void
    let decline: () -> Void

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: open) {
                    HStack(spacing: 12) {
                        OfferImageView(offer: offer, height: 72, cornerRadius: 12)
                            .frame(width: 64, height: 72)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(offer.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(MarviColor.ink)
                            Text("\(offer.venue) · \(offer.area)")
                                .font(.caption)
                                .foregroundStyle(MarviColor.muted)
                            Text("\(offer.dateLabel) · \(offer.timeLabel)")
                                .font(.caption2)
                                .foregroundStyle(MarviColor.graphite)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                SSDeclineAcceptRow(
                    declineTitle: appState.t(.decline),
                    acceptTitle: appState.t(.accept),
                    onDecline: decline,
                    onAccept: accept
                )
            }
        }
    }
}

private struct BookingCard: View {
    @EnvironmentObject private var appState: AppState
    let booking: Booking
    let open: () -> Void
    let checkIn: () -> Void
    let submitProof: () -> Void
    let decline: () -> Void
    let accept: () -> Void

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 14) {
                Button(action: open) {
                    HStack(alignment: .top, spacing: 12) {
                        OfferImageView(offer: booking.offer, height: 72, cornerRadius: 12)
                            .frame(width: 64, height: 72)

                        VStack(alignment: .leading, spacing: 6) {
                            StatusPill(text: booking.stage.label(for: appState.preferredLanguage), tint: stageTint, systemImage: "circle.fill")

                            Text(booking.offer.title)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(MarviColor.ink)

                            Label("\(booking.offer.venue) · \(booking.offer.area)", systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                                .foregroundStyle(MarviColor.muted)

                            Text("\(booking.offer.dateLabel) · \(booking.offer.timeLabel)")
                                .font(.caption)
                                .foregroundStyle(MarviColor.graphite)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)

                if booking.stage == .invited {
                    SSDeclineAcceptRow(
                        declineTitle: "Decline",
                        acceptTitle: "Accept",
                        onDecline: decline,
                        onAccept: accept
                    )
                } else if booking.stage != .completed && booking.stage != .cancelled {
                    HStack(spacing: 10) {
                        Button(action: decline) {
                            Text(appState.t(.decline))
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MarviColor.ink)
                        .background(MarviColor.panelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Button(action: checkIn) {
                            Label(primaryActionTitle, systemImage: primaryActionIcon)
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(canPrimaryAction ? .white : MarviColor.muted)
                        .background(canPrimaryAction ? AnyShapeStyle(MarviGradient.brand) : AnyShapeStyle(MarviColor.panelElevated))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .disabled(!canPrimaryAction)
                    }

                    if booking.stage == .checkedIn || booking.stage == .proofDue {
                        Button(action: submitProof) {
                            Label(appState.t(.submitProof), systemImage: "tray.and.arrow.up")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(MarviColor.panelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private var canPrimaryAction: Bool {
        booking.stage == .confirmed || booking.stage == .checkedIn || booking.stage == .proofDue
    }

    private var primaryActionTitle: String {
        switch booking.stage {
        case .confirmed: appState.t(.checkIn)
        case .checkedIn, .proofDue: appState.t(.addProof)
        default: appState.t(.checkIn)
        }
    }

    private var primaryActionIcon: String {
        switch booking.stage {
        case .confirmed: "checkmark.circle"
        case .checkedIn, .proofDue: "tray.and.arrow.up"
        default: "checkmark.circle"
        }
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
}

// MARK: - Proof & Check-in sheets (unchanged)

private struct BookingTimeline: View {
    @EnvironmentObject private var appState: AppState
    let stage: BookingStage
    let proofStatus: ProofStatus

    var body: some View {
        HStack(spacing: 8) {
            TimelineStep(title: appState.t(.timelineConfirm), isDone: true)
            TimelineLine(isDone: stage != .invited)
            TimelineStep(title: appState.t(.timelineCheckIn), isDone: stage == .checkedIn || stage == .completed)
            TimelineLine(isDone: proofStatus == .pending || proofStatus == .approved)
            TimelineStep(title: appState.t(.timelineProof), isDone: proofStatus == .pending || proofStatus == .approved)
        }
        .padding(10)
        .background(MarviColor.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct TimelineStep: View {
    let title: String
    let isDone: Bool

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isDone ? MarviColor.emerald : MarviColor.panel)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isDone ? MarviColor.ink : MarviColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TimelineLine: View {
    let isDone: Bool

    var body: some View {
        Rectangle()
            .fill(isDone ? MarviColor.emerald.opacity(0.5) : MarviColor.border)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}

struct CheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let booking: Booking
    @State private var code = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            MarviScreen {
                VStack(alignment: .leading, spacing: 20) {
                    SectionTitle(
                        title: appState.t(.checkInAtVenue),
                        subtitle: appState.t(.checkInSheetSub)
                    )

                    MarviTextField(placeholder: appState.t(.checkInCode), text: $code, autocapitalization: .characters)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MarviColor.tomato)
                    }

                    GradientCTA(title: isSubmitting ? appState.t(.checkingIn) : appState.t(.confirmCheckIn)) {
                        Task {
                            isSubmitting = true
                            errorMessage = nil
                            let error = await appState.checkIn(booking, code: code)
                            isSubmitting = false
                            if let error {
                                errorMessage = error
                            } else {
                                dismiss()
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(appState.t(.checkInNav))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.close)) { dismiss() }
                }
            }
        }
    }
}

struct ProofSubmissionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let booking: Booking
    @State private var linksText = ""
    @State private var isSubmitting = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        SectionTitle(
                            title: appState.t(.submitProofTitle),
                            subtitle: String(format: appState.t(.submitProofSub), booking.offer.venue)
                        )

                        MarviTextField(
                            placeholder: "https://instagram.com/p/…",
                            text: $linksText,
                            autocapitalization: .never
                        )

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(appState.t(.attachScreenshot), systemImage: "photo")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MarviColor.rose)
                        .background(MarviColor.rose.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MarviColor.tomato)
                        }

                        GradientCTA(title: isSubmitting ? appState.t(.submitting) : appState.t(.sendToReview)) {
                            Task {
                                isSubmitting = true
                                errorMessage = nil
                                let links = linksText
                                    .split(whereSeparator: \.isNewline)
                                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }

                                var imageData: Data?
                                if let selectedPhoto {
                                    imageData = try? await selectedPhoto.loadTransferable(type: Data.self)
                                }

                                let error = await appState.submitProof(
                                    for: booking,
                                    links: links,
                                    imageData: imageData,
                                    fileName: "proof-\(booking.id.uuidString.prefix(8)).jpg"
                                )
                                isSubmitting = false
                                if let error {
                                    errorMessage = error
                                } else {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(appState.t(.proofNav))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.close)) { dismiss() }
                }
            }
        }
    }
}
