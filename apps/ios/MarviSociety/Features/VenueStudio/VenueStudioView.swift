import SwiftUI

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

private enum VenueStudioTab: CaseIterable, Identifiable {
    case establishments, brands

    var id: Self { self }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .establishments: MarviL10n.t(.tabEstablishments, language: language)
        case .brands: MarviL10n.t(.tabBrands, language: language)
        }
    }
}

struct VenueStudioView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingBuilder = false
    @State private var isShowingSwipe = false
    @State private var isShowingAddVenue = false
    @State private var reviewSegment: VenueReviewSegment = .checkedIn
    @State private var studioTab: VenueStudioTab = .establishments
    @State private var isShowingInbox = false

    private var firstName: String {
        appState.profile.displayName
    }

    private var liveCampaignForActiveVenue: Campaign? {
        guard let active = appState.activeVenue else {
            return appState.campaigns.first(where: { $0.status == .live })
        }
        return appState.campaigns.first(where: {
            $0.status == .live && $0.venueName == active.venueName && $0.area == active.area
        }) ?? appState.campaigns.first(where: { $0.status == .live })
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
                            subtitle: appState.t(.venuePartnerWorkspace),
                            onProfile: { appState.navigate(to: .profile) },
                            onNotifications: { isShowingInbox = true }
                        )
                        .padding(.top, 4)

                        if !appState.venuePendingConfirmations.isEmpty {
                            VenuePendingConfirmationsCard(bookings: appState.venuePendingConfirmations)
                        }

                        VenueLocationsCard(
                            venues: appState.myVenues,
                            onSelect: { venue in
                                Task { _ = await appState.switchActiveVenue(to: venue.id) }
                            },
                            onAdd: { isShowingAddVenue = true }
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text(appState.t(.manageEvents))
                                .font(.system(size: 30, weight: .bold, design: .serif))
                                .foregroundStyle(MarviColor.ink)

                            Text(appState.t(.atEstablishments))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(MarviGradient.brand)
                        }

                        if let task = liveCampaignForActiveVenue {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(appState.t(.liveCampaign))
                                        .font(.caption.weight(.bold))
                                        .textCase(.uppercase)
                                        .foregroundStyle(MarviColor.muted)

                                    Text(task.title)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(MarviColor.ink)

                                    Text(String(format: appState.t(.creatorSlotsVenue), task.venueName, task.slots))
                                        .font(.caption)
                                        .foregroundStyle(MarviColor.muted)

                                    GradientCTA(title: appState.t(.reviewCreators), action: { isShowingSwipe = true })
                                }
                            }
                        }

                        StudioStatusGrid(
                            onCreate: { isShowingBuilder = true },
                            onSwipe: { isShowingSwipe = true }
                        )

                        SSSegmentedTabs(
                            options: VenueStudioTab.allCases,
                            title: { $0.title(for: appState.preferredLanguage) },
                            selection: $studioTab
                        )

                        if studioTab == .establishments {
                            SectionTitle(
                                title: appState.t(.campaigns),
                                subtitle: String(format: appState.t(.campaignsSub), appState.campaigns.count)
                            )

                            ForEach(appState.campaigns) { campaign in
                                CampaignCard(campaign: campaign)
                            }
                        } else {
                            SectionTitle(
                                title: appState.t(.brandPartners),
                                subtitle: appState.t(.brandPartnersSub)
                            )

                            if appState.campaigns.isEmpty {
                                MarviCard {
                                    EmptyStateView(
                                        title: appState.t(.noBrandCampaigns),
                                        subtitle: appState.t(.noBrandCampaignsSub),
                                        icon: "tag",
                                        actionTitle: appState.t(.refresh),
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
                                        title: appState.t(.toReview),
                                        subtitle: appState.t(.toReviewVenueSub)
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
                                    title: { $0.title(for: appState.preferredLanguage) },
                                    selection: $reviewSegment
                                )

                                if filteredReviewQueue.isEmpty {
                                    EmptyStateView(
                                        title: appState.t(.noReviewsTab),
                                        subtitle: appState.t(.noReviewsTabSub),
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
            .sheet(isPresented: $isShowingAddVenue) {
                AddVenueSheet()
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
                                Button(appState.t(.done)) { isShowingInbox = false }
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
    @State private var selectedProfileCandidate: InfluencerCandidate?

    private var liveOfferID: UUID? {
        guard let active = appState.activeVenue else {
            return appState.campaigns.first(where: { $0.status == .live })?.id
        }
        return appState.campaigns.first(where: {
            $0.status == .live && $0.venueName == active.venueName && $0.area == active.area
        })?.id ?? appState.campaigns.first(where: { $0.status == .live })?.id
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
                        Text(appState.campaigns.first?.title ?? appState.t(.creatorMatching))
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

                if isLoading {
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
                        }

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

private struct CreatorPublicProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let creatorID: UUID
    let fallbackName: String

    @State private var publicProfile: PublicCreatorProfile?
    @State private var isLoading = true
    @State private var isTogglingFollow = false

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if isLoading {
                            VStack(spacing: 14) {
                                ProgressView().tint(MarviColor.rose)
                                Text(appState.t(.loadingProfile))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MarviColor.muted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else if let publicProfile {
                            PublicCreatorHero(
                                publicProfile: publicProfile,
                                fallbackName: fallbackName,
                                isTogglingFollow: isTogglingFollow,
                                onToggleFollow: toggleFollow
                            )

                            MarviCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionTitle(
                                        title: appState.t(.collaborationsLabel),
                                        subtitle: appState.t(.collaborationHistorySub)
                                    )

                                    if publicProfile.collaborations.isEmpty {
                                        Text(appState.t(.noCollaborationsYet))
                                            .font(.subheadline)
                                            .foregroundStyle(MarviColor.muted)
                                    } else {
                                        ForEach(publicProfile.collaborations) { item in
                                            HStack(spacing: 10) {
                                                Image(systemName: item.category.icon)
                                                    .foregroundStyle(item.category.tint)
                                                    .frame(width: 32, height: 32)
                                                    .background(item.category.tint.opacity(0.14))
                                                    .clipShape(Circle())

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.venueName)
                                                        .font(.subheadline.weight(.bold))
                                                        .foregroundStyle(MarviColor.ink)
                                                    Text([item.area, item.category.rawValue].filter { !$0.isEmpty }.joined(separator: " · "))
                                                        .font(.caption)
                                                        .foregroundStyle(MarviColor.muted)
                                                }
                                                Spacer()
                                            }
                                            .padding(10)
                                            .background(MarviColor.panelElevated)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }
                                    }
                                }
                            }

                            MarviCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionTitle(
                                        title: appState.t(.reviewsFromVenues),
                                        subtitle: appState.t(.venueRatedYou)
                                    )

                                    if publicProfile.reviewsReceived.isEmpty {
                                        Text(appState.t(.noPublicReviews))
                                            .font(.subheadline)
                                            .foregroundStyle(MarviColor.muted)
                                    } else {
                                        ForEach(publicProfile.reviewsReceived) { review in
                                            PublicCreatorReviewRow(review: review)
                                        }
                                    }
                                }
                            }
                        } else {
                            EmptyStateView(
                                title: appState.t(.errProfileNotReady),
                                subtitle: fallbackName,
                                icon: "person.crop.circle.badge.exclamationmark"
                            )
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(appState.t(.publicCreatorProfile))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.done)) { dismiss() }
                        .foregroundStyle(MarviColor.rose)
                }
            }
        }
        .presentationDetents([.large])
        .task { await loadProfile() }
    }

    private func loadProfile() async {
        isLoading = true
        publicProfile = await appState.loadCreatorPublicProfile(creatorID: creatorID)
        isLoading = false
    }

    private func toggleFollow() {
        guard let publicProfile, !isTogglingFollow else { return }
        Task {
            isTogglingFollow = true
            self.publicProfile = await appState.toggleFollow(profile: publicProfile)
            isTogglingFollow = false
        }
    }
}

private struct PublicCreatorHero: View {
    @EnvironmentObject private var appState: AppState
    let publicProfile: PublicCreatorProfile
    let fallbackName: String
    let isTogglingFollow: Bool
    let onToggleFollow: () -> Void

    private var displayName: String {
        publicProfile.profile.name.isEmpty ? fallbackName : publicProfile.profile.name
    }

    private var cleanHandle: String {
        publicProfile.profile.handle.replacingOccurrences(of: "@", with: "")
    }

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        MarviGradient.brandVertical
                        Text(String(displayName.prefix(1)).uppercased())
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 6) {
                        Text(displayName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                        if !cleanHandle.isEmpty {
                            Text("@\(cleanHandle)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MarviColor.rose)
                        }
                        Text(publicProfile.profile.city)
                            .font(.caption)
                            .foregroundStyle(MarviColor.muted)
                    }

                    Spacer()

                    StatusPill(text: "\(publicProfile.profile.score)", tint: MarviColor.gold, systemImage: "star.fill")
                }

                if !publicProfile.profile.bio.isEmpty {
                    Text(publicProfile.profile.bio)
                        .font(.subheadline)
                        .foregroundStyle(MarviColor.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    PublicCreatorMetric(value: "\(publicProfile.followers)", label: appState.t(.followers), icon: "person.2.fill", tint: MarviColor.rose)
                    PublicCreatorMetric(value: "\(publicProfile.following)", label: appState.t(.followingLabel), icon: "person.badge.plus", tint: MarviColor.aubergine)
                }

                if !publicProfile.profile.niches.isEmpty {
                    FlowTagRow(tags: publicProfile.profile.niches)
                }

                Button(action: onToggleFollow) {
                    HStack {
                        if isTogglingFollow {
                            ProgressView().tint(.white)
                        }
                        Text(publicProfile.isFollowing ? appState.t(.unfollowCreator) : appState.t(.followCreator))
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background {
                        if publicProfile.isFollowing {
                            MarviColor.aubergine
                        } else {
                            MarviGradient.brand
                        }
                    }
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isTogglingFollow)
            }
        }
    }
}

private struct PublicCreatorMetric: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(MarviColor.ink)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MarviColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(MarviColor.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct FlowTagRow: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MarviColor.rose)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MarviColor.rose.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private struct PublicCreatorReviewRow: View {
    let review: PublicCreatorReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(review.venueName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MarviColor.ink)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(MarviColor.gold)
                    Text(String(format: "%.1f", review.averageRating))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                }
            }

            if !review.comment.isEmpty {
                Text("“\(review.comment)”")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(MarviColor.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !review.dateLabel.isEmpty {
                Text(review.dateLabel)
                    .font(.caption2)
                    .foregroundStyle(MarviColor.muted)
            }
        }
        .padding(12)
        .background(MarviColor.panelElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    SectionTitle(title: appState.t(.newCampaign), subtitle: appState.t(.newCampaignSub))

                    MarviCard {
                        VStack(alignment: .leading, spacing: 14) {
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
                            MarviTextField(placeholder: appState.t(.valuePh), text: $valueLabel)
                            MarviTextField(placeholder: appState.t(.deliverablesPh), text: $deliverablesText)

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

                    PrimaryActionButton(
                        title: isSubmitting ? appState.t(.submitting) : appState.t(.sendToAdminReview),
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
            .navigationTitle(appState.t(.createNav))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.close)) { dismiss() }
                }
            }
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

private struct VenueLocationsCard: View {
    @EnvironmentObject private var appState: AppState
    let venues: [VenueSummary]
    let onSelect: (VenueSummary) -> Void
    let onAdd: () -> Void

    var body: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: appState.t(.myLocations), subtitle: appState.t(.myLocationsSub))

                if venues.isEmpty {
                    EmptyStateView(
                        title: appState.t(.addLocation),
                        subtitle: appState.t(.addLocationSub),
                        icon: "building.2.crop.circle",
                        actionTitle: appState.t(.addLocation),
                        action: onAdd
                    )
                } else {
                    Text(appState.t(.selectLocation))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MarviColor.muted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(venues) { venue in
                                Button { onSelect(venue) } label: {
                                    VenueLocationChip(venue: venue)
                                }
                                .buttonStyle(.plain)
                            }

                            Button(action: onAdd) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                    Text(appState.t(.addLocation))
                                        .font(.caption.weight(.bold))
                                }
                                .foregroundStyle(MarviColor.rose)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(MarviColor.panelElevated)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct VenueLocationChip: View {
    @EnvironmentObject private var appState: AppState
    let venue: VenueSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: venue.category.icon)
                    .font(.caption.weight(.bold))
                Text(venue.venueName)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }
            Text(venue.area)
                .font(.caption2)
                .foregroundStyle(MarviColor.muted)
                .lineLimit(1)

            if venue.status == .underReview {
                Text(appState.t(.locationPendingReview))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MarviColor.gold)
            }
        }
        .foregroundStyle(venue.isActive ? Color.white : MarviColor.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            venue.isActive
                ? AnyShapeStyle(MarviGradient.brand)
                : AnyShapeStyle(MarviColor.panelElevated)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if venue.isActive {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            }
        }
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
                    }
                }
            }
        }
    }
}
