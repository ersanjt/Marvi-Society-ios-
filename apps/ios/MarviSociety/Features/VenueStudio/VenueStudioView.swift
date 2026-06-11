import SwiftUI

private enum VenueReviewSegment: String, CaseIterable {
    case checkedIn = "Checked in"
    case checkedOut = "Checked out"
    case noShow = "No show"
}

private enum VenueStudioTab: String, CaseIterable {
    case establishments = "Establishments"
    case brands = "Brands"
}

struct VenueStudioView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingBuilder = false
    @State private var isShowingSwipe = false
    @State private var reviewSegment: VenueReviewSegment = .checkedIn
    @State private var studioTab: VenueStudioTab = .establishments
    @State private var isShowingInbox = false

    private var firstName: String {
        appState.profile.displayName
    }

    private var filteredReviewQueue: [VenueReviewItem] {
        appState.venueReviewQueue.filter { item in
            switch reviewSegment {
            case .checkedIn:
                return item.stage == .checkedIn && !item.hasReview
            case .checkedOut:
                return item.stage == .proofDue
                    || item.stage == .completed
                    || item.hasReview
                    || item.proofStatus == .approved
                    || item.proofStatus == .pending
            case .noShow:
                return item.stage == .cancelled
            }
        }
    }

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HomeHeader(
                            greeting: firstName,
                            subtitle: "Venue partner workspace",
                            onNotifications: { isShowingInbox = true }
                        )
                        .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Manage your events")
                                .font(.system(size: 30, weight: .bold, design: .serif))
                                .foregroundStyle(MarviColor.ink)

                            Text("at your establishments")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(MarviGradient.brand)
                        }

                        if let task = appState.campaigns.first(where: { $0.status == .live }) {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Live campaign")
                                        .font(.caption.weight(.bold))
                                        .textCase(.uppercase)
                                        .foregroundStyle(MarviColor.muted)

                                    Text(task.title)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(MarviColor.ink)

                                    Text("\(task.venueName) · \(task.slots) creator slots")
                                        .font(.caption)
                                        .foregroundStyle(MarviColor.muted)

                                    GradientCTA(title: "Review creators", action: { isShowingSwipe = true })
                                }
                            }
                        }

                        StudioStatusGrid(
                            onCreate: { isShowingBuilder = true },
                            onSwipe: { isShowingSwipe = true }
                        )

                        SSSegmentedTabs(
                            options: VenueStudioTab.allCases,
                            title: { $0.rawValue },
                            selection: $studioTab
                        )

                        if studioTab == .establishments {
                            SectionTitle(
                                title: "Campaigns",
                                subtitle: "\(appState.campaigns.count) active in this workspace"
                            )

                            ForEach(appState.campaigns) { campaign in
                                CampaignCard(campaign: campaign)
                            }
                        } else {
                            SectionTitle(
                                title: "Brand partners",
                                subtitle: "Campaigns linked to your venue workspace."
                            )

                            if appState.campaigns.isEmpty {
                                MarviCard {
                                    EmptyStateView(
                                        title: "No brand campaigns yet",
                                        subtitle: "Submit a campaign for admin review to publish on Explore.",
                                        icon: "tag",
                                        actionTitle: "Refresh",
                                        action: { Task { await appState.refreshFromServer() } }
                                    )
                                }
                            } else {
                                ForEach(appState.campaigns) { campaign in
                                    CampaignCard(campaign: campaign)
                                }
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    SectionTitle(
                                        title: "To Review",
                                        subtitle: "Share your thoughts after creator visits."
                                    )
                                    Spacer()
                                    if !filteredReviewQueue.isEmpty {
                                        Text("\(filteredReviewQueue.count)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(MarviGradient.brand)
                                            .clipShape(Capsule())
                                    }
                                }

                                SSSegmentedTabs(
                                    options: VenueReviewSegment.allCases,
                                    title: { $0.rawValue },
                                    selection: $reviewSegment
                                )

                                if filteredReviewQueue.isEmpty {
                                    EmptyStateView(
                                        title: "No reviews in this tab",
                                        subtitle: "Creators appear here after check-in or checkout.",
                                        icon: "star.bubble"
                                    )
                                } else {
                                    ForEach(filteredReviewQueue) { item in
                                        VenueReviewRow(item: item)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await appState.refreshFromServer()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingBuilder) {
                CampaignBuilderSheet()
                    .environmentObject(appState)
            }
            .fullScreenCover(isPresented: $isShowingSwipe) {
                InfluencerSwipeView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $isShowingInbox) {
                NavigationStack {
                    InboxView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { isShowingInbox = false }
                            }
                        }
                }
            }
        }
    }
}

struct InfluencerSwipeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var candidates: [InfluencerCandidate] = []
    @State private var dragOffset: CGSize = .zero
    @State private var isLoading = true

    private var liveOfferID: UUID? {
        appState.campaigns.first(where: { $0.status == .live })?.id
    }

    var body: some View {
        ZStack {
            MarviColor.surface.ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(MarviColor.ink)
                            .frame(width: 40, height: 40)
                            .background(MarviColor.panel)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 2) {
                        Text(appState.campaigns.first?.title ?? "Creator matching")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                        Text("\(candidates.count) creators left")
                            .font(.caption)
                            .foregroundStyle(MarviColor.muted)
                    }

                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if isLoading {
                    Spacer()
                    ProgressView().tint(MarviColor.rose).scaleEffect(1.3)
                    Text("Loading creators…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MarviColor.muted)
                    Spacer()
                } else if let current = candidates.first {
                    SwipeCard(candidate: current, offset: dragOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { dragOffset = $0.translation }
                                .onEnded { value in
                                    if value.translation.width > 120 {
                                        swipeAway(direction: .right)
                                    } else if value.translation.width < -120 {
                                        swipeAway(direction: .left)
                                    } else {
                                        withAnimation(.spring()) { dragOffset = .zero }
                                    }
                                }
                        )
                        .padding(.horizontal, 20)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: candidates.isEmpty ? "person.2.slash" : "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(candidates.isEmpty ? MarviColor.muted : MarviColor.emerald)

                        Text(candidates.isEmpty ? "No creators to match" : "Shortlist complete")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(MarviColor.ink)

                        Text(candidates.isEmpty
                            ? "When your campaign is live, creator applications will appear here for swiping."
                            : "All creators in this batch have been reviewed.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(MarviColor.muted)
                            .padding(.horizontal, 32)

                        GradientCTA(title: "Close", action: { dismiss() })
                            .padding(.horizontal, 40)
                    }
                    .frame(maxHeight: .infinity)
                }

                HStack(spacing: 40) {
                    SwipeActionButton(icon: "xmark", tint: MarviColor.rose) {
                        swipeAway(direction: .left)
                    }
                    SwipeActionButton(icon: "checkmark", tint: MarviColor.aubergine) {
                        swipeAway(direction: .right)
                    }
                }
                .padding(.bottom, 32)
                .opacity(candidates.isEmpty ? 0 : 1)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            isLoading = true
            candidates = await appState.loadSwipeCandidates(offerID: liveOfferID)
            isLoading = false
        }
    }

    private enum SwipeDirection { case left, right }

    private func swipeAway(direction: SwipeDirection) {
        let current = candidates.first
        let exit: CGFloat = direction == .right ? 500 : -500
        withAnimation(.easeIn(duration: 0.25)) {
            dragOffset = CGSize(width: exit, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if direction == .right, let current {
                Task { await appState.shortlistCreator(current, offerID: liveOfferID) }
            }
            if direction == .left, let current {
                Task { await appState.passCreator(current, offerID: liveOfferID) }
            }
            if !candidates.isEmpty { candidates.removeFirst() }
            dragOffset = .zero
        }
    }
}

private struct VenueReviewRow: View {
    @EnvironmentObject private var appState: AppState
    let item: VenueReviewItem
    @State private var isShowingDetail = false

    var body: some View {
        Button {
            isShowingDetail = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title)
                    .foregroundStyle(MarviColor.rose)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.creatorName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                    Text(item.instagramHandle)
                        .font(.caption)
                        .foregroundStyle(MarviColor.muted)
                    Text(item.offerTitle)
                        .font(.caption)
                        .foregroundStyle(MarviColor.graphite)
                    Text(item.checkedInLabel)
                        .font(.caption2)
                        .foregroundStyle(MarviColor.muted)
                }

                Spacer()

                Text("Review")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MarviColor.rose)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isShowingDetail) {
            VenueReviewDetailSheet(item: item)
                .environmentObject(appState)
        }
    }
}

private struct VenueReviewDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let item: VenueReviewItem

    @State private var punctuality = 4.0
    @State private var presentation = 4.0
    @State private var comment = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        MarviCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(item.creatorName)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(MarviColor.ink)
                                Text(item.instagramHandle)
                                    .font(.subheadline)
                                    .foregroundStyle(MarviColor.muted)
                                StatusPill(text: item.stageLabel, tint: MarviColor.gold, systemImage: "clock")
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionTitle(title: "Visit", subtitle: item.offerTitle)
                                Text("Checked in \(item.checkedInLabel)")
                                    .font(.subheadline)
                                    .foregroundStyle(MarviColor.muted)
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionTitle(title: "Share your thoughts", subtitle: "Rate punctuality and presentation.")

                                ratingRow(title: "Punctuality", value: $punctuality)
                                ratingRow(title: "Presentation", value: $presentation)

                                MarviTextField(placeholder: "Optional note", text: $comment)
                            }
                        }

                        if item.hasReview {
                            Label("Review already submitted — saving again will update it.", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MarviColor.emerald)
                        }

                        GradientCTA(
                            title: isSubmitting ? "Saving…" : "Submit review",
                            action: {
                                Task {
                                    isSubmitting = true
                                    let ok = await appState.submitVenueReview(
                                        bookingID: item.id,
                                        punctuality: Int(punctuality.rounded()),
                                        presentation: Int(presentation.rounded()),
                                        comment: comment
                                    )
                                    isSubmitting = false
                                    if ok { dismiss() }
                                }
                            }
                        )
                        .disabled(isSubmitting)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Creator review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(MarviColor.rose)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func ratingRow(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MarviColor.ink)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))/5")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MarviColor.rose)
            }
            Slider(value: value, in: 1...5, step: 1)
                .tint(MarviColor.rose)
        }
    }
}

private struct SwipeCard: View {
    let candidate: InfluencerCandidate
    let offset: CGSize

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                MarviGradient.brandVertical
                Image(systemName: "person.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(height: 280)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(MarviColor.ink)

                        Text(candidate.niche)
                            .font(.subheadline)
                            .foregroundStyle(MarviColor.muted)
                    }

                    Spacer()

                    StatusPill(text: "\(candidate.score)", tint: MarviColor.gold, systemImage: "star.fill")
                }

                HStack(spacing: 10) {
                    TraitBadge(title: "Punctuality", value: candidate.punctuality)
                    TraitBadge(title: "Presentation", value: candidate.presentation)
                }

                Text("\(candidate.followers) followers")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MarviColor.rose)
            }
            .padding(20)
            .background(MarviColor.panel)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MarviColor.border, lineWidth: 1)
        )
        .offset(offset)
        .rotationEffect(.degrees(Double(offset.width / 20)))
    }
}

private struct TraitBadge: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MarviColor.muted)
            Text("\(value)%")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MarviColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(MarviColor.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SwipeActionButton: View {
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(tint)
                .clipShape(Circle())
                .shadow(color: tint.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct CampaignCard: View {
    let campaign: Campaign

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: campaign.category.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(campaign.category.tint)
                        .frame(width: 44, height: 44)
                        .background(campaign.category.tint.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        StatusPill(text: campaign.status.rawValue, tint: statusTint, systemImage: "circle.fill")
                        Text(campaign.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                        Text("\(campaign.venueName) · \(campaign.area)")
                            .font(.subheadline)
                            .foregroundStyle(MarviColor.muted)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    InfoBadge(icon: "calendar", text: campaign.dateLabel)
                    InfoBadge(icon: "gift", text: campaign.valueLabel)
                    InfoBadge(icon: "person.2", text: "\(campaign.matchedCreators)/\(campaign.slots)")
                }
            }
        }
    }

    private var statusTint: Color {
        switch campaign.status {
        case .draft: MarviColor.muted
        case .review: MarviColor.gold
        case .live: MarviColor.emerald
        case .completed: MarviColor.blue
        }
    }
}

private struct CampaignBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var title = ""
    @State private var venueName = ""
    @State private var area = ""
    @State private var category: OfferCategory = .dining
    @State private var collaborationModel: CollaborationModel = .invitation
    @State private var campaignDate = Date().addingTimeInterval(86400 * 7)
    @State private var valueLabel = ""
    @State private var deliverablesText = ""
    @State private var slots = 10.0
    @State private var isSubmitting = false
    @State private var venueLocked = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(title: "New campaign", subtitle: "Submitted for admin review before going live.")

                    MarviCard {
                        VStack(alignment: .leading, spacing: 14) {
                            MarviTextField(placeholder: "Campaign title", text: $title)
                            MarviTextField(placeholder: "Venue name", text: $venueName)
                                .disabled(venueLocked)
                            MarviTextField(placeholder: "Area", text: $area)
                                .disabled(venueLocked)
                            DatePicker(
                                "Event date",
                                selection: $campaignDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MarviColor.ink)
                            MarviTextField(placeholder: "Value (e.g. Dinner for 2)", text: $valueLabel)
                            MarviTextField(placeholder: "Deliverables, comma separated", text: $deliverablesText)

                            Text("Collaboration model")
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(MarviColor.muted)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(CollaborationModel.allCases) { model in
                                        Button {
                                            collaborationModel = model
                                        } label: {
                                            Label(model.rawValue, systemImage: model.icon)
                                                .font(.caption.weight(.bold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .foregroundStyle(collaborationModel == model ? .white : MarviColor.ink)
                                                .background(
                                                    collaborationModel == model
                                                        ? AnyShapeStyle(MarviGradient.brand)
                                                        : AnyShapeStyle(MarviColor.panelElevated)
                                                )
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Creator slots: \(Int(slots))")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(MarviColor.ink)
                                Slider(value: $slots, in: 2...30, step: 1)
                                    .tint(MarviColor.rose)
                            }
                        }
                    }

                    PrimaryActionButton(
                        title: isSubmitting ? "Submitting…" : "Send to admin review",
                        systemImage: "paperplane.fill",
                        isDisabled: !canSubmitCampaign || isSubmitting
                    ) {
                        Task {
                            isSubmitting = true
                            let success = await appState.createCampaign(
                                title: title,
                                venueName: venueName,
                                area: area,
                                category: category,
                                collaborationModel: collaborationModel,
                                dateLabel: Self.dateFormatter.string(from: campaignDate),
                                valueLabel: valueLabel.isEmpty ? "Complimentary experience" : valueLabel,
                                slots: Int(slots),
                                deliverables: campaignDeliverables
                            )
                            isSubmitting = false
                            if success { dismiss() }
                        }
                    }
                }
                .padding(16)
            }
            .background(MarviColor.surface.ignoresSafeArea())
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if let venue = await appState.loadVenueSummary() {
                    venueName = venue.venueName
                    area = venue.area
                    category = venue.category
                    venueLocked = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var campaignDeliverables: [String] {
        deliverablesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canSubmitCampaign: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !venueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !area.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !campaignDeliverables.isEmpty
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()
}
