import SwiftUI

struct OfferDetailView: View {
    @EnvironmentObject private var appState: AppState
    let offer: Offer

    @State private var showCancelConfirmation = false
    @State private var showGiftSheet = false
    @State private var showRSVPSheet = false
    @State private var shippingAddress = ""
    @State private var rsvpGuests = 2.0

    private var lang: AppLanguage { appState.preferredLanguage }

    private var isAccepted: Bool { appState.isAccepted(offer) }
    private var isSaved: Bool { appState.isSaved(offer) }
    private var isPending: Bool { appState.isPendingOfferAction(offer) }
    private var isFull: Bool { offer.remaining <= 0 }
    private var isPaused: Bool { appState.profile.status == .paused }
    private var isUnderReview: Bool { appState.profile.status == .underReview }
    private var canAccept: Bool {
        !isPending && !isFull && !isPaused && !isUnderReview && appState.isAuthenticated
    }

    var body: some View {
        MarviScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HeaderBlock(
                        offer: offer,
                        matchScore: appState.profile.score,
                        distanceLabel: appState.distanceLabel(for: offer),
                        isAccepted: isAccepted,
                        isSaved: isSaved,
                        toggleSaved: { appState.toggleSaved(offer) }
                    )

                    if offer.collaborationModel == .event {
                        MarviCard {
                            SectionTitle(
                                title: appState.t(.eventRSVP),
                                subtitle: appState.t(.eventRSVPSub)
                            )
                        }
                    }

                    if offer.collaborationModel == .gift {
                        MarviCard {
                            SectionTitle(
                                title: appState.t(.giftDelivery),
                                subtitle: appState.t(.giftDeliverySub)
                            )
                        }
                    }

                    MarviCard {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionTitle(title: appState.t(.campaignBrief), subtitle: offer.description)

                            HStack(spacing: 10) {
                                MetricTile(value: offer.dateLabel, label: appState.t(.metricDate), icon: "calendar", tint: offer.category.tint)
                                MetricTile(value: offer.timeLabel, label: appState.t(.metricTime), icon: "clock", tint: MarviColor.blue)
                            }

                            HStack(spacing: 10) {
                                MetricTile(value: offer.valueLabel, label: appState.t(.creatorValue), icon: "gift", tint: MarviColor.gold)
                                MetricTile(value: "\(offer.remaining)/\(offer.capacity)", label: appState.t(.openSlots), icon: "person.2", tint: MarviColor.aubergine)
                            }
                        }
                    }

                    MarviCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(title: appState.t(.capacity))

                            HStack {
                                Text(appState.tf(.creatorsConfirmed, offer.capacity - offer.remaining))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MarviColor.ink)
                                Spacer()
                                Text(appState.tf(.percentFilled, Int(fillRatio * 100)))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(MarviColor.muted)
                            }

                            ProgressBar(value: fillRatio, tint: offer.category.tint)
                        }
                    }

                    DetailListCard(title: appState.t(.deliverables), icon: "checklist", items: offer.deliverables, tint: MarviColor.emerald)
                    DetailListCard(title: appState.t(.requirements), icon: "shield.checkered", items: offer.requirements, tint: MarviColor.aubergine)

                    MarviCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(appState.t(.hostNote), systemImage: "person.crop.square")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(MarviColor.ink)
                            Text(offer.hostNote)
                                .font(.subheadline)
                                .foregroundStyle(MarviColor.graphite)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    MarviCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: appState.t(.acceptanceTerms))
                            TermRow(icon: "clock.fill", title: appState.t(.termAttendance), value: appState.t(.termAttendanceVal))
                            TermRow(icon: "camera.fill", title: appState.t(.termContent), value: appState.t(.termContentVal))
                            TermRow(icon: "hand.raised.fill", title: appState.t(.termPolicy), value: appState.t(.termPolicyVal))
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 96)
            }
        }
        .navigationTitle(offer.venue)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                PrimaryActionButton(
                    title: primaryActionTitle,
                    systemImage: primaryActionIcon,
                    isDisabled: isAccepted ? isPending : !canAccept
                ) {
                    if isAccepted {
                        showCancelConfirmation = true
                    } else {
                        beginAcceptFlow()
                    }
                }
            }
            .padding(16)
            .background(MarviColor.panel.opacity(0.95))
        }
        .confirmationDialog(
            appState.t(.cancelInvitationQ),
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button(appState.t(.cancelInvitation), role: .destructive) {
                appState.cancel(offer)
            }
            Button(appState.t(.keepBtn), role: .cancel) {}
        } message: {
            Text(appState.t(.venueNotifiedCancel))
        }
        .sheet(isPresented: $showGiftSheet) {
            AcceptExtrasSheet(
                title: MarviL10n.t(.confirmGift, language: lang),
                actionTitle: MarviL10n.t(.confirmGift, language: lang)
            ) {
                MarviTextField(
                    placeholder: MarviL10n.t(.shippingAddress, language: lang),
                    text: $shippingAddress
                )
            } onConfirm: {
                appState.accept(
                    offer,
                    options: AcceptOfferOptions(shippingAddress: shippingAddress)
                )
            }
        }
        .sheet(isPresented: $showRSVPSheet) {
            AcceptExtrasSheet(
                title: MarviL10n.t(.rsvpEvent, language: lang),
                actionTitle: MarviL10n.t(.rsvpEvent, language: lang)
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(MarviL10n.t(.guestCount, language: lang)): \(Int(rsvpGuests))")
                        .font(.subheadline.weight(.bold))
                    Slider(value: $rsvpGuests, in: 1...6, step: 1)
                        .tint(MarviColor.rose)
                }
            } onConfirm: {
                appState.accept(
                    offer,
                    options: AcceptOfferOptions(rsvpGuests: Int(rsvpGuests))
                )
            }
        }
    }

    private func beginAcceptFlow() {
        switch offer.collaborationModel {
        case .gift:
            showGiftSheet = true
        case .event:
            showRSVPSheet = true
        default:
            appState.accept(offer)
        }
    }

    private var fillRatio: Double {
        guard offer.capacity > 0 else { return 0 }
        return Double(offer.capacity - offer.remaining) / Double(offer.capacity)
    }

    private var primaryActionTitle: String {
        if isPending { return appState.t(.pleaseWait) }
        if isAccepted { return appState.t(.cancelInvitation) }
        if isUnderReview { return appState.t(.awaitingApproval) }
        if isPaused { return appState.t(.membershipPaused) }
        if isFull { return appState.t(.fullyBooked) }
        switch offer.collaborationModel {
        case .instant: return appState.t(.useNow)
        case .event: return appState.t(.rsvpEvent)
        case .gift: return appState.t(.confirmGift)
        default: return appState.t(.acceptInvitation)
        }
    }

    private var primaryActionIcon: String {
        if isAccepted { return "xmark.circle" }
        if offer.collaborationModel == .instant { return "bolt.fill" }
        if offer.collaborationModel == .event { return "person.2.fill" }
        if offer.collaborationModel == .gift { return "shippingbox.fill" }
        return "checkmark.circle"
    }
}

private struct AcceptExtrasSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let title: String
    let actionTitle: String
    @ViewBuilder let content: () -> Content
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(title: title, subtitle: appState.t(.extrasRequiredSub))
                    MarviCard { content() }
                    PrimaryActionButton(title: actionTitle, systemImage: "checkmark.circle") {
                        onConfirm()
                        dismiss()
                    }
                }
                .padding(16)
            }
            .background(MarviColor.surface.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.close)) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct HeaderBlock: View {
    @EnvironmentObject private var appState: AppState
    let offer: Offer
    let matchScore: Int
    let distanceLabel: String?
    let isAccepted: Bool
    let isSaved: Bool
    let toggleSaved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                OfferImageView(offer: offer, height: 96, cornerRadius: 14)
                    .frame(width: 86, height: 96)

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 6) {
                        StatusPill(text: offer.category.label(for: appState.preferredLanguage), tint: offer.category.tint, systemImage: offer.category.icon)
                        StatusPill(text: offer.collaborationModel.label(for: appState.preferredLanguage), tint: MarviColor.gold, systemImage: offer.collaborationModel.icon)
                        if isAccepted {
                            StatusPill(text: appState.t(.confirmedStatus), tint: MarviColor.emerald, systemImage: "checkmark")
                        }
                    }

                    Text(offer.title)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(MarviColor.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)

                    Label("\(offer.venue) · \(offer.area)", systemImage: "mappin.and.ellipse")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MarviColor.muted)
                        .lineLimit(1)

                    if let distanceLabel {
                        Label(distanceLabel, systemImage: "location")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MarviColor.rose)
                    }
                }

                Spacer()
            }

            HStack(spacing: 10) {
                if matchScore > 0 {
                    StatusPill(text: appState.tf(.matchPercent, matchScore), tint: MarviColor.gold, systemImage: "star.fill")
                }
                StatusPill(text: appState.tf(.slotsLeft, offer.remaining), tint: offer.category.tint, systemImage: "person.2")
                Spacer()
                Button(action: toggleSaved) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(isSaved ? MarviColor.rose : MarviColor.muted)
                        .frame(width: 42, height: 42)
                        .background(MarviColor.panelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(MarviColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MarviColor.border, lineWidth: 1)
        )
    }
}

private struct DetailListCard: View {
    let title: String
    let icon: String
    let items: [String]
    let tint: Color

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MarviColor.ink)

                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(tint)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(MarviColor.graphite)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct TermRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MarviColor.rose)
                .frame(width: 30, height: 30)
                .background(MarviColor.rose.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MarviColor.ink)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(MarviColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}
