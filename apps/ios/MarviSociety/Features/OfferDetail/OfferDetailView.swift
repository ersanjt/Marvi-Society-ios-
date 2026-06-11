import SwiftUI

struct OfferDetailView: View {
    @EnvironmentObject private var appState: AppState
    let offer: Offer

    @State private var showCancelConfirmation = false

    private var isAccepted: Bool { appState.isAccepted(offer) }
    private var isSaved: Bool { appState.isSaved(offer) }
    private var isPending: Bool { appState.isPendingOfferAction(offer) }
    private var isFull: Bool { offer.remaining <= 0 }
    private var isPaused: Bool { appState.profile.status == .paused }
    private var canAccept: Bool { !isPending && !isFull && !isPaused && appState.isAuthenticated }

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

                    MarviCard {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionTitle(title: "Campaign brief", subtitle: offer.description)

                            HStack(spacing: 10) {
                                MetricTile(value: offer.dateLabel, label: "date", icon: "calendar", tint: offer.category.tint)
                                MetricTile(value: offer.timeLabel, label: "time", icon: "clock", tint: MarviColor.blue)
                            }

                            HStack(spacing: 10) {
                                MetricTile(value: offer.valueLabel, label: "creator value", icon: "gift", tint: MarviColor.gold)
                                MetricTile(value: "\(offer.remaining)/\(offer.capacity)", label: "open slots", icon: "person.2", tint: MarviColor.aubergine)
                            }
                        }
                    }

                    MarviCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(title: "Capacity")

                            HStack {
                                Text("\(offer.capacity - offer.remaining) creators confirmed")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MarviColor.ink)
                                Spacer()
                                Text("\(Int(fillRatio * 100))% filled")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(MarviColor.muted)
                            }

                            ProgressBar(value: fillRatio, tint: offer.category.tint)
                        }
                    }

                    DetailListCard(title: "Deliverables", icon: "checklist", items: offer.deliverables, tint: MarviColor.emerald)
                    DetailListCard(title: "Requirements", icon: "shield.checkered", items: offer.requirements, tint: MarviColor.aubergine)

                    MarviCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Host note", systemImage: "person.crop.square")
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
                            SectionTitle(title: "Acceptance terms")
                            TermRow(icon: "clock.fill", title: "Attendance", value: "Arrive within the confirmed window.")
                            TermRow(icon: "camera.fill", title: "Content", value: "Deliver all agreed links before the proof deadline.")
                            TermRow(icon: "hand.raised.fill", title: "Policy", value: "No private guest filming without consent.")
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
                        appState.accept(offer)
                    }
                }
            }
            .padding(16)
            .background(MarviColor.panel.opacity(0.95))
        }
        .confirmationDialog(
            "Cancel this invitation?",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel invitation", role: .destructive) {
                appState.cancel(offer)
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("The venue will be notified and your slot may be released.")
        }
    }

    private var fillRatio: Double {
        guard offer.capacity > 0 else { return 0 }
        return Double(offer.capacity - offer.remaining) / Double(offer.capacity)
    }

    private var primaryActionTitle: String {
        if isPending { return "Please wait…" }
        if isAccepted { return "Cancel invitation" }
        if isPaused { return "Membership paused" }
        if isFull { return "Fully booked" }
        if offer.collaborationModel == .instant { return "Use now" }
        return "Accept invitation"
    }

    private var primaryActionIcon: String {
        if isAccepted { return "xmark.circle" }
        if offer.collaborationModel == .instant { return "bolt.fill" }
        return "checkmark.circle"
    }
}

private struct HeaderBlock: View {
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
                        StatusPill(text: offer.category.rawValue, tint: offer.category.tint, systemImage: offer.category.icon)
                        StatusPill(text: offer.collaborationModel.rawValue, tint: MarviColor.gold, systemImage: offer.collaborationModel.icon)
                        if isAccepted {
                            StatusPill(text: "Confirmed", tint: MarviColor.emerald, systemImage: "checkmark")
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
                    StatusPill(text: "\(matchScore)% match", tint: MarviColor.gold, systemImage: "star.fill")
                }
                StatusPill(text: "\(offer.remaining) slots left", tint: offer.category.tint, systemImage: "person.2")
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
