import SwiftUI

struct CommunityView: View {
    @EnvironmentObject private var appState: AppState
    @State private var section: CommunitySection = .feed
    @State private var searchText = ""
    @State private var selectedMember: MemberSearchResult?
    @State private var selectedActivityCreatorID: UUID?
    @State private var selectedActivityVenueID: UUID?
    @State private var selectedDirectThread: DirectThread?
    @State private var selectedConversation: ChatConversation?

    var body: some View {
        NavigationStack {
            MarviScreen {
                VStack(spacing: 0) {
                    Picker("", selection: $section) {
                        Text(appState.t(.communitySegmentFeed)).tag(CommunitySection.feed)
                        Text(appState.t(.communitySegmentMembers)).tag(CommunitySection.members)
                        Text(appState.t(.communitySegmentMessages)).tag(CommunitySection.messages)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            switch section {
                            case .feed:
                                activityFeedSection
                            case .members:
                                membersSection
                            case .messages:
                                messagesSection
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle(appState.t(.communityTab))
            .searchable(
                text: $searchText,
                isPresented: Binding(
                    get: { section == .members },
                    set: { _ in }
                ),
                prompt: appState.t(.communitySearchPrompt)
            )
            .onSubmit(of: .search) {
                guard section == .members else { return }
                Task { await appState.searchMembers(query: searchText) }
            }
            .refreshable {
                await refreshCurrentSection()
            }
            .task {
                await refreshCurrentSection()
            }
            .onChange(of: section) { _, newSection in
                if newSection != .members {
                    searchText = ""
                }
                Task { await refreshCurrentSection() }
            }
            .sheet(item: $selectedMember) { member in
                if member.isVenue {
                    VenuePublicProfileView(venueID: member.id, fallbackName: member.displayName)
                        .environmentObject(appState)
                } else {
                    CreatorPublicProfileView(creatorID: member.id, fallbackName: member.displayName)
                        .environmentObject(appState)
                }
            }
            .sheet(isPresented: Binding(
                get: { selectedActivityCreatorID != nil },
                set: { if !$0 { selectedActivityCreatorID = nil } }
            )) {
                if let creatorID = selectedActivityCreatorID {
                    CreatorPublicProfileView(creatorID: creatorID, fallbackName: appState.t(.publicCreatorProfile))
                        .environmentObject(appState)
                }
            }
            .sheet(isPresented: Binding(
                get: { selectedActivityVenueID != nil },
                set: { if !$0 { selectedActivityVenueID = nil } }
            )) {
                if let venueID = selectedActivityVenueID {
                    VenuePublicProfileView(venueID: venueID, fallbackName: appState.t(.venuePublicProfile))
                        .environmentObject(appState)
                }
            }
            .sheet(item: $selectedDirectThread) { thread in
                DirectChatThreadView(thread: thread)
                    .environmentObject(appState)
            }
            .sheet(item: $selectedConversation) { conversation in
                ChatThreadView(conversation: conversation)
                    .environmentObject(appState)
            }
        }
    }

    private func refreshCurrentSection() async {
        switch section {
        case .feed:
            await appState.loadFollowingActivity()
        case .members:
            await appState.searchMembers(query: searchText)
        case .messages:
            await appState.loadDirectThreads()
            await appState.loadConversations()
        }
    }

    private var activityFeedSection: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: appState.t(.communityFeedTitle),
                    subtitle: appState.t(.communityFeedSub)
                )

                if appState.isLoadingFollowingActivity {
                    HStack {
                        Spacer()
                        ProgressView().tint(MarviColor.rose)
                        Spacer()
                    }
                    .padding(.vertical, 28)
                } else if let feedError = appState.followingActivityError {
                    EmptyStateView(
                        title: appState.t(.syncErrorTitle),
                        subtitle: feedError,
                        icon: "exclamationmark.triangle",
                        actionTitle: appState.t(.refresh),
                        action: { Task { await appState.loadFollowingActivity() } }
                    )
                } else if appState.followingActivity.isEmpty {
                    EmptyStateView(
                        title: appState.t(.communityFeedEmpty),
                        subtitle: appState.preferredLanguage == .turkish
                            ? "Creator takip ettiğinde check-in ve vitrin paylaşımları burada görünür."
                            : "Follow creators to see their check-ins and showcase posts here.",
                        icon: "person.2",
                        actionTitle: appState.t(.refresh),
                        action: { Task { await appState.loadFollowingActivity() } }
                    )
                } else {
                    ForEach(appState.followingActivity) { item in
                        Button {
                            if let venueID = item.actorVenueID {
                                selectedActivityVenueID = venueID
                            } else if let creatorID = item.actorCreatorID {
                                selectedActivityCreatorID = creatorID
                            }
                        } label: {
                            MemberActivityRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .disabled(item.actorCreatorID == nil && item.actorVenueID == nil)
                    }
                }
            }
        }
    }

    private var membersSection: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: appState.t(.communityMembersTitle),
                    subtitle: appState.t(.communityMembersSub)
                )

                if appState.memberSearchResults.isEmpty {
                    EmptyStateView(
                        title: appState.t(.communityMembersEmpty),
                        subtitle: appState.t(.communityMembersEmptySub),
                        icon: "person.2",
                        actionTitle: appState.t(.refresh),
                        action: { Task { await appState.searchMembers(query: searchText) } }
                    )
                } else {
                    ForEach(appState.memberSearchResults) { member in
                        MemberSearchRow(
                            member: member,
                            onOpenProfile: { selectedMember = member },
                            onToggleFollow: {
                                Task { _ = await appState.toggleFollowMember(member) }
                            }
                        )
                    }
                }
            }
        }
    }

    private var communityInboxItems: [CommunityInboxItem] {
        let directs = appState.directThreads.map(CommunityInboxItem.direct)
        let collabs = appState.conversations.map(CommunityInboxItem.collab)
        return (directs + collabs).sorted { $0.sortDate > $1.sortDate }
    }

    private var messagesSection: some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(
                    title: appState.t(.communitySegmentMessages),
                    subtitle: appState.t(.communityMessagesSub)
                )

                if communityInboxItems.isEmpty {
                    EmptyStateView(
                        title: appState.t(.noMessagesYet),
                        subtitle: appState.t(.communityMessagesSub),
                        icon: "bubble.left.and.bubble.right",
                        actionTitle: appState.t(.refresh),
                        action: { Task { await refreshCurrentSection() } }
                    )
                } else {
                    ForEach(Array(communityInboxItems.enumerated()), id: \.element.id) { index, item in
                        Button {
                            switch item {
                            case .direct(let thread):
                                selectedDirectThread = thread
                            case .collab(let conversation):
                                selectedConversation = conversation
                            }
                        } label: {
                            CommunityInboxRow(item: item)
                        }
                        .buttonStyle(.plain)

                        if index < communityInboxItems.count - 1 {
                            Divider()
                                .overlay(MarviColor.panelElevated)
                        }
                    }
                }
            }
        }
    }
}

private enum CommunityInboxItem: Identifiable {
    case direct(DirectThread)
    case collab(ChatConversation)

    var id: String {
        switch self {
        case .direct(let thread):
            return "direct-\(thread.id.uuidString)"
        case .collab(let conversation):
            return "collab-\(conversation.id.uuidString)"
        }
    }

    var sortDate: Date {
        switch self {
        case .direct(let thread):
            return thread.lastMessageAt ?? .distantPast
        case .collab(let conversation):
            return conversation.lastMessageAt ?? .distantPast
        }
    }
}

private struct CommunityInboxRow: View {
    @EnvironmentObject private var appState: AppState
    let item: CommunityInboxItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(MarviColor.rose.opacity(0.14))
                Image(systemName: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MarviColor.rose)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MarviColor.ink)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(MarviColor.rose)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MarviColor.rose.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(MarviColor.muted)
                    .lineLimit(2)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MarviColor.muted)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(badge), \(subtitle)")
    }

    private var iconName: String {
        switch item {
        case .direct: return "person.crop.circle"
        case .collab: return "building.2"
        }
    }

    private var title: String {
        switch item {
        case .direct(let thread):
            return thread.peerName
        case .collab(let conversation):
            return conversation.venueName.isEmpty ? conversation.offerTitle : conversation.venueName
        }
    }

    private var subtitle: String {
        switch item {
        case .direct(let thread):
            let handle = thread.peerHandle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !handle.isEmpty {
                let normalized = handle.hasPrefix("@") ? handle : "@\(handle)"
                return "\(normalized) · \(thread.preview)"
            }
            return thread.preview
        case .collab(let conversation):
            if conversation.venueName.isEmpty || conversation.offerTitle.isEmpty {
                return conversation.preview
            }
            if conversation.preview == conversation.offerTitle {
                return conversation.offerTitle
            }
            return "\(conversation.offerTitle) · \(conversation.preview)"
        }
    }

    private var badge: String {
        switch item {
        case .direct:
            return appState.t(.communityDirectChat)
        case .collab:
            return appState.t(.communityCollabChat)
        }
    }
}

private enum CommunitySection: String {
    case feed
    case members
    case messages
}

private struct MemberActivityRow: View {
    @EnvironmentObject private var appState: AppState
    let item: MemberActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.icon)
                .font(.headline)
                .foregroundStyle(MarviColor.rose)
                .frame(width: 36, height: 36)
                .background(MarviColor.rose.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(item.actorName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MarviColor.ink)
                Text(activitySummary)
                    .font(.caption)
                    .foregroundStyle(MarviColor.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                Text(relativeDate(item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(MarviColor.muted)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var activitySummary: String {
        switch item.actionType {
        case "checked_in":
            return appState.tf(.memberCheckedInActivity, item.title, item.subtitle)
        case "showcase_added":
            return appState.tf(.memberShowcaseActivity, item.title)
        case "venue_offer":
            return appState.tf(.memberVenueOfferActivity, item.title, item.subtitle)
        default:
            return item.title
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct MemberSearchRow: View {
    @EnvironmentObject private var appState: AppState
    let member: MemberSearchResult
    let onOpenProfile: () -> Void
    let onToggleFollow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpenProfile) {
                HStack(spacing: 12) {
                    ZStack {
                        if let avatarURL = URL(string: member.avatarURL), !member.avatarURL.isEmpty {
                            AsyncImage(url: avatarURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    MarviGradient.brandVertical
                                }
                            }
                        } else {
                            MarviGradient.brandVertical
                            Text(String(member.displayName.prefix(1)).uppercased())
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.displayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MarviColor.ink)
                        if !member.handleLabel.isEmpty {
                            Text(member.handleLabel)
                                .font(.caption)
                                .foregroundStyle(MarviColor.rose)
                        } else if member.isVenue {
                            InfoBadge(icon: "building.2", text: appState.t(.venueKindLabel))
                        }
                        Text("\(member.city) · \(member.followers) \(appState.t(.followers))")
                            .font(.caption2)
                            .foregroundStyle(MarviColor.muted)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onToggleFollow) {
                Text(member.isFollowing ? appState.t(.unfollowCreator) : appState.t(.followCreator))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(member.isFollowing ? MarviColor.aubergine : .white)
                    .background {
                        if member.isFollowing {
                            MarviColor.aubergine.opacity(0.12)
                        } else {
                            MarviGradient.brand
                        }
                    }
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct CreatorPublicProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let creatorID: UUID
    let fallbackName: String

    @State private var publicProfile: PublicCreatorProfile?
    @State private var showcaseItems: [ShowcaseItem] = []
    @State private var comments: [ProfileComment] = []
    @State private var commentDraft = ""
    @State private var isPostingComment = false
    @State private var isOpeningMessage = false
    @State private var openedThread: DirectThread?
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

                            HStack(spacing: 10) {
                                Button {
                                    Task { await openMessage() }
                                } label: {
                                    Label(appState.t(.sendMessageBtn), systemImage: "paperplane.fill")
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(MarviColor.rose)
                                .background(MarviColor.rose.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .disabled(isOpeningMessage)
                            }

                            profileCommentsSection(for: publicProfile)

                            if !showcaseItems.isEmpty {
                                MarviCard {
                                    VStack(alignment: .leading, spacing: 12) {
                                        SectionTitle(
                                            title: appState.t(.showcaseTitle),
                                            subtitle: appState.t(.showcaseSubtitle)
                                        )
                                        PublicShowcaseGrid(items: showcaseItems)
                                    }
                                }
                            }

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
        .sheet(item: $openedThread) { thread in
            DirectChatThreadView(thread: thread)
                .environmentObject(appState)
        }
    }

    @ViewBuilder
    private func profileCommentsSection(for profile: PublicCreatorProfile) -> some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(
                    title: appState.t(.profileCommentsTitle),
                    subtitle: appState.t(.profileCommentsSub)
                )

                if comments.isEmpty {
                    Text(appState.t(.profileCommentsEmpty))
                        .font(.subheadline)
                        .foregroundStyle(MarviColor.muted)
                } else {
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.authorName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MarviColor.ink)
                            Text(comment.body)
                                .font(.subheadline)
                                .foregroundStyle(MarviColor.graphite)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MarviColor.panelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

                MarviTextField(placeholder: appState.t(.commentPlaceholder), text: $commentDraft)
                Button {
                    Task { await postComment(targetUserID: profile.userID) }
                } label: {
                    Label(appState.t(.postComment), systemImage: "text.bubble")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(MarviGradient.brand)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(isPostingComment || commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func loadProfile() async {
        isLoading = true
        publicProfile = await appState.loadCreatorPublicProfile(creatorID: creatorID)
        if let userID = publicProfile?.userID {
            showcaseItems = await appState.loadUserShowcase(userID: userID)
            comments = await appState.loadProfileComments(targetUserID: userID)
        }
        isLoading = false
    }

    private func openMessage() async {
        guard let userID = publicProfile?.userID else { return }
        isOpeningMessage = true
        openedThread = await appState.openDirectThread(with: userID)
        isOpeningMessage = false
    }

    private func postComment(targetUserID: UUID) async {
        isPostingComment = true
        defer { isPostingComment = false }
        if let error = await appState.postProfileComment(targetUserID: targetUserID, body: commentDraft) {
            _ = error
            return
        }
        commentDraft = ""
        comments = await appState.loadProfileComments(targetUserID: targetUserID)
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
                coverBanner

                HStack(alignment: .top, spacing: 14) {
                    avatarBadge

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

                HStack(spacing: 10) {
                    if let instagramURL = socialURL(platform: "instagram", handle: publicProfile.profile.handle) {
                        Link(destination: instagramURL) {
                            Label(appState.t(.openInstagram), systemImage: "camera")
                                .font(.caption.weight(.bold))
                        }
                    }
                    if let tiktokURL = socialURL(platform: "tiktok", handle: publicProfile.profile.tiktokHandle) {
                        Link(destination: tiktokURL) {
                            Label(appState.t(.openTiktok), systemImage: "music.note")
                                .font(.caption.weight(.bold))
                        }
                    }
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

    @ViewBuilder
    private var coverBanner: some View {
        Group {
            if let coverURL = URL(string: publicProfile.profile.coverURL), !publicProfile.profile.coverURL.isEmpty {
                AsyncImage(url: coverURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        coverPlaceholder
                    }
                }
            } else {
                coverPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var coverPlaceholder: some View {
        LinearGradient(
            colors: [MarviColor.aubergine.opacity(0.55), MarviColor.rose.opacity(0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var avatarBadge: some View {
        ZStack {
            if let avatarURL = URL(string: publicProfile.profile.avatarURL), !publicProfile.profile.avatarURL.isEmpty {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarInitials
                    }
                }
            } else {
                avatarInitials
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .overlay(Circle().stroke(MarviColor.panel, lineWidth: 2))
    }

    private var avatarInitials: some View {
        ZStack {
            MarviGradient.brandVertical
            Text(String(displayName.prefix(1)).uppercased())
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
        }
    }

    private func socialURL(platform: String, handle: String) -> URL? {
        let sanitized = handle.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
        guard !sanitized.isEmpty else { return nil }
        return URL(string: "https://\(platform).com/\(sanitized)")
    }
}

private struct PublicShowcaseGrid: View {
    let items: [ShowcaseItem]

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items.prefix(9)) { item in
                if let url = item.openURL {
                    Link(destination: url) {
                        showcaseTile(item)
                    }
                } else if let thumb = item.thumbnailURL {
                    AsyncImage(url: thumb) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color.gray.opacity(0.2)
                        }
                    }
                    .frame(height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    showcaseTile(item)
                }
            }
        }
    }

    @ViewBuilder
    private func showcaseTile(_ item: ShowcaseItem) -> some View {
        ZStack {
            MarviColor.panelElevated
            Image(systemName: item.mediaType == .link ? "link" : "photo")
                .foregroundStyle(MarviColor.muted)
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

struct VenuePublicProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let venueID: UUID
    let fallbackName: String

    @State private var profile: PublicVenueProfile?
    @State private var comments: [ProfileComment] = []
    @State private var commentDraft = ""
    @State private var isLoading = true
    @State private var isTogglingFollow = false
    @State private var isOpeningMessage = false
    @State private var openedThread: DirectThread?

    var body: some View {
        NavigationStack {
            MarviScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if isLoading {
                            ProgressView(appState.t(.loadingProfile))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                        } else if let profile {
                            MarviCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(profile.venueName)
                                                .font(.title2.weight(.bold))
                                                .foregroundStyle(MarviColor.ink)
                                            Text(profile.area)
                                                .font(.caption)
                                                .foregroundStyle(MarviColor.muted)
                                        }
                                        Spacer()
                                        InfoBadge(icon: "tag", text: profile.category.rawValue)
                                    }

                                    HStack(spacing: 10) {
                                        PublicCreatorMetric(value: "\(profile.followers)", label: appState.t(.followers), icon: "person.2.fill", tint: MarviColor.rose)
                                        PublicCreatorMetric(value: "\(profile.following)", label: appState.t(.followingLabel), icon: "person.badge.plus", tint: MarviColor.aubergine)
                                    }

                                    HStack(spacing: 10) {
                                        Button {
                                            Task { await toggleFollow(profile) }
                                        } label: {
                                            Text(profile.isFollowing ? appState.t(.unfollowCreator) : appState.t(.followCreator))
                                                .font(.subheadline.weight(.bold))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.white)
                                        .background(profile.isFollowing ? AnyShapeStyle(MarviColor.aubergine) : AnyShapeStyle(MarviGradient.brand))
                                        .clipShape(Capsule())
                                        .disabled(isTogglingFollow)

                                        Button {
                                            Task { await openMessage(ownerUserID: profile.ownerUserID) }
                                        } label: {
                                            Image(systemName: "paperplane.fill")
                                                .foregroundStyle(MarviColor.rose)
                                                .padding(12)
                                                .background(MarviColor.rose.opacity(0.12))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            venueCommentsSection(ownerUserID: profile.ownerUserID)

                            if !profile.liveOffers.isEmpty {
                                MarviCard {
                                    VStack(alignment: .leading, spacing: 12) {
                                        SectionTitle(title: appState.t(.venueLiveOffers), subtitle: profile.area)
                                        ForEach(profile.liveOffers) { offer in
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(offer.title).font(.subheadline.weight(.bold))
                                                Text("\(offer.area) · \(offer.remainingSlots) slots")
                                                    .font(.caption)
                                                    .foregroundStyle(MarviColor.muted)
                                            }
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(MarviColor.panelElevated)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                    }
                                }
                            }
                        } else {
                            EmptyStateView(title: appState.t(.errProfileNotReady), subtitle: fallbackName, icon: "building.2")
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(appState.t(.venuePublicProfile))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.done)) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .task { await loadProfile() }
        .sheet(item: $openedThread) { thread in
            DirectChatThreadView(thread: thread).environmentObject(appState)
        }
    }

    @ViewBuilder
    private func venueCommentsSection(ownerUserID: UUID) -> some View {
        MarviCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: appState.t(.profileCommentsTitle), subtitle: appState.t(.profileCommentsSub))
                if comments.isEmpty {
                    Text(appState.t(.profileCommentsEmpty)).font(.subheadline).foregroundStyle(MarviColor.muted)
                } else {
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.authorName).font(.caption.weight(.bold))
                            Text(comment.body).font(.subheadline)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MarviColor.panelElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                MarviTextField(placeholder: appState.t(.commentPlaceholder), text: $commentDraft)
                Button(appState.t(.postComment)) {
                    Task {
                        if await appState.postProfileComment(targetUserID: ownerUserID, body: commentDraft) == nil {
                            commentDraft = ""
                            comments = await appState.loadProfileComments(targetUserID: ownerUserID)
                        }
                    }
                }
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(.white)
                .background(MarviGradient.brand)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func loadProfile() async {
        isLoading = true
        profile = await appState.loadVenuePublicProfile(venueID: venueID)
        if let ownerUserID = profile?.ownerUserID {
            comments = await appState.loadProfileComments(targetUserID: ownerUserID)
        }
        isLoading = false
    }

    private func toggleFollow(_ profile: PublicVenueProfile) async {
        isTogglingFollow = true
        self.profile = await appState.toggleFollowVenue(profile)
        isTogglingFollow = false
    }

    private func openMessage(ownerUserID: UUID) async {
        isOpeningMessage = true
        openedThread = await appState.openDirectThread(with: ownerUserID)
        isOpeningMessage = false
    }
}

struct DirectChatThreadView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let thread: DirectThread

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isSending = false
    @State private var myUserID: UUID?

    var body: some View {
        NavigationStack {
            MarviScreen {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(messages) { message in
                                SocialChatBubble(message: message, isMine: message.senderUserID == myUserID)
                            }
                        }
                        .padding(16)
                    }

                    HStack(spacing: 10) {
                        MarviTextField(placeholder: appState.t(.messagePlaceholder), text: $draft)
                        Button { Task { await send() } } label: {
                            Image(systemName: "paperplane.fill").foregroundStyle(MarviColor.rose)
                        }
                        .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(12)
                    .background(MarviColor.panel)
                }
            }
            .navigationTitle(thread.peerName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(appState.t(.close)) { dismiss() }
                }
            }
            .task {
                myUserID = await appState.resolvedUserID()
                messages = await appState.fetchDirectChatMessages(threadID: thread.id)
            }
        }
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        let text = draft
        draft = ""
        guard await appState.sendDirectChatMessage(threadID: thread.id, body: text) else { return }
        messages = await appState.fetchDirectChatMessages(threadID: thread.id)
    }
}

private struct SocialChatBubble: View {
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            Text(message.body)
                .font(.subheadline)
                .foregroundStyle(isMine ? .white : MarviColor.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    if isMine {
                        MarviGradient.brand
                    } else {
                        MarviColor.panelElevated
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            if !isMine { Spacer(minLength: 40) }
        }
    }
}
