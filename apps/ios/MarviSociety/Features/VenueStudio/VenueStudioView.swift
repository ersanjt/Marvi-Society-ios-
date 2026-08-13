import PhotosUI
import SwiftUI
import UIKit

private enum VenueReviewSegment: CaseIterable, Identifiable {
    case checkedIn, checkedOut, noShow

    var id: Self { self }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .checkedIn: MarviL10n.t(.segmentCheckedIn, language: language)
        case .checkedOut: MarviL10n.t(.segmentCheckedOut, language: language)
        case .noShow: MarviL10n.t(.segmentNoShow, language: language)
        }
    }
}

private enum StudioCampaignScope: CaseIterable, Identifiable {
    case underReview, upcoming, happening, past

    var id: Self { self }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .underReview: MarviL10n.t(.studioUnderReview, language: language)
        case .upcoming: MarviL10n.t(.studioUpcoming, language: language)
        case .happening: MarviL10n.t(.studioHappening, language: language)
        case .past: MarviL10n.t(.studioPast, language: language)
        }
    }

    var isPast: Bool { self == .past }
}

struct VenueStudioView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingBuilder = false
    @State private var isShowingSwipe = false
    @State private var isShowingAddVenue = false
    @State private var editingVenueID: UUID?
    @State private var reviewSegment: VenueReviewSegment = .checkedIn
    @State private var campaignScope: StudioCampaignScope = .happening
    @State private var isShowingInbox = false
    @State private var campaignPendingDelete: Campaign?
    @State private var isDeletingCampaign = false
    @State private var deleteFeedback: String?
    @State private var studioBrands: [BrandSummary] = []
    @State private var studioActionMessage: String?

    private var firstName: String {
        appState.profile.displayName
    }

    private var focusedVenue: VenueSummary? {
        appState.activeVenue ?? appState.myVenues.first
    }

    private var canCreateCampaignNow: Bool {
        focusedVenue?.status == .approved
    }

    private var focusedVenueHasLiveCampaign: Bool {
        !campaignsForFocusedVenue.filter { $0.status == .live }.isEmpty
    }

    private var activeCampaignsEmptySubtitle: String {
        switch focusedVenue?.status {
        case .underReview:
            return appState.t(.venuePendingBannerSub)
        case .paused:
            return appState.t(.venueRejectedBannerSub)
        case .approved:
            return appState.t(.noActiveCampaignsApprovedSub)
        case .none:
            return appState.t(.noActiveCampaignsSub)
        }
    }

    private var campaignsForFocusedVenue: [Campaign] {
        let visible = appState.campaigns.filter { !$0.isDeleted }
        guard let active = focusedVenue else { return visible }
        let matched = visible.filter { campaign in
            if let venueID = campaign.venueID {
                return venueID == active.id
            }
            return campaign.venueName.caseInsensitiveCompare(active.venueName) == .orderedSame
                && campaign.area.caseInsensitiveCompare(active.area) == .orderedSame
        }
        // Fall back to all account campaigns if venue_id hasn't synced yet.
        return matched.isEmpty ? visible : matched
    }

    private var studioCampaigns: [Campaign] {
        let visible = campaignsForFocusedVenue
        switch campaignScope {
        case .underReview:
            return visible.filter { $0.status == .review }
        case .upcoming:
            // Auto-live campaigns land as .live; include draft for any legacy rows.
            return visible.filter { $0.status == .live || $0.status == .draft }
        case .happening:
            return visible.filter { $0.status == .live }
        case .past:
            return visible.filter { $0.status == .completed }
        }
    }

    private var liveCampaignForActiveVenue: Campaign? {
        campaignsForFocusedVenue.first(where: { $0.status == .live })
    }

    private var filteredReviewQueue: [VenueReviewItem] {
        appState.venueReviewQueue.filter { item in
            switch reviewSegment {
            case .checkedIn:
                return item.stage == .checkedIn && !item.hasReview
            case .checkedOut:
                // Needs venue feedback after the visit / proof window.
                return !item.hasReview && (
                    item.stage == .proofDue
                        || item.stage == .completed
                        || item.proofStatus == .pending
                        || item.proofStatus == .approved
                )
            case .noShow:
                return item.stage == .cancelled
            }
        }
    }

    private var reviewEmptySubtitle: String {
        switch reviewSegment {
        case .checkedIn: appState.t(.noReviewsCheckedInSub)
        case .checkedOut: appState.t(.noReviewsCheckedOutSub)
        case .noShow: appState.t(.noReviewsNoShowSub)
        }
    }

    private func openCampaignBuilder() {
        studioActionMessage = nil
        guard canCreateCampaignNow else {
            studioActionMessage = focusedVenue?.status == .paused
                ? appState.t(.venueRejectedBannerSub)
                : appState.t(.venuePendingBannerSub)
            return
        }
        isShowingBuilder = true
    }

    private func openSwipe() {
        studioActionMessage = nil
        guard liveCampaignForActiveVenue != nil else {
            studioActionMessage = appState.t(.swipeNeedsLiveSub)
            campaignScope = .happening
            return
        }
        isShowingSwipe = true
    }

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HomeHeader(
                            greeting: firstName,
                            subtitle: appState.t(.venuePartnerWorkspace),
                            onProfile: { appState.navigate(to: .profile) },
                            onNotifications: { isShowingInbox = true }
                        )
                        .padding(.top, 4)

                        if !appState.venuePendingConfirmations.isEmpty {
                            VenuePendingConfirmationsCard(bookings: appState.venuePendingConfirmations)
                        }

                        VenueContextBar(
                            venues: appState.myVenues,
                            onSelect: { venue in
                                Task { _ = await appState.switchActiveVenue(to: venue.id) }
                            },
                            onAdd: { isShowingAddVenue = true },
                            onEdit: { venueID in editingVenueID = venueID }
                        )

                        if let studioActionMessage {
                            Text(studioActionMessage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MarviColor.gold)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Status + primary actions (compact — no duplicate banners)
                        if focusedVenue?.status == .underReview {
                            MarviCard {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "clock.fill")
                                        .foregroundStyle(MarviColor.gold)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(appState.t(.venuePendingBannerTitle))
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(MarviColor.ink)
                                        Text(appState.t(.venuePendingBannerSub))
                                            .font(.caption)
                                            .foregroundStyle(MarviColor.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        } else if focusedVenue?.status == .paused, let venueID = focusedVenue?.id {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(MarviColor.tomato)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(appState.t(.venueRejectedBannerTitle))
                                                .font(.subheadline.weight(.bold))
                                            Text(appState.t(.venueRejectedBannerSub))
                                                .font(.caption)
                                                .foregroundStyle(MarviColor.muted)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    PrimaryActionButton(
                                        title: appState.t(.venueEditAndResubmit),
                                        systemImage: "pencil.and.outline"
                                    ) {
                                        editingVenueID = venueID
                                    }
                                }
                            }
                        } else if focusedVenue?.status == .approved {
                            if !focusedVenueHasLiveCampaign, canCreateCampaignNow {
                                PrimaryActionButton(
                                    title: appState.t(.newCampaign),
                                    systemImage: "plus.circle.fill"
                                ) {
                                    openCampaignBuilder()
                                }
                            } else if let task = liveCampaignForActiveVenue {
                                MarviCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text(appState.t(.liveCampaign))
                                                .font(.caption.weight(.bold))
                                                .textCase(.uppercase)
                                                .foregroundStyle(MarviColor.muted)
                                            Spacer()
                                            StatusPill(text: appState.t(.locationApproved), tint: MarviColor.emerald)
                                        }
                                        Text(task.title)
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(MarviColor.ink)
                                        Text(String(format: appState.t(.creatorSlotsVenue), task.venueName, task.slots))
                                            .font(.caption)
                                            .foregroundStyle(MarviColor.muted)
                                        GradientCTA(title: appState.t(.reviewCreators), action: { openSwipe() })
                                    }
                                }
                            }

                            HStack(spacing: 10) {
                                if focusedVenueHasLiveCampaign, canCreateCampaignNow {
                                    SecondaryActionButton(
                                        title: appState.t(.newCampaign),
                                        systemImage: "plus"
                                    ) {
                                        openCampaignBuilder()
                                    }
                                }
                                if let venueID = focusedVenue?.id {
                                    SecondaryActionButton(
                                        title: appState.t(.estWizardEditTitle),
                                        systemImage: "mappin.and.ellipse"
                                    ) {
                                        editingVenueID = venueID
                                    }
                                }
                            }
                        }

                        SectionTitle(
                            title: appState.t(.campaigns),
                            subtitle: String(format: appState.t(.campaignsSub), studioCampaigns.count)
                        )

                        SSSegmentedTabs(
                            options: StudioCampaignScope.allCases,
                            title: { scope in
                                scope.title(for: appState.preferredLanguage)
                                    .replacingOccurrences(of: "\n", with: " ")
                            },
                            selection: $campaignScope
                        )

                        if let deleteFeedback {
                            Text(deleteFeedback)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MarviColor.emerald)
                        }

                        if studioCampaigns.isEmpty {
                            MarviCard {
                                EmptyStateView(
                                    title: campaignScope == .past
                                        ? appState.t(.noPastCampaigns)
                                        : appState.t(.noActiveCampaigns),
                                    subtitle: campaignScope == .past
                                        ? appState.t(.noPastCampaignsSub)
                                        : activeCampaignsEmptySubtitle,
                                    icon: campaignScope == .past ? "archivebox" : "megaphone",
                                    actionTitle: campaignScope != .past && canCreateCampaignNow
                                        ? appState.t(.studioCreate) : nil,
                                    action: campaignScope != .past && canCreateCampaignNow
                                        ? { openCampaignBuilder() } : nil
                                )
                            }
                        } else {
                            ForEach(studioCampaigns) { campaign in
                                CampaignCard(campaign: campaign) {
                                    campaignPendingDelete = campaign
                                }
                            }
                        }

                        // Brands — secondary, collapsed by default via tab only when needed
                        DisclosureGroup {
                            if studioBrands.isEmpty {
                                Text(appState.t(.noBrandsYetSub))
                                    .font(.caption)
                                    .foregroundStyle(MarviColor.muted)
                                    .padding(.top, 8)
                            } else {
                                ForEach(studioBrands) { brand in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(brand.brandName)
                                                .font(.subheadline.weight(.semibold))
                                            Text(brand.organizationName)
                                                .font(.caption2)
                                                .foregroundStyle(MarviColor.muted)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        } label: {
                            Text(appState.t(.brandPartners))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(MarviColor.ink)
                        }
                        .tint(MarviColor.muted)

                        MarviCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(appState.t(.toReview))
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(MarviColor.ink)
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

                                Text(appState.t(.toReviewVenueSub))
                                    .font(.caption)
                                    .foregroundStyle(MarviColor.muted)

                                SSSegmentedTabs(
                                    options: VenueReviewSegment.allCases,
                                    title: { $0.title(for: appState.preferredLanguage) },
                                    selection: $reviewSegment
                                )

                                if filteredReviewQueue.isEmpty {
                                    EmptyStateView(
                                        title: appState.t(.noReviewsTab),
                                        subtitle: reviewEmptySubtitle,
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
                    studioBrands = await appState.fetchMyBrands()
                }
                .task {
                    studioBrands = await appState.fetchMyBrands()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingBuilder) {
                CampaignBuilderSheet()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $isShowingAddVenue) {
                EstablishmentWizardView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: Binding(
                get: { editingVenueID != nil },
                set: { if !$0 { editingVenueID = nil } }
            )) {
                if let editingVenueID {
                    EstablishmentWizardView(editingVenueID: editingVenueID)
                        .environmentObject(appState)
                }
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
                                Button(appState.t(.done)) { isShowingInbox = false }
                            }
                        }
                }
            }
            .confirmationDialog(
                appState.t(.deleteCampaignConfirm),
                isPresented: Binding(
                    get: { campaignPendingDelete != nil },
                    set: { if !$0 { campaignPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(appState.t(.delete), role: .destructive) {
                    guard let campaign = campaignPendingDelete else { return }
                    campaignPendingDelete = nil
                    isDeletingCampaign = true
                    Task {
                        let ok = await appState.venueSoftDeleteCampaign(campaign)
                        await MainActor.run {
                            isDeletingCampaign = false
                            if ok {
                                deleteFeedback = appState.t(.campaignDeletedMsg)
                            } else {
                                deleteFeedback = appState.lastSyncError
                            }
                        }
                    }
                }
                Button(appState.t(.cancel), role: .cancel) {
                    campaignPendingDelete = nil
                }
            }
            .disabled(isDeletingCampaign)
        }
    }
}

struct InfluencerSwipeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var candidates: [InfluencerCandidate] = []
    @State private var dragOffset: CGSize = .zero
    @State private var isLoading = true
    @State private var selectedProfileCandidate: InfluencerCandidate?

    private var liveOfferID: UUID? {
        guard let active = appState.activeVenue else {
            return appState.campaigns.first(where: { !$0.isDeleted && $0.status == .live })?.id
        }
        let scoped = appState.campaigns.first(where: {
            !$0.isDeleted && $0.status == .live && (
                $0.venueID == active.id
                    || (
                        $0.venueID == nil
                            && $0.venueName.caseInsensitiveCompare(active.venueName) == .orderedSame
                            && $0.area.caseInsensitiveCompare(active.area) == .orderedSame
                    )
            )
        })
        return scoped?.id
    }

    private var liveCampaignTitle: String {
        guard let id = liveOfferID else { return appState.t(.creatorMatching) }
        return appState.campaigns.first(where: { $0.id == id })?.title ?? appState.t(.creatorMatching)
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
                        Text(liveCampaignTitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                        Text(appState.tf(.creatorsLeft, candidates.count))
                            .font(.caption)
                            .foregroundStyle(MarviColor.muted)
                    }

                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if liveOfferID == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 48))
                            .foregroundStyle(MarviColor.rose)
                        Text(appState.t(.swipeNeedsLiveTitle))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                        Text(appState.t(.swipeNeedsLiveSub))
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(MarviColor.muted)
                            .padding(.horizontal, 32)
                        GradientCTA(title: appState.t(.close), action: { dismiss() })
                            .padding(.horizontal, 40)
                    }
                    .frame(maxHeight: .infinity)
                } else if isLoading {
                    Spacer()
                    ProgressView().tint(MarviColor.rose).scaleEffect(1.3)
                    Text(appState.t(.loadingCreators))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MarviColor.muted)
                    Spacer()
                } else if let current = candidates.first {
                    VStack(spacing: 12) {
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

                        Button {
                            selectedProfileCandidate = current
                        } label: {
                            Label(appState.t(.viewPublicProfile), systemImage: "person.crop.circle.badge.checkmark")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(MarviColor.rose)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(MarviColor.panel)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: candidates.isEmpty ? "person.2.slash" : "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(candidates.isEmpty ? MarviColor.muted : MarviColor.emerald)

                        Text(candidates.isEmpty ? appState.t(.noCreatorsMatch) : appState.t(.shortlistComplete))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(MarviColor.ink)

                        Text(candidates.isEmpty
                            ? appState.t(.noCreatorsMatchSub)
                            : appState.t(.allReviewedSub))
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(MarviColor.muted)
                            .padding(.horizontal, 32)

                        GradientCTA(title: appState.t(.close), action: { dismiss() })
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
        .sheet(item: $selectedProfileCandidate) { candidate in
            CreatorPublicProfileView(creatorID: candidate.id, fallbackName: candidate.name)
                .environmentObject(appState)
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

                Text(appState.t(.reviewLabel))
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
                                SectionTitle(title: appState.t(.visitLabel), subtitle: item.offerTitle)
                                Text(String(format: appState.t(.checkedInAt), item.checkedInLabel))
                                    .font(.subheadline)
                                    .foregroundStyle(MarviColor.muted)
                            }
                        }

                        MarviCard {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionTitle(title: appState.t(.shareThoughts), subtitle: appState.t(.shareThoughtsSub))

                                ratingRow(title: appState.t(.punctuality), value: $punctuality)
                                ratingRow(title: appState.t(.presentation), value: $presentation)

                                MarviTextField(placeholder: appState.t(.optionalNote), text: $comment)
                            }
                        }

                        if item.hasReview {
                            Label(appState.t(.reviewAlreadySubmitted), systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MarviColor.emerald)
                        } else {
                            GradientCTA(
                                title: isSubmitting ? appState.t(.saving) : appState.t(.submitReview),
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
                    }
                    .padding(16)
                }
            }
            .navigationTitle(appState.t(.creatorReviewNav))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.done)) { dismiss() }
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
    @EnvironmentObject private var appState: AppState
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
                    TraitBadge(title: appState.t(.punctuality), value: candidate.punctuality)
                    TraitBadge(title: appState.t(.presentation), value: candidate.presentation)
                }

                Text(appState.tf(.followersCount, candidate.followers))
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
    @EnvironmentObject private var appState: AppState
    let campaign: Campaign
    var onDelete: () -> Void

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
                        StatusPill(text: campaign.status.label(for: appState.preferredLanguage), tint: statusTint, systemImage: "circle.fill")
                        Text(campaign.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                        Text("\(campaign.venueName) · \(campaign.area)")
                            .font(.subheadline)
                            .foregroundStyle(MarviColor.muted)
                    }
                    Spacer(minLength: 8)
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MarviColor.tomato)
                            .frame(width: 36, height: 36)
                            .background(MarviColor.tomato.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(appState.t(.delete))
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
    @State private var descriptionText = ""
    @State private var timeLabel = ""
    @State private var requirementsText = ""
    @State private var hostNoteText = ""
    @State private var slots = 10.0
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var venueLocked = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoPreview: UIImage?

    var body: some View {
        let addCampaignPhotoTitle = appState.t(.addCampaignPhoto)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(title: appState.t(.newCampaign), subtitle: appState.t(.newCampaignSub))

                    MarviCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(appState.t(.campaignImageLabel))
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(MarviColor.muted)

                            PhotosPicker(selection: $photoItem, matching: .images) {
                                ZStack {
                                    if let photoPreview {
                                        Image(uiImage: photoPreview)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        MarviColor.panelElevated
                                        Label(addCampaignPhotoTitle, systemImage: "photo.on.rectangle")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(MarviColor.rose)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .onChange(of: photoItem) { _, item in
                                Task {
                                    guard let item,
                                          let data = try? await item.loadTransferable(type: Data.self),
                                          let image = UIImage(data: data) else { return }
                                    photoData = data
                                    photoPreview = image
                                }
                            }

                            MarviTextField(placeholder: appState.t(.campaignTitlePh), text: $title)
                            MarviTextField(placeholder: appState.t(.venueNamePh), text: $venueName)
                                .disabled(venueLocked)
                            MarviTextField(placeholder: appState.t(.areaPh), text: $area)
                                .disabled(venueLocked)
                            DatePicker(
                                appState.t(.eventDateLabel),
                                selection: $campaignDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MarviColor.ink)
                            MarviTextField(placeholder: appState.t(.campaignTimePh), text: $timeLabel)
                            MarviTextField(placeholder: appState.t(.valuePh), text: $valueLabel)
                            MarviTextField(placeholder: appState.t(.campaignDescriptionPh), text: $descriptionText)
                            MarviTextField(placeholder: appState.t(.deliverablesPh), text: $deliverablesText)
                            MarviTextField(placeholder: appState.t(.campaignRequirementsPh), text: $requirementsText)
                            MarviTextField(placeholder: appState.t(.campaignHostNotePh), text: $hostNoteText)

                            Text(appState.t(.collaborationModelLabel))
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(MarviColor.muted)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(CollaborationModel.allCases) { model in
                                        Button {
                                            collaborationModel = model
                                        } label: {
                                            Label(model.label(for: appState.preferredLanguage), systemImage: model.icon)
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
                                Text(appState.tf(.creatorSlotsCount, Int(slots)))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(MarviColor.ink)
                                Slider(value: $slots, in: 2...30, step: 1)
                                    .tint(MarviColor.rose)
                            }
                        }
                    }

                    if let submitError, !submitError.isEmpty {
                        Text(submitError)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MarviColor.tomato)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PrimaryActionButton(
                        title: isSubmitting ? appState.t(.submitting) : appState.t(.sendToAdminReview),
                        systemImage: "paperplane.fill",
                        isDisabled: !canSubmitCampaign,
                        isLoading: isSubmitting
                    ) {
                        submitCampaign()
                    }
                }
                .padding(16)
            }
            .background(MarviColor.surface.ignoresSafeArea())
            .navigationTitle(appState.t(.createNav))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.close)) { dismiss() }
                        .disabled(isSubmitting)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .task {
                var venue = appState.activeVenue
                if venue == nil {
                    venue = await appState.loadVenueSummary()
                }
                if let venue {
                    venueName = venue.venueName
                    area = venue.area
                    category = venue.category
                    venueLocked = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func submitCampaign() {
        guard !isSubmitting, canSubmitCampaign else { return }
        submitError = nil
        isSubmitting = true
        Task { @MainActor in
            let success = await appState.createCampaign(
                title: title,
                venueName: venueName,
                area: area,
                category: category,
                collaborationModel: collaborationModel,
                dateLabel: Self.dateFormatter.string(from: campaignDate),
                valueLabel: valueLabel.isEmpty ? "Complimentary experience" : valueLabel,
                slots: Int(slots),
                deliverables: campaignDeliverables,
                imageData: photoData,
                description: descriptionText,
                timeLabel: timeLabel.isEmpty ? "Flexible" : timeLabel,
                requirements: campaignRequirements,
                hostNote: hostNoteText
            )
            if success {
                dismiss()
                return
            }
            submitError = appState.lastSyncError
                ?? (appState.preferredLanguage == .turkish
                    ? "Kampanya gönderilemedi. Tekrar dene."
                    : "Could not submit campaign. Please try again.")
            isSubmitting = false
        }
    }

    private var campaignDeliverables: [String] {
        deliverablesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var campaignRequirements: [String] {
        requirementsText
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

private struct VenueContextBar: View {
    @EnvironmentObject private var appState: AppState
    let venues: [VenueSummary]
    let onSelect: (VenueSummary) -> Void
    let onAdd: () -> Void
    let onEdit: (UUID) -> Void

    var body: some View {
        if venues.isEmpty {
            MarviCard {
                EmptyStateView(
                    title: appState.t(.addLocation),
                    subtitle: appState.t(.addLocationSub),
                    icon: "building.2.crop.circle",
                    actionTitle: appState.t(.addLocation),
                    action: onAdd
                )
            }
        } else if venues.count == 1, let venue = venues.first {
            singleVenueRow(venue)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(appState.t(.myLocations))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                    Spacer()
                    Button(action: onAdd) {
                        Label(appState.t(.addLocation), systemImage: "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MarviColor.rose)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(venues) { venue in
                            Button { onSelect(venue) } label: {
                                VenueLocationChip(venue: venue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func singleVenueRow(_ venue: VenueSummary) -> some View {
        MarviCard {
            HStack(spacing: 12) {
                Image(systemName: venue.category.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MarviColor.rose)
                    .frame(width: 40, height: 40)
                    .background(MarviColor.rose.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(venue.venueName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(venue.area)
                            .font(.caption)
                            .foregroundStyle(MarviColor.muted)
                        statusLabel(for: venue)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    onEdit(venue.id)
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MarviColor.ink)
                        .padding(10)
                        .background(MarviColor.panelElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appState.t(.estWizardEditTitle))

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MarviColor.rose)
                        .padding(10)
                        .background(MarviColor.rose.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appState.t(.addLocation))
            }
        }
    }

    @ViewBuilder
    private func statusLabel(for venue: VenueSummary) -> some View {
        if venue.status == .underReview {
            Text(appState.t(.locationPendingReview))
                .font(.caption2.weight(.bold))
                .foregroundStyle(MarviColor.gold)
        } else if venue.status == .approved {
            Text(appState.t(.locationApproved))
                .font(.caption2.weight(.bold))
                .foregroundStyle(MarviColor.emerald)
        } else if venue.status == .paused {
            Text(appState.t(.locationRejected))
                .font(.caption2.weight(.bold))
                .foregroundStyle(MarviColor.tomato)
        }
    }
}

private struct VenueLocationsCard: View {
    @EnvironmentObject private var appState: AppState
    let venues: [VenueSummary]
    let onSelect: (VenueSummary) -> Void
    let onAdd: () -> Void

    var body: some View {
        VenueContextBar(
            venues: venues,
            onSelect: onSelect,
            onAdd: onAdd,
            onEdit: { _ in }
        )
    }
}

private struct VenueLocationChip: View {
    @EnvironmentObject private var appState: AppState
    let venue: VenueSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(venue.venueName)
                .font(.caption.weight(.bold))
                .lineLimit(1)
            Text(venue.area)
                .font(.caption2)
                .foregroundStyle(venue.isActive ? Color.white.opacity(0.85) : MarviColor.muted)
                .lineLimit(1)
        }
        .foregroundStyle(venue.isActive ? Color.white : MarviColor.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            venue.isActive
                ? AnyShapeStyle(MarviGradient.brand)
                : AnyShapeStyle(MarviColor.panelElevated)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct AddVenueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var name = ""
    @State private var area = ""
    @State private var address = ""
    @State private var contactPhone = ""
    @State private var category: OfferCategory = .dining
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(title: appState.t(.addLocation), subtitle: appState.t(.addLocationSub))

                    MarviCard {
                        VStack(alignment: .leading, spacing: 14) {
                            MarviTextField(placeholder: appState.t(.venueNamePh), text: $name)
                            MarviTextField(placeholder: appState.t(.areaPh), text: $area)
                            MarviTextField(placeholder: appState.t(.addressOptional), text: $address)
                            MarviTextField(placeholder: appState.t(.contactPhoneOptional), text: $contactPhone)

                            Text(appState.t(.locationTypeLabel))
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(MarviColor.muted)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(OfferCategory.allCases) { item in
                                        Button { category = item } label: {
                                            Label(item.label(for: appState.preferredLanguage), systemImage: item.icon)
                                                .font(.caption.weight(.bold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .foregroundStyle(category == item ? .white : MarviColor.ink)
                                                .background(
                                                    category == item
                                                        ? AnyShapeStyle(MarviGradient.brand)
                                                        : AnyShapeStyle(MarviColor.panelElevated)
                                                )
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    PrimaryActionButton(
                        title: isSubmitting ? appState.t(.submitting) : appState.t(.addLocation),
                        systemImage: "building.2.fill",
                        isDisabled: !canSubmit || isSubmitting
                    ) {
                        Task {
                            isSubmitting = true
                            let success = await appState.registerVenue(
                                name: name,
                                area: area,
                                category: category,
                                address: address,
                                contactPhone: contactPhone
                            )
                            isSubmitting = false
                            if success { dismiss() }
                        }
                    }
                }
                .padding(16)
            }
            .background(MarviColor.surface.ignoresSafeArea())
            .navigationTitle(appState.t(.addLocation))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.close)) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !area.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct VenuePendingConfirmationsCard: View {
    @EnvironmentObject private var appState: AppState
    let bookings: [Booking]
    @State private var confirmingID: UUID?

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: appState.t(.pendingVenueConfirm),
                    subtitle: appState.t(.pendingVenueConfirmSub)
                )
                ForEach(bookings) { booking in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(booking.offer.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                        Text(booking.guestName.isEmpty ? booking.offer.venue : booking.guestName)
                            .font(.caption)
                            .foregroundStyle(MarviColor.muted)
                        Button {
                            Task {
                                confirmingID = booking.id
                                _ = await appState.venueConfirmBooking(booking)
                                confirmingID = nil
                            }
                        } label: {
                            Label(
                                confirmingID == booking.id ? appState.t(.saving) : appState.t(.confirmCollaboration),
                                systemImage: "checkmark.circle.fill"
                            )
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .background(MarviColor.emerald)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .disabled(confirmingID != nil)

                        Button {
                            Task {
                                confirmingID = booking.id
                                _ = await appState.cancelBooking(booking)
                                confirmingID = nil
                            }
                        } label: {
                            Text(appState.t(.decline))
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MarviColor.tomato)
                        .background(MarviColor.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .disabled(confirmingID != nil)
                    }
                }
            }
        }
    }
}
