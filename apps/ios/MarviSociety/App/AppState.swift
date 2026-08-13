import SwiftUI
import UIKit

@MainActor
final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding = false {
        didSet { saveSnapshot() }
    }
    @Published var selectedRole: UserRole = .creator {
        didSet { saveSnapshot() }
    }
    /// Resets to the first tab when switching creator / venue / admin workspace.
    @Published var workspaceTabIndex = 0
    @Published var isPresentingAdminConsole = false
    @Published var offers: [Offer] = []
    @Published var savedOfferIDs: Set<UUID> = []
    @Published var bookings: [Booking] = []
    @Published var campaigns: [Campaign] = []
    @Published var adminTasks: [AdminTask] = []
    @Published var adminUsers: [AdminUserSummary] = []
    @Published var adminInviteCodes: [AdminInviteCodeItem] = []
    @Published var lastInviteActionSummary: String?
    @Published var inboxMessages: [InboxMessage] = []
    @Published var profile = CreatorProfile.empty
    @Published var strikes: [Strike] = []
    @Published var pushNotificationsEnabled = true {
        didSet { saveSnapshot() }
    }
    @Published var proofRemindersEnabled = true {
        didSet {
            saveSnapshot()
            if proofRemindersEnabled {
                syncProofReminders()
            } else {
                PushNotificationService.cancelAllProofReminders()
            }
        }
    }
    @Published var autoSaveProofLinks = false {
        didSet { saveSnapshot() }
    }

    @Published var isSyncing = false
    @Published var isBootstrapping = false
    @Published var hasLoadedInitialData = false
    @Published var needsReauthentication = false
    @Published var lastSyncError: String?
    @Published var passwordResetMessage: String?
    @Published var isAuthenticated = false
    @Published var allowedRoles: [UserRole] = [.creator]
    @Published var accountRole: UserRole = .creator
    @Published var accountPausedBySelf = false
    @Published var pendingOfferIDs: Set<UUID> = []
    @Published var venueReviewQueue: [VenueReviewItem] = []
    @Published var myVenues: [VenueSummary] = []
    @Published var processingAdminTaskID: UUID?
    @Published var pendingDeepLink: MarviDeepLink?
    @Published var highlightedBookingID: UUID?
    @Published var pendingOfferNavigation: Offer?
    @Published var pendingInviteCode: String?
    @Published private(set) var accountReferralCode: String?
    @Published var collaborationHistory: [CollaborationEntry] = []
    @Published var followCounts: FollowCounts = .zero
    @Published var showcaseItems: [ShowcaseItem] = []
    @Published var memberSearchResults: [MemberSearchResult] = []
    @Published var followingActivity: [MemberActivityItem] = []
    @Published var isLoadingFollowingActivity = false
    @Published var followingActivityError: String?
    @Published var directThreads: [DirectThread] = []
    @Published var conversations: [ChatConversation] = []
    @Published var adminActivity: [ActivityEventItem] = []
    @Published var isLoadingAdminActivity = false
    @Published var adminActivityError: String?
    @Published var pendingCollaborationRequests: [PendingCollaborationRequest] = []
    @Published var socialVerification: SocialVerificationStatus?
    @Published private(set) var languageManuallySet = false {
        didSet { saveSnapshot() }
    }
    @Published var preferredLanguage: AppLanguage = AppLanguage.inferredFromDevice() {
        didSet { saveSnapshot() }
    }

    private var lastNotifiedInstantOfferID: UUID?
    private var lastLocationUploadAt: Date?
    private var authFlowGeneration = 0

    let locationService = LocationService()
    var isRemoteMode: Bool { APIConfig.isSupabaseConfigured }
    private let api: any MarviAPI
    private let persistence: AppPersistence
    private var isPersistenceReady = false

    init(persistence: AppPersistence = .shared, api: (any MarviAPI)? = nil) {
        self.persistence = persistence
        self.api = api ?? APIConfig.makeAPI()

        if let snapshot = persistence.load() {
            hasCompletedOnboarding = snapshot.hasCompletedOnboarding
            selectedRole = snapshot.selectedRole
            pushNotificationsEnabled = snapshot.pushNotificationsEnabled
            proofRemindersEnabled = snapshot.proofRemindersEnabled
            autoSaveProofLinks = snapshot.autoSaveProofLinks
            languageManuallySet = snapshot.languageManuallySet
            preferredLanguage = snapshot.languageManuallySet
                ? snapshot.preferredLanguage
                : AppLanguage.inferredFromDevice()
        }

        isPersistenceReady = true
        refreshLocation()

        guard isRemoteMode else { return }

        Task { await bootstrapRemoteSession() }

        if hasCompletedOnboarding {
            requestPushPermission()
            syncProofReminders()
        }
    }

    var acceptedOfferIDs: Set<UUID> {
        Set(bookings.filter { $0.stage != .cancelled }.map(\.offer.id))
    }

    var activeBookings: [Booking] {
        bookings.filter { $0.stage != .cancelled && $0.stage != .completed }
    }

    var completedBookings: [Booking] {
        bookings.filter { $0.stage == .completed }
    }

    var pendingInviteBookings: [Booking] {
        bookings.filter { $0.stage == .invited }
    }

    /// Tab badge for My Events — matches Talepler grid (invites + creator collab pending).
    var myEventsTabBadgeCount: Int {
        pendingInviteBookings.count
            + pendingCollaborationRequests.filter(\.isPendingCreator).count
    }

    var interestOffers: [Offer] {
        offers.filter { savedOfferIDs.contains($0.id) && !acceptedOfferIDs.contains($0.id) }
    }

    var activeVenue: VenueSummary? {
        myVenues.first(where: \.isActive) ?? myVenues.first
    }

    var hasMultipleVenues: Bool {
        myVenues.count > 1
    }

    var openAdminTasks: [AdminTask] {
        adminTasks.filter { $0.status == .open }
    }

    /// Invite codes are no longer required for membership (kept for admin tooling only).
    var needsInviteRedemption: Bool { false }

    /// Only paused accounts are blocked. New members can enter and request collaborations immediately.
    var needsAdminApproval: Bool {
        guard isRemoteMode, isAuthenticated, hasCompletedOnboarding else { return false }
        if accountRole == .admin { return false }
        return profile.status == .paused
    }

    /// Soft profile enrichment only — does not block entering the main app.
    var needsSocialHandlesEntry: Bool { false }

    /// Soft profile nudge only — server accept_offer only hard-blocks paused accounts.
    var missingSocialHandlesForAccept: Bool {
        guard isRemoteMode, isAuthenticated else { return false }
        if accountRole == .admin { return false }
        let handle = profile.handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let tiktok = profile.tiktokHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        return handle.isEmpty && tiktok.isEmpty
    }

    /// Soft nudge: Instagram DM verify recommended for trust (profile health), not a hard accept gate.
    var needsSocialVerification: Bool {
        guard isRemoteMode, isAuthenticated, hasCompletedOnboarding else { return false }
        if accountRole == .admin { return false }
        if allowedRoles.contains(.venue), selectedRole == .venue { return false }
        if missingSocialHandlesForAccept { return false }
        return socialVerification?.isVerified != true
    }

    var needsSocialProfileCompletion: Bool {
        missingSocialHandlesForAccept || needsSocialVerification
    }

    /// Whether the signed-in creator may accept live offers (client-side gate; server also enforces).
    var canAcceptOffers: Bool {
        guard isAuthenticated, hasCompletedOnboarding else { return false }
        if accountRole == .admin { return true }
        return !needsAdminApproval
    }

    /// Explains why Accept is disabled (shown under CTAs). Nil when accept is allowed.
    var acceptBlockedReason: String? {
        guard isAuthenticated, hasCompletedOnboarding else { return t(.signInToAccept) }
        if accountRole == .admin { return nil }
        if needsAdminApproval || profile.status == .paused {
            return t(.membershipPaused)
        }
        return nil
    }

    static func inferredSystemLanguage() -> AppLanguage {
        AppLanguage.inferredFromDevice()
    }

    func setPreferredLanguage(_ language: AppLanguage, manual: Bool = false) {
        if manual {
            languageManuallySet = true
        }
        preferredLanguage = language
    }

    private func applyInferredLanguageFromLocation(latitude: Double, longitude: Double) {
        guard !languageManuallySet else { return }
        // Keep Turkish as the default; only reinforce it when GPS is in Turkey.
        if AppLanguage.isCoordinateInTurkey(latitude: latitude, longitude: longitude) {
            preferredLanguage = .turkish
        }
    }

    var backendLabel: String { "Supabase" }

    var userCoordinate: (lat: Double, lng: Double)? {
        guard let coordinate = locationService.coordinate else { return nil }
        return (coordinate.latitude, coordinate.longitude)
    }

    func refreshLocation() {
        locationService.refreshLocation()
    }

    func handleLocationUpdate() {
        if let coordinate = locationService.coordinate {
            applyInferredLanguageFromLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }

        Task { await uploadUserLocationIfNeeded() }

        guard pushNotificationsEnabled, isAuthenticated else { return }
        guard let instant = nearbyOffers(withinKm: 3).first(where: { $0.collaborationModel == .instant }) else {
            return
        }
        guard lastNotifiedInstantOfferID != instant.id else { return }
        lastNotifiedInstantOfferID = instant.id
        PushNotificationService.scheduleInstantOfferNearby(venueName: instant.venue)
        track("instant_offer_nearby", properties: ["offer_id": instant.id.uuidString])
    }

    func registerPushToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        Task {
            try? await api.registerDeviceToken(token, platform: "ios")
        }
    }

    func track(_ name: String, properties: [String: String] = [:]) {
        #if DEBUG
        print("[MarviAnalytics] \(name) \(properties)")
        #endif
        guard isRemoteMode, isAuthenticated else { return }
        Task { try? await api.trackEvent(name, properties: properties) }
    }

    func navigate(to link: MarviDeepLink) {
        switch link {
        case .inbox:
            workspaceTabIndex = inboxTabIndex
        case .profile:
            selectedRole = allowedRoles.contains(.creator) ? .creator : (allowedRoles.first ?? .creator)
            workspaceTabIndex = profileTabIndex
        case .admin:
            Task { await openAdminConsole() }
        case .community:
            switch selectedRole {
            case .creator: workspaceTabIndex = 1
            case .venue: workspaceTabIndex = 1
            case .admin: workspaceTabIndex = inboxTabIndex
            }
        case .venueStudio:
            if allowedRoles.contains(.venue) {
                selectedRole = .venue
                workspaceTabIndex = 0
            } else {
                workspaceTabIndex = inboxTabIndex
            }
        case .bookings:
            if allowedRoles.contains(.creator) {
                selectedRole = .creator
                workspaceTabIndex = 3
            } else if selectedRole == .venue {
                workspaceTabIndex = 0
            } else {
                workspaceTabIndex = inboxTabIndex
            }
        case .offer(let offerID):
            if allowedRoles.contains(.creator) {
                selectedRole = .creator
                workspaceTabIndex = 0
            }
            if let offer = offers.first(where: { $0.id == offerID }) {
                pendingOfferNavigation = offer
            } else {
                Task {
                    await refreshFromServer()
                    if let offer = offers.first(where: { $0.id == offerID }) {
                        pendingOfferNavigation = offer
                    }
                }
            }
        case .booking(let bookingID):
            if allowedRoles.contains(.creator) {
                selectedRole = .creator
                workspaceTabIndex = 3
                highlightedBookingID = bookingID
            } else if selectedRole == .venue {
                workspaceTabIndex = 0
                highlightedBookingID = bookingID
            } else {
                workspaceTabIndex = inboxTabIndex
            }
        }
        pendingDeepLink = nil
    }

    func openInboxMessage(_ message: InboxMessage) {
        // Optimistic: opened items leave the inbox immediately (user request).
        withAnimation(.easeInOut(duration: 0.25)) {
            inboxMessages.removeAll { $0.id == message.id }
        }

        Task {
            if !message.isRead {
                do {
                    try await api.markNotificationRead(message.id)
                } catch {
                    // Put it back if the server reject so the user can retry.
                    await MainActor.run {
                        if !inboxMessages.contains(where: { $0.id == message.id }) {
                            inboxMessages.insert(message, at: 0)
                        }
                        if let presentable = presentableError(error) {
                            lastSyncError = presentable
                        }
                    }
                    return
                }
            }
            await MainActor.run {
                if let link = message.deepLink(for: selectedRole) {
                    navigate(to: link)
                }
                track("inbox_open", properties: ["type": message.notificationType])
            }
        }
    }

    func markAllInboxRead() {
        let snapshot = inboxMessages
        withAnimation(.easeInOut(duration: 0.25)) {
            inboxMessages = []
        }
        Task {
            do {
                try await api.markAllNotificationsRead()
                track("inbox_mark_all_read", properties: ["count": "\(snapshot.count)"])
            } catch {
                // Fallback when mark_all RPC is not applied yet: mark each row.
                var failed = false
                for message in snapshot where !message.isRead {
                    do {
                        try await api.markNotificationRead(message.id)
                    } catch {
                        failed = true
                    }
                }
                if failed {
                    await MainActor.run {
                        inboxMessages = snapshot
                        if let presentable = presentableError(error) {
                            lastSyncError = presentable
                        }
                    }
                } else {
                    track("inbox_mark_all_read", properties: ["count": "\(snapshot.count)", "fallback": "true"])
                }
            }
        }
    }

    var inboxTabIndex: Int {
        switch selectedRole {
        case .creator: 2
        case .venue: 2
        case .admin: 1
        }
    }

    var profileTabIndex: Int {
        switch selectedRole {
        case .creator: 4
        case .venue: 3
        case .admin: 2
        }
    }

    var unreadInboxCount: Int {
        min(inboxMessages.filter { !$0.isRead }.count, 99)
    }

    func nearbyOffers(withinKm: Double = 8) -> [Offer] {
        guard let user = userCoordinate else {
            return offers.filter { $0.collaborationModel == .instant }
        }

        return offers
            .compactMap { offer -> (Offer, Double)? in
                guard let distance = offer.distanceKm(from: user.lat, userLng: user.lng) else { return nil }
                return distance <= withinKm ? (offer, distance) : nil
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    func distanceLabel(for offer: Offer) -> String? {
        guard let user = userCoordinate,
              let km = offer.distanceKm(from: user.lat, userLng: user.lng) else { return nil }
        if km < 1 {
            return String(format: "%.0f m away", km * 1000)
        }
        return String(format: "%.1f km away", km)
    }

    func requestPushPermission() {
        guard pushNotificationsEnabled else { return }
        Task {
            _ = await PushNotificationService.requestAuthorization()
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func handleDeepLinkURL(_ url: URL) {
        guard url.scheme?.lowercased() == "marvisociety" else { return }
        let pathID = url.pathComponents.filter { $0 != "/" }.last
        switch url.host?.lowercased() {
        case "booking":
            if let id = pathID.flatMap(UUID.init(uuidString:)) {
                navigate(to: .booking(id))
            }
        case "offer":
            if let id = pathID.flatMap(UUID.init(uuidString:)) {
                navigate(to: .offer(id))
            }
        case "admin":
            Task { await openAdminConsole() }
        case "profile":
            navigate(to: .profile)
        case "invite":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
               !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pendingInviteCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if isAuthenticated, hasCompletedOnboarding, needsInviteRedemption {
                    return
                }
                if !hasCompletedOnboarding {
                    return
                }
            }
        default:
            navigate(to: .inbox)
        }
    }

    func syncProofReminders() {
        guard proofRemindersEnabled else { return }
        for booking in activeBookings {
            PushNotificationService.scheduleProofReminder(for: booking, enabled: true)
        }
    }

    func dismissSyncError() {
        lastSyncError = nil
    }

    // MARK: - Sync

    func bootstrapRemoteSession() async {
        guard isRemoteMode else { return }
        isBootstrapping = true
        defer { isBootstrapping = false }

        if await api.restoreSession() {
            isAuthenticated = true
            needsReauthentication = false
            try? await api.refreshSession()
            await syncAllowedRoles()
            await refreshFromServer(retryOnUnauthorized: true)
            return
        }

        if hasCompletedOnboarding {
            needsReauthentication = true
            isAuthenticated = false
            lastSyncError = t(.errSessionExpired)
        }
    }

    func refreshFromServer(retryOnUnauthorized: Bool = false) async {
        guard isRemoteMode, isAuthenticated else { return }
        isSyncing = true
        defer { isSyncing = false }

        isAuthenticated = await api.accessToken != nil
        var syncErrors: [String] = []
        var hadRealFailure = false

        func noteFailure(_ label: String, error: Error) {
            if Self.isIgnorableSyncError(error) { return }
            hadRealFailure = true
            syncErrors.append(label)
            if lastSyncError == nil, let message = presentableError(error) {
                lastSyncError = message
            }
        }

        // Profile first — offers filter uses creator city.
        do {
            profile = try await api.fetchProfile()
            hasLoadedInitialData = true
        } catch {
            noteFailure("profile", error: error)
        }

        do {
            offers = try await api.fetchOffers(city: profile.city.lowercased())
        } catch {
            noteFailure("offers", error: error)
        }

        do {
            bookings = try await api.fetchBookings()
        } catch {
            noteFailure("bookings", error: error)
        }

        if let loadedInbox = try? await api.fetchNotifications() {
            inboxMessages = loadedInbox.filter { !$0.isRead }
        }

        do {
            savedOfferIDs = try await api.fetchSavedOfferIDs()
        } catch {
            noteFailure("saved offers", error: error)
        }

        if allowedRoles.contains(.admin) {
            do {
                adminTasks = try await api.fetchAdminTasks()
            } catch {
                noteFailure("admin queue", error: error)
            }
            if let loadedUsers = try? await api.fetchAdminUsers(search: nil, status: nil) {
                adminUsers = loadedUsers
            }
        } else if let loadedTasks = try? await api.fetchAdminTasks() {
            adminTasks = loadedTasks
        }

        if let loadedStrikes = try? await api.fetchStrikes() { strikes = loadedStrikes }

        do {
            collaborationHistory = try await api.fetchMyCollaborationHistory()
        } catch {
            noteFailure("collaboration", error: error)
        }
        if let counts = try? await api.fetchMyFollowCounts() { followCounts = counts }
        do {
            showcaseItems = try await api.fetchMyShowcase()
        } catch {
            noteFailure("showcase", error: error)
        }
        if isAuthenticated, accountRole != .admin {
            if let verification = try? await api.ensureSocialVerificationCode() {
                socialVerification = verification
            }
        }
        if let chats = try? await api.fetchConversations() { conversations = chats }
        if let pending = try? await api.fetchPendingCollaborationRequests() {
            pendingCollaborationRequests = pending
        }

        await syncAllowedRoles()

        if allowedRoles.contains(.venue) {
            do {
                myVenues = try await api.fetchMyVenues()
            } catch {
                noteFailure("venues", error: error)
            }
        }
        do {
            campaigns = try await api.fetchCampaigns()
        } catch {
            noteFailure("campaigns", error: error)
        }
        if allowedRoles.contains(.venue) {
            do {
                venueReviewQueue = try await api.fetchVenueReviewQueue()
            } catch {
                noteFailure("venue reviews", error: error)
            }
        }

        if Task.isCancelled { return }

        if syncErrors.contains("profile"), retryOnUnauthorized {
            do {
                try await api.refreshSession()
                lastSyncError = nil
                await refreshFromServer(retryOnUnauthorized: false)
            } catch {
                if !Self.isIgnorableSyncError(error) {
                    markSessionExpired(message: presentableError(error) ?? t(.errSessionExpired))
                }
            }
            return
        }

        if hadRealFailure {
            lastSyncError = lastSyncError ?? t(.errSomeDataRefresh)
        } else {
            lastSyncError = nil
        }
    }

    private static func isIgnorableSyncError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if case MarviAPIError.cancelled = error { return true }
        let ns = error as NSError
        if ns.domain == MarviAPIError.errorDomain, ns.code == 4 { return true }
        let lower = ns.localizedDescription.lowercased()
        return lower.contains("cancelled") || lower.contains("marviapierror error 4")
    }

    func syncAllowedRoles() async {
        guard isRemoteMode, isAuthenticated else { return }

        do {
            let context = try await api.fetchAccountContext()
            accountRole = context.role
            var workspaces = UserRole.allowedWorkspaces(for: context.role)
            if context.hasVenueProfile, !workspaces.contains(.venue) {
                workspaces.append(.venue)
            }
            allowedRoles = UserRole.sortedWorkspaces(workspaces)
            if !allowedRoles.contains(selectedRole) {
                selectedRole = allowedRoles.first ?? .creator
            }

            if let membership = context.membershipStatus {
                profile.status = membership
            }
            accountReferralCode = context.referralCode
            accountPausedBySelf = context.pausedBySelf
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func signOut() async {
        try? await api.signOut()
        clearServerState()
        needsReauthentication = true
        hasLoadedInitialData = false
        isAuthenticated = false
        allowedRoles = [.creator]
        accountRole = .creator
        selectedRole = .creator
        SessionKeychain.clear()
    }

    /// Leaves the re-auth gate and opens onboarding signup for a new member.
    func beginCreateAccountFlow() {
        authFlowGeneration += 1
        let generation = authFlowGeneration
        needsReauthentication = false
        hasCompletedOnboarding = false
        lastSyncError = nil
        Task {
            try? await api.signOut()
            guard generation == authFlowGeneration else { return }
            clearServerState()
            hasLoadedInitialData = false
            isAuthenticated = false
            allowedRoles = [.creator]
            accountRole = .creator
            selectedRole = .creator
            SessionKeychain.clear()
            needsReauthentication = false
            hasCompletedOnboarding = false
        }
    }

    /// True when the signed-in user already finished onboarding on the server.
    func isExistingMemberOnServer() async -> Bool {
        guard isRemoteMode, isAuthenticated else { return false }

        if let context = try? await api.fetchAccountContext() {
            accountReferralCode = context.referralCode
            if context.role == .admin { return true }
            if context.hasVenueProfile { return true }

            let handle = profile.handle.trimmingCharacters(in: .whitespacesAndNewlines)
            let tiktok = profile.tiktokHandle.trimmingCharacters(in: .whitespacesAndNewlines)
            let city = profile.city.trimmingCharacters(in: .whitespacesAndNewlines)
            if (!handle.isEmpty || !tiktok.isEmpty), !city.isEmpty { return true }
            return false
        }

        return false
    }

    func requestPasswordReset(email: String) async {
        guard isRemoteMode else { return }

        isSyncing = true
        lastSyncError = nil
        passwordResetMessage = nil
        defer { isSyncing = false }

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastSyncError = t(.errEnterEmail)
            return
        }

        do {
            try await api.resetPassword(trimmed)
            passwordResetMessage = t(.passwordResetDefault)
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func dismissPasswordResetMessage() {
        passwordResetMessage = nil
    }

    func pauseAccount() async -> String? {
        guard isRemoteMode, isAuthenticated else {
            return t(.errSignInRequired)
        }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            try await api.pauseOwnAccount()
            accountPausedBySelf = true
            profile.status = .paused
            await refreshFromServer()
            return nil
        } catch {
            let message = presentableError(error) ?? t(.errSomeDataRefresh)
            lastSyncError = message
            return message
        }
    }

    func reactivateAccount() async -> String? {
        guard isRemoteMode, isAuthenticated else {
            return t(.errSignInRequired)
        }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            try await api.reactivateOwnAccount()
            accountPausedBySelf = false
            await refreshFromServer()
            await syncAllowedRoles()
            return nil
        } catch {
            let message = presentableError(error) ?? t(.errSomeDataRefresh)
            lastSyncError = message
            return message
        }
    }

    func deleteAccountPermanently() async -> String? {
        guard isRemoteMode, isAuthenticated else {
            return t(.errSignInRequired)
        }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            try await api.deleteOwnAccountPermanently()
            hasCompletedOnboarding = false
            needsReauthentication = false
            isAuthenticated = false
            clearServerState()
            SessionKeychain.clear()
            persistence.reset()
            return nil
        } catch {
            let message = presentableError(error) ?? t(.errSomeDataRefresh)
            lastSyncError = message
            return message
        }
    }

    static func isAccountAlreadyExistsMessage(_ message: String?) -> Bool {
        guard let message else { return false }
        let lower = message.lowercased()
        return lower.contains("already exists")
            || lower.contains("already registered")
            || lower.contains("already been registered")
            || lower.contains("user already registered")
    }

    func loadVenueSummary() async -> VenueSummary? {
        guard isRemoteMode, isAuthenticated else { return nil }
        do {
            if myVenues.isEmpty {
                myVenues = try await api.fetchMyVenues()
            }
            if let activeVenue {
                return activeVenue
            }
            return try await api.fetchVenueSummary()
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return nil
        }
    }

    func switchActiveVenue(to venueID: UUID) async -> Bool {
        guard isRemoteMode, isAuthenticated else { return false }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await api.setActiveVenue(venueID)
            myVenues = try await api.fetchMyVenues()
            await refreshFromServer()
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func fetchMyBrands() async -> [BrandSummary] {
        guard isRemoteMode, isAuthenticated else { return [] }
        do {
            return try await api.fetchMyBrands()
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return []
        }
    }

    func createOrganizationWithBrand(organizationName: String, brandName: String) async -> BrandSummary? {
        guard isRemoteMode, isAuthenticated else { return nil }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        do {
            let result = try await api.createOrganizationWithBrand(
                organizationName: organizationName,
                brandName: brandName
            )
            return result.asBrandSummary
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return nil
        }
    }

    func createEstablishmentDraft(brandID: UUID, establishmentName: String) async -> UUID? {
        guard isRemoteMode, isAuthenticated else { return nil }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        do {
            let venueID = try await api.createEstablishmentDraft(
                brandID: brandID,
                establishmentName: establishmentName
            )
            myVenues = try await api.fetchMyVenues()
            return venueID
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return nil
        }
    }

    func upsertEstablishmentDetails(venueID: UUID, input: EstablishmentDetailsInput) async -> Bool {
        guard isRemoteMode, isAuthenticated else { return false }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        do {
            try await api.upsertEstablishmentDetails(venueID: venueID, input: input)
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func upsertEstablishmentAddress(venueID: UUID, input: EstablishmentAddressInput) async -> Bool {
        guard isRemoteMode, isAuthenticated else { return false }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        do {
            try await api.upsertEstablishmentAddress(venueID: venueID, input: input)
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func upsertEstablishmentPhotos(venueID: UUID, logoData: Data, galleryData: [Data]) async -> Bool {
        guard isRemoteMode, isAuthenticated else { return false }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        do {
            guard let preparedLogo = ImageUploadPreprocessor.prepare(logoData, profile: .avatar) else {
                throw MarviAPIError.server(message: "Could not process logo image")
            }
            let logoURL = try await api.uploadEstablishmentMedia(
                data: preparedLogo,
                fileName: "logo.jpg",
                venueID: venueID
            )
            var galleryURLs: [String] = []
            for (index, data) in galleryData.enumerated() {
                guard let prepared = ImageUploadPreprocessor.prepare(data, profile: .cover) else {
                    throw MarviAPIError.server(message: "Could not process gallery image")
                }
                let url = try await api.uploadEstablishmentMedia(
                    data: prepared,
                    fileName: "gallery-\(index + 1).jpg",
                    venueID: venueID
                )
                galleryURLs.append(url)
            }
            try await api.upsertEstablishmentPhotos(
                venueID: venueID,
                logoURL: logoURL,
                galleryURLs: galleryURLs
            )
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func submitEstablishmentForReview(venueID: UUID) async -> Bool {
        guard isRemoteMode, isAuthenticated else { return false }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        do {
            try await api.submitEstablishmentForReview(venueID: venueID)
            myVenues = try await api.fetchMyVenues()
            await syncAllowedRoles()
            await refreshFromServer()
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func registerVenue(
        name: String,
        area: String,
        category: OfferCategory,
        categoryLabel: String? = nil,
        address: String = "",
        contactName: String = "",
        contactPhone: String = ""
    ) async -> Bool {
        guard isRemoteMode, isAuthenticated else { return false }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        let trimmedCategoryLabel = categoryLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCategoryLabel = trimmedCategoryLabel?.isEmpty == false
            ? trimmedCategoryLabel ?? category.apiValue
            : category.apiValue
        let input = RegisterVenueInput(
            venueName: name,
            area: area,
            category: category,
            categoryLabel: resolvedCategoryLabel,
            address: address,
            contactName: contactName.isEmpty ? profile.displayName : contactName,
            contactPhone: contactPhone
        )

        do {
            _ = try await api.registerVenueLocation(input)
            myVenues = try await api.fetchMyVenues()
            await syncAllowedRoles()
            await refreshFromServer()
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    @discardableResult
    func saveProfileToServer() async -> Bool {
        guard isRemoteMode, isAuthenticated else { return false }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await api.updateProfile(profile)
            profile = try await api.fetchProfile()
            // Social verification is best-effort; don't fail a successful profile save.
            if let verification = try? await api.ensureSocialVerificationCode() {
                socialVerification = verification
            }
            lastSyncError = nil
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func loadSocialVerification() async {
        guard isRemoteMode, isAuthenticated else { return }
        do {
            socialVerification = try await api.ensureSocialVerificationCode()
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func submitSocialVerificationSent() async -> String? {
        guard isRemoteMode, isAuthenticated else { return t(.errSignInRequired) }

        isSyncing = true
        defer { isSyncing = false }

        do {
            socialVerification = try await api.submitSocialVerificationDM()
            return nil
        } catch {
            let message = presentableError(error) ?? t(.errSomeDataRefresh)
            lastSyncError = message
            return message
        }
    }

    func adminVerifySocialDM(userID: UUID) async -> String? {
        guard isRemoteMode, isAuthenticated else { return t(.errSignInRequired) }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await api.adminVerifySocialDM(userID: userID)
            if allowedRoles.contains(.admin) {
                adminTasks = try await api.fetchAdminTasks()
            }
            return nil
        } catch {
            let message = presentableError(error) ?? t(.errSomeDataRefresh)
            lastSyncError = message
            return message
        }
    }

    func signInWithEmail(_ email: String, password: String, metadata: [String: String]) async {
        guard isRemoteMode else { return }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            try await api.signInWithEmail(email, password: password, metadata: metadata)
            authFlowGeneration += 1
            isAuthenticated = true
            needsReauthentication = false
            await refreshFromServer()
            await syncAllowedRoles()
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func signUpWithEmail(_ email: String, password: String, metadata: [String: String]) async {
        guard isRemoteMode else { return }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            try await api.signUpWithEmail(email, password: password, metadata: metadata)
            authFlowGeneration += 1
            isAuthenticated = true
            needsReauthentication = false
            await refreshFromServer()
            await syncAllowedRoles()
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func signInWithApple(using service: AppleSignInService, metadata: [String: String]) async {
        guard isRemoteMode else { return }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            let tokens = try await service.signIn()
            try await api.signInWithApple(
                idToken: tokens.idToken,
                nonce: tokens.nonce,
                metadata: metadata
            )
            authFlowGeneration += 1
            isAuthenticated = true
            needsReauthentication = false
            await refreshFromServer()
            await syncAllowedRoles()
        } catch MarviAPIError.cancelled {
            // User dismissed Apple sign-in — no error banner.
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func signInWithGoogle(using service: GoogleSignInService, metadata: [String: String]) async {
        guard isRemoteMode else { return }
        guard let supabaseURL = APIConfig.supabaseURL, let anonKey = APIConfig.supabaseAnonKey else {
            lastSyncError = t(.errSignInUnavailable)
            return
        }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            let tokens = try await service.signIn(supabaseURL: supabaseURL, anonKey: anonKey)
            try await api.signInWithGoogle(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                metadata: metadata
            )
            authFlowGeneration += 1
            isAuthenticated = true
            needsReauthentication = false
            await refreshFromServer()
            await syncAllowedRoles()
        } catch MarviAPIError.cancelled {
            // User dismissed Google sign-in — no error banner.
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    // MARK: - Onboarding

    func completeOnboarding(role: UserRole) {
        if !allowedRoles.contains(role) {
            selectedRole = allowedRoles.first ?? .creator
        } else {
            selectedRole = role
        }
        hasCompletedOnboarding = true
        needsReauthentication = false

        Task { await refreshFromServer() }
        requestPushPermission()
        syncProofReminders()
        refreshLocation()
        workspaceTabIndex = 0
    }

    func switchWorkspace(to role: UserRole) {
        guard allowedRoles.contains(role) else { return }
        selectedRole = role
        workspaceTabIndex = 0
    }

    func openAdminConsole() async {
        if isRemoteMode, isAuthenticated {
            await syncAllowedRoles()
        }

        guard allowedRoles.contains(.admin) else {
            lastSyncError = t(.errAdminAccessDisabled)
            return
        }

        selectedRole = .admin
        workspaceTabIndex = 0
        await refreshFromServer()
        isPresentingAdminConsole = true
    }

    // MARK: - Offers

    func isAccepted(_ offer: Offer) -> Bool {
        acceptedOfferIDs.contains(offer.id)
    }

    func isSaved(_ offer: Offer) -> Bool {
        savedOfferIDs.contains(offer.id)
    }

    func isPendingOfferAction(_ offer: Offer) -> Bool {
        pendingOfferIDs.contains(offer.id)
    }

    func toggleSaved(_ offer: Offer) {
        guard isAuthenticated else { return }
        pendingOfferIDs.insert(offer.id)
        Task {
            defer { pendingOfferIDs.remove(offer.id) }
            do {
                let saved = try await api.toggleSavedOffer(offer.id)
                if saved { savedOfferIDs.insert(offer.id) }
                else { savedOfferIDs.remove(offer.id) }
            } catch {
                if let message = presentableError(error) { lastSyncError = message }
            }
        }
    }

    func accept(_ offer: Offer, options: AcceptOfferOptions = AcceptOfferOptions()) {
        guard isAuthenticated, !isAccepted(offer), offer.remaining > 0 else { return }
        if needsAdminApproval {
            lastSyncError = acceptBlockedReason ?? t(.membershipPaused)
            return
        }
        pendingOfferIDs.insert(offer.id)
        Task {
            defer { pendingOfferIDs.remove(offer.id) }
            do {
                let booking = try await api.acceptOffer(offer.id, options: options)
                bookings.insert(booking, at: 0)
                syncProofReminders()
                track("offer_accepted", properties: [
                    "offer_id": offer.id.uuidString,
                    "model": offer.collaborationModel.rawValue
                ])
                await refreshFromServer()
            } catch {
                if let message = presentableError(error) { lastSyncError = message }
            }
        }
    }

    func decline(_ booking: Booking) {
        cancel(booking.offer)
    }

    func loadSwipeCandidates(offerID: UUID? = nil) async -> [InfluencerCandidate] {
        guard isAuthenticated else { return [] }
        do {
            return try await api.fetchSwipeCandidates(offerID: offerID)
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return []
        }
    }

    func shortlistCreator(_ candidate: InfluencerCandidate, offerID: UUID? = nil) async {
        guard isAuthenticated else { return }
        do {
            try await api.shortlistCreator(candidate.id, offerID: offerID)
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func passCreator(_ candidate: InfluencerCandidate, offerID: UUID? = nil) async {
        guard isAuthenticated else { return }
        do {
            try await api.passCreator(candidate.id, offerID: offerID)
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func submitVenueReview(
        bookingID: UUID,
        punctuality: Int,
        presentation: Int,
        comment: String
    ) async -> Bool {
        guard isAuthenticated else { return false }
        do {
            try await api.submitVenueReview(
                bookingID: bookingID,
                punctuality: punctuality,
                presentation: presentation,
                comment: comment
            )
            if allowedRoles.contains(.venue), let reviews = try? await api.fetchVenueReviewQueue() {
                venueReviewQueue = reviews
            }
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func submitCreatorReview(
        bookingID: UUID,
        hospitality: Int,
        experience: Int,
        comment: String
    ) async -> Bool {
        guard isAuthenticated else { return false }
        do {
            try await api.submitCreatorReview(
                bookingID: bookingID,
                hospitality: hospitality,
                experience: experience,
                comment: comment
            )
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func uploadProfilePhoto(data: Data, kind: ProfileImageKind) async -> Bool {
        guard isAuthenticated else { return false }
        let uploadProfile: ImageUploadProfile = kind == .avatar ? .avatar : .cover
        guard let prepared = ImageUploadPreprocessor.prepare(data, profile: uploadProfile) else {
            lastSyncError = t(.errPhotoTooLarge)
            return false
        }
        do {
            let url = try await api.uploadProfileImage(
                data: prepared,
                fileName: "\(kind.rawValue).jpg",
                kind: kind
            )
            // Persist just the image column so the photo can't be wiped by an
            // unrelated field or a post-save refetch that races the write.
            try await api.updateProfileImageURL(url, kind: kind)
            switch kind {
            case .avatar: profile.avatarURL = url
            case .cover: profile.coverURL = url
            }
            lastSyncError = nil
            return true
        } catch MarviAPIError.cancelled {
            // A picker dismissal or a system URLSession cancellation is not a
            // server failure and must never become the global red error banner.
            lastSyncError = nil
            return false
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func issueStrikeForProofTask(_ task: AdminTask, reason: String) {
        guard let bookingID = task.subjectID else {
            lastSyncError = t(.errNoLinkedBooking)
            return
        }
        guard processingAdminTaskID == nil else { return }
        processingAdminTaskID = task.id
        Task {
            defer { processingAdminTaskID = nil }
            do {
                try await api.issueStrikeForBooking(bookingID: bookingID, reason: reason)
                await refreshFromServer()
            } catch {
                if let message = presentableError(error) { lastSyncError = message }
            }
        }
    }

    func cancel(_ offer: Offer) {
        guard isAuthenticated else { return }
        pendingOfferIDs.insert(offer.id)
        Task {
            defer { pendingOfferIDs.remove(offer.id) }
            do {
                try await api.cancelOffer(offer.id)
                await refreshFromServer()
            } catch {
                if let message = presentableError(error) { lastSyncError = message }
            }
        }
    }

    func checkIn(_ booking: Booking, code: String) async -> String? {
        guard isAuthenticated else { return t(.errSignInCheckIn) }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return t(.errEnterCheckInCode) }

        do {
            let updated = try await api.checkIn(bookingID: booking.id, code: normalized)
            updateBooking(updated.id) { $0 = updated }
            return nil
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func validateReferralCode(_ code: String) async -> Bool {
        let normalized = InviteCodeNormalizer.normalize(code)
        guard !normalized.isEmpty else { return false }
        do {
            return try await api.validateReferralCode(normalized)
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func redeemReferralCode(_ code: String) async -> String? {
        let normalized = InviteCodeNormalizer.normalize(code)
        guard !normalized.isEmpty else { return t(.errEnterInviteCode) }
        guard isAuthenticated else { return t(.errSignInRedeemInvite) }
        do {
            try await api.redeemReferralCode(normalized)
            accountReferralCode = normalized
            await syncAllowedRoles()
            return nil
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func sendCreatorInvite(email: String) async -> String? {
        guard isRemoteMode, isAuthenticated else { return t(.errSignInRequired) }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return t(.errEnterEmail) }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            _ = try await api.sendCreatorInvite(email: trimmed)
            return nil
        } catch {
            let message = presentableError(error) ?? t(.errSomeDataRefresh)
            lastSyncError = message
            return message
        }
    }

    func uploadProofScreenshot(for booking: Booking, imageData: Data, fileName: String) async -> String? {
        guard let prepared = ImageUploadPreprocessor.prepare(imageData, profile: .proof) else {
            lastSyncError = t(.errPhotoTooLarge)
            return nil
        }
        do {
            return try await api.uploadProofImage(
                bookingID: booking.id,
                imageData: prepared,
                fileName: fileName
            )
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return nil
        }
    }

    func submitProof(for booking: Booking, links: [String], imageData: Data? = nil, fileName: String = "proof.jpg") async -> String? {
        guard isAuthenticated else { return t(.errSignInSubmitProof) }
        var proofLinks = links
        if let imageData, !imageData.isEmpty {
            if let url = await uploadProofScreenshot(for: booking, imageData: imageData, fileName: fileName) {
                proofLinks.append(url)
            } else if links.isEmpty {
                return lastSyncError ?? t(.errUploadScreenshot)
            }
        }
        guard !proofLinks.isEmpty else { return t(.errAddProofLink) }
        do {
            let updated = try await api.submitProof(bookingID: booking.id, links: proofLinks)
            updateBooking(updated.id) { $0 = updated }
            await refreshFromServer()
            return nil
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func createCampaign(
        title: String,
        venueName: String,
        area: String,
        category: OfferCategory,
        collaborationModel: CollaborationModel = .invitation,
        dateLabel: String,
        valueLabel: String,
        slots: Int,
        deliverables: [String],
        imageData: Data? = nil,
        description: String = "",
        timeLabel: String = "Flexible",
        requirements: [String] = [],
        hostNote: String = ""
    ) async -> Bool {
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            var imageName = ""
            if let imageData {
                var venueID = activeVenue?.id
                if venueID == nil {
                    venueID = try await api.fetchVenueSummary()?.id
                }
                guard let venueID else {
                    throw MarviAPIError.server(message: "No venue profile linked to this account.")
                }
                guard let prepared = ImageUploadPreprocessor.prepare(imageData, profile: .cover) else {
                    throw MarviAPIError.server(message: "Could not process campaign photo")
                }
                imageName = try await api.uploadVenueCampaignImage(
                    data: prepared,
                    fileName: "campaign.jpg",
                    venueID: venueID
                )
            }

            let input = CreateCampaignInput(
                title: title,
                category: category,
                collaborationModel: collaborationModel,
                dateLabel: dateLabel,
                valueLabel: valueLabel,
                slots: slots,
                deliverables: deliverables,
                imageName: imageName,
                description: description,
                timeLabel: timeLabel,
                requirements: requirements,
                hostNote: hostNote
            )

            let campaign = try await api.createCampaign(input, venueID: activeVenue?.id)
            campaigns.insert(campaign, at: 0)
            await refreshFromServer()
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func approveTask(_ task: AdminTask) {
        guard processingAdminTaskID == nil else { return }
        processingAdminTaskID = task.id
        Task {
            defer { processingAdminTaskID = nil }
            do {
                try await api.approveTask(task.id)
                await refreshFromServer()
            } catch {
                if let message = presentableError(error) { lastSyncError = message }
            }
        }
    }

    func rejectTask(_ task: AdminTask) {
        guard processingAdminTaskID == nil else { return }
        processingAdminTaskID = task.id
        Task {
            defer { processingAdminTaskID = nil }
            do {
                try await api.rejectTask(task.id)
                await refreshFromServer()
            } catch {
                if let message = presentableError(error) { lastSyncError = message }
            }
        }
    }


    func adminSetCampaignStatus(_ campaign: Campaign, status: CampaignStatus, reason: String? = nil) {
        guard allowedRoles.contains(.admin) || allowedRoles.contains(.venue) else { return }
        processingAdminTaskID = campaign.id
        Task {
            defer { processingAdminTaskID = nil }
            do {
                try await api.adminSetOfferStatus(offerID: campaign.id, status: status, reason: reason)
                await refreshFromServer()
            } catch {
                if let message = presentableError(error) { lastSyncError = message }
            }
        }
    }

    @discardableResult
    func adminSoftDeleteCampaign(_ campaign: Campaign, reason: String? = nil) async -> Bool {
        guard allowedRoles.contains(.admin) else { return false }
        processingAdminTaskID = campaign.id
        defer { processingAdminTaskID = nil }
        do {
            try await api.adminSoftDeleteOffer(offerID: campaign.id, reason: reason)
            await refreshFromServer()
            lastSyncError = nil
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    @discardableResult
    func venueSoftDeleteCampaign(_ campaign: Campaign, reason: String? = nil) async -> Bool {
        guard allowedRoles.contains(.venue) || allowedRoles.contains(.admin) else { return false }
        processingAdminTaskID = campaign.id
        defer { processingAdminTaskID = nil }
        do {
            try await api.venueSoftDeleteOffer(offerID: campaign.id, reason: reason)
            // Optimistic remove so Studio updates immediately.
            campaigns.removeAll { $0.id == campaign.id }
            await refreshFromServer()
            lastSyncError = nil
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    @discardableResult
    func adminRestoreCampaign(_ campaign: Campaign) async -> Bool {
        guard allowedRoles.contains(.admin) else { return false }
        processingAdminTaskID = campaign.id
        defer { processingAdminTaskID = nil }
        do {
            try await api.adminRestoreOffer(offerID: campaign.id)
            await refreshFromServer()
            lastSyncError = nil
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func loadAdminUsers(search: String = "", status: String? = nil) async {
        guard isRemoteMode, isAuthenticated, allowedRoles.contains(.admin) else { return }
        do {
            adminUsers = try await api.fetchAdminUsers(
                search: search.isEmpty ? nil : search,
                status: status
            )
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func loadAdminUserDetail(userID: UUID) async -> AdminUserDetail? {
        guard isRemoteMode, isAuthenticated, allowedRoles.contains(.admin) else { return nil }
        do {
            return try await api.fetchAdminUserDetail(userID: userID)
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return nil
        }
    }

    func adminSetUserStatus(userID: UUID, status: MembershipStatus) async -> String? {
        guard isRemoteMode, allowedRoles.contains(.admin) else {
            return t(.errAdminRequired)
        }
        do {
            try await api.adminSetMembershipStatus(userID: userID, status: status.apiValue)
            await loadAdminUsers()
            return nil
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func adminSetUserRole(userID: UUID, role: UserRole) async -> String? {
        guard isRemoteMode, allowedRoles.contains(.admin) else {
            return t(.errAdminRequired)
        }
        do {
            try await api.adminSetUserRole(userID: userID, role: role.apiValue)
            await loadAdminUsers()
            return nil
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func adminSendUserNotification(userID: UUID, title: String, body: String) async -> String? {
        guard isRemoteMode, allowedRoles.contains(.admin) else {
            return t(.errAdminRequired)
        }
        do {
            try await api.adminSendNotification(userID: userID, title: title, body: body)
            return nil
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func adminSendUserEmail(userID: UUID, subject: String, body: String) async -> String? {
        guard isRemoteMode, allowedRoles.contains(.admin) else {
            return t(.errAdminRequired)
        }
        do {
            try await api.adminSendEmail(userID: userID, subject: subject, body: body)
            return nil
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func adminUploadUserPhoto(userID: UUID, data: Data, kind: ProfileImageKind) async -> String? {
        guard isRemoteMode, allowedRoles.contains(.admin) else {
            return t(.errAdminRequired)
        }
        let uploadProfile: ImageUploadProfile = kind == .avatar ? .avatar : .cover
        guard let prepared = ImageUploadPreprocessor.prepare(data, profile: uploadProfile) else {
            return t(.errPhotoTooLarge)
        }
        do {
            let url = try await api.uploadProfileImage(
                data: prepared,
                fileName: "\(kind.rawValue).jpg",
                kind: kind,
                forUserID: userID
            )
            try await api.adminSetUserProfileImage(userID: userID, kind: kind, url: url)
            await loadAdminUsers()
            return nil
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func adminClearUserPhoto(userID: UUID, kind: ProfileImageKind) async -> String? {
        guard isRemoteMode, allowedRoles.contains(.admin) else {
            return t(.errAdminRequired)
        }
        do {
            try await api.adminSetUserProfileImage(userID: userID, kind: kind, url: nil)
            await loadAdminUsers()
            return nil
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func loadAdminInviteCodes() async {
        guard isRemoteMode, isAuthenticated, allowedRoles.contains(.admin) else { return }
        do {
            adminInviteCodes = try await api.fetchAdminInviteCodes()
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func adminCreateInviteCode(
        code: String?,
        ownerType: String,
        maxUses: Int,
        inviteEmail: String? = nil
    ) async -> String? {
        guard isRemoteMode, allowedRoles.contains(.admin) else {
            return t(.errAdminRequired)
        }
        do {
            let item = try await api.adminCreateInviteCode(
                code: code,
                ownerType: ownerType,
                maxUses: maxUses,
                inviteEmail: inviteEmail
            )
            if let index = adminInviteCodes.firstIndex(where: { $0.id == item.id }) {
                adminInviteCodes[index] = item
            } else {
                adminInviteCodes.insert(item, at: 0)
            }
            await loadAdminInviteCodes()
            if let email = item.inviteEmail, !email.isEmpty {
                lastInviteActionSummary = "\(item.code) → \(email)"
            } else {
                lastInviteActionSummary = item.code
            }
            return nil
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func adminUpdateInviteCodeQuota(code: String, maxUses: Int) async -> String? {
        guard isRemoteMode, allowedRoles.contains(.admin) else {
            return t(.errAdminRequired)
        }
        do {
            try await api.adminUpdateInviteCodeQuota(code: code, maxUses: maxUses)
            await loadAdminInviteCodes()
            return nil
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func adminSendInviteEmail(email: String, inviteCode: String?, maxUses: Int = 1) async -> String? {
        guard isRemoteMode, allowedRoles.contains(.admin) else {
            return t(.errAdminRequired)
        }
        do {
            let result = try await api.adminSendInvite(email: email, inviteCode: inviteCode, maxUses: maxUses)
            await loadAdminInviteCodes()
            lastInviteActionSummary = "\(result.inviteCode) → \(result.email)"
            return nil
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func adminCreateUserAccount(
        email: String,
        password: String?,
        fullName: String,
        city: String,
        autoApprove: Bool = true
    ) async -> (result: AdminProvisionResult?, error: String?) {
        guard isRemoteMode, allowedRoles.contains(.admin) else {
            return (nil, t(.errAdminRequired))
        }
        do {
            let result = try await api.adminCreateUser(
                email: email,
                password: password,
                fullName: fullName,
                city: city,
                autoApprove: autoApprove
            )
            await loadAdminUsers()
            return (result, nil)
        } catch {
            return (nil, presentableError(error) ?? t(.errSomeDataRefresh))
        }
    }

    func adminBroadcastInRadius(
        lat: Double,
        lng: Double,
        radiusKm: Double,
        title: String,
        body: String
    ) async -> String? {
        guard isRemoteMode, allowedRoles.contains(.admin) else {
            return t(.errAdminRequired)
        }
        do {
            let count = try await api.adminNotifyUsersInRadius(
                lat: lat,
                lng: lng,
                radiusKm: radiusKm,
                title: title,
                body: body
            )
            if count == 0 {
                return t(.errNoUsersInArea)
            }
            return tf(.errSentToUsers, count, Int(radiusKm))
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    private func uploadUserLocationIfNeeded() async {
        guard isRemoteMode, isAuthenticated, let coordinate = userCoordinate else { return }
        if let lastLocationUploadAt, Date().timeIntervalSince(lastLocationUploadAt) < 300 {
            return
        }
        do {
            try await api.upsertUserLocation(lat: coordinate.lat, lng: coordinate.lng)
            lastLocationUploadAt = Date()
        } catch {
            #if DEBUG
            print("[MarviLocation] upload failed: \(error.localizedDescription)")
            #endif
        }
    }

    func loadAdminSubjectDetail(for task: AdminTask) async -> AdminSubjectDetail? {
        guard isRemoteMode, isAuthenticated, let subjectID = task.subjectID else { return nil }

        do {
            switch task.type {
            case .creatorApplication:
                guard let profile = try await api.fetchCreatorProfile(userID: subjectID) else { return nil }
                return AdminSubjectDetail(
                    name: profile.name,
                    handle: profile.handle.isEmpty ? nil : profile.handle,
                    city: profile.city.isEmpty ? nil : profile.city,
                    area: nil,
                    category: nil,
                    niches: profile.niches,
                    languages: profile.languages,
                    score: profile.score,
                    audienceLabel: profile.audienceLabel,
                    status: profile.status.rawValue
                )
            case .venueApplication:
                guard let venue = try await api.fetchVenueProfile(id: subjectID) else { return nil }
                return AdminSubjectDetail(
                    name: venue.venueName,
                    handle: nil,
                    city: nil,
                    area: venue.area,
                    category: venue.category.rawValue,
                    niches: [],
                    languages: [],
                    score: nil,
                    audienceLabel: nil,
                    status: nil
                )
            case .campaignReview, .proofReview:
                return nil
            case .socialVerification:
                async let profileTask = api.fetchCreatorProfile(userID: subjectID)
                async let detailTask = api.fetchAdminUserDetail(userID: subjectID)
                guard let profile = try await profileTask else { return nil }
                let detail = try await detailTask
                return AdminSubjectDetail(
                    name: profile.name,
                    handle: detail.creatorHandle ?? (profile.handle.isEmpty ? nil : profile.handle),
                    city: profile.city.isEmpty ? nil : profile.city,
                    area: nil,
                    category: nil,
                    niches: profile.niches,
                    languages: profile.languages,
                    score: profile.score,
                    audienceLabel: profile.audienceLabel,
                    status: profile.status.rawValue,
                    tiktokHandle: profile.tiktokHandle.isEmpty ? nil : profile.tiktokHandle,
                    socialVerificationCode: detail.socialVerificationCode,
                    socialVerificationSubmittedAt: detail.socialVerificationSubmittedAt
                )
            }
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return nil
        }
    }

    private func updateBooking(_ id: UUID, update: (inout Booking) -> Void) {
        guard let index = bookings.firstIndex(where: { $0.id == id }) else { return }
        update(&bookings[index])
    }

    private func markSessionExpired(message: String) {
        isAuthenticated = false
        needsReauthentication = true
        clearServerState()
        SessionKeychain.clear()
        lastSyncError = message
    }

    private func clearServerState() {
        offers = []
        bookings = []
        campaigns = []
        adminTasks = []
        adminUsers = []
        adminInviteCodes = []
        adminActivity = []
        isLoadingAdminActivity = false
        adminActivityError = nil
        venueReviewQueue = []
        myVenues = []
        inboxMessages = []
        strikes = []
        savedOfferIDs = []
        profile = .empty
        accountReferralCode = nil
        pendingInviteCode = nil
        collaborationHistory = []
        followCounts = .zero
        showcaseItems = []
        memberSearchResults = []
        followingActivity = []
        followingActivityError = nil
        isLoadingFollowingActivity = false
        directThreads = []
        socialVerification = nil
    }

    // MARK: - Chat & mutual collaboration

    func loadConversations() async {
        guard isAuthenticated else { return }
        if let chats = try? await api.fetchConversations() { conversations = chats }
    }

    func venueConfirmBooking(_ booking: Booking) async -> Bool {
        guard isAuthenticated else { return false }
        do {
            let updated = try await api.venueConfirmBooking(booking.id)
            updateBooking(updated.id) { $0 = updated }
            await loadConversations()
            await refreshFromServer()
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func creatorAcceptCollaboration(requestID: UUID) async -> Bool {
        guard isAuthenticated else { return false }
        do {
            let booking = try await api.creatorAcceptCollaboration(requestID)
            bookings.insert(booking, at: 0)
            pendingCollaborationRequests.removeAll { $0.id == requestID }
            await loadConversations()
            await refreshFromServer()
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func sendChatMessage(conversationID: UUID, body: String) async -> Bool {
        guard isAuthenticated else { return false }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            _ = try await api.sendMessage(conversationID: conversationID, body: trimmed)
            await loadConversations()
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    var venuePendingConfirmations: [Booking] {
        guard selectedRole == .venue, activeVenue != nil else { return [] }
        return bookings.filter { booking in
            booking.stage == .invited && booking.offer.venue == activeVenue?.venueName
        }
    }

    func loadAdminActivity() async {
        guard isAuthenticated, allowedRoles.contains(.admin) else { return }
        isLoadingAdminActivity = true
        adminActivityError = nil
        defer { isLoadingAdminActivity = false }
        do {
            adminActivity = try await api.fetchAdminActivity(limit: 150)
        } catch {
            adminActivityError = presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func fetchChatMessages(conversationID: UUID) async -> [ChatMessage] {
        (try? await api.fetchMessages(conversationID: conversationID)) ?? []
    }

    func resolvedUserID() async -> UUID? {
        await api.resolveCurrentUserID()
    }

    // MARK: - Creator showcase

    func loadShowcase() async {
        guard isAuthenticated else { return }
        if let items = try? await api.fetchMyShowcase() { showcaseItems = items }
    }

    @discardableResult
    func addShowcaseLink(url: String, caption: String) async -> Bool {
        guard isAuthenticated else { return false }
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let normalized = trimmed.lowercased().hasPrefix("http") ? trimmed : "https://\(trimmed)"
        do {
            let item = try await api.addShowcaseItem(
                mediaType: .link,
                mediaURL: "",
                externalURL: normalized,
                caption: caption.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            showcaseItems.insert(item, at: 0)
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    @discardableResult
    func addShowcasePhoto(data: Data, caption: String) async -> Bool {
        guard isAuthenticated else { return false }
        do {
            let mediaURL = try await api.uploadShowcaseMedia(
                data: data,
                fileName: "showcase.jpg",
                contentType: "image/jpeg"
            )
            let item = try await api.addShowcaseItem(
                mediaType: .image,
                mediaURL: mediaURL,
                externalURL: "",
                caption: caption.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            showcaseItems.insert(item, at: 0)
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func deleteShowcaseItem(_ item: ShowcaseItem) async {
        guard isAuthenticated else { return }
        do {
            try await api.deleteShowcaseItem(item.id)
            showcaseItems.removeAll { $0.id == item.id }
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func loadCreatorPublicProfile(creatorID: UUID) async -> PublicCreatorProfile? {
        guard isRemoteMode, isAuthenticated else { return nil }
        do {
            return try await api.fetchCreatorPublicProfile(creatorID: creatorID)
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return nil
        }
    }

    func loadUserShowcase(userID: UUID) async -> [ShowcaseItem] {
        guard isRemoteMode, isAuthenticated else { return [] }
        do {
            return try await api.fetchShowcase(userID: userID)
        } catch {
            return []
        }
    }

    func toggleFollow(profile: PublicCreatorProfile) async -> PublicCreatorProfile {
        if profile.isFollowing {
            await unfollowUser(profile.userID)
        } else {
            await followUser(profile.userID)
        }
        return await loadCreatorPublicProfile(creatorID: profile.id) ?? {
            var fallback = profile
            fallback.isFollowing.toggle()
            return fallback
        }()
    }

    func followUser(_ userID: UUID) async {
        guard isRemoteMode, isAuthenticated else { return }
        do {
            try await api.followUser(userID)
            if let counts = try? await api.fetchMyFollowCounts() { followCounts = counts }
            await loadFollowingActivity()
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func unfollowUser(_ userID: UUID) async {
        guard isRemoteMode, isAuthenticated else { return }
        do {
            try await api.unfollowUser(userID)
            if let counts = try? await api.fetchMyFollowCounts() { followCounts = counts }
            memberSearchResults = memberSearchResults.map { member in
                guard member.userID == userID else { return member }
                var updated = member
                updated.isFollowing = false
                return updated
            }
            await loadFollowingActivity()
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func searchMembers(query: String = "") async {
        guard isRemoteMode, isAuthenticated else { return }
        do {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            memberSearchResults = try await api.searchMembers(query: trimmed.isEmpty ? nil : trimmed)
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func loadFollowingActivity() async {
        guard isRemoteMode, isAuthenticated else { return }
        isLoadingFollowingActivity = true
        followingActivityError = nil
        defer { isLoadingFollowingActivity = false }
        do {
            followingActivity = try await api.fetchFollowingActivity(limit: 40)
        } catch {
            if let message = presentableError(error) {
                followingActivityError = message
                lastSyncError = message
            }
        }
    }

    func toggleFollowMember(_ member: MemberSearchResult) async -> MemberSearchResult {
        if member.isFollowing {
            await unfollowUser(member.userID)
        } else {
            await followUser(member.userID)
            memberSearchResults = memberSearchResults.map { item in
                guard item.id == member.id else { return item }
                var updated = item
                updated.isFollowing = true
                return updated
            }
        }
        return memberSearchResults.first(where: { $0.id == member.id }) ?? member
    }

    func loadDirectThreads() async {
        guard isRemoteMode, isAuthenticated else { return }
        do {
            directThreads = try await api.fetchDirectThreads()
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
        }
    }

    func openDirectThread(with peerUserID: UUID) async -> DirectThread? {
        guard isRemoteMode, isAuthenticated else { return nil }
        do {
            let threadID = try await api.ensureDirectThread(peerUserID: peerUserID)
            await loadDirectThreads()
            if let existing = directThreads.first(where: { $0.id == threadID }) {
                return existing
            }
            if let existing = directThreads.first(where: { $0.peerUserID == peerUserID }) {
                return existing
            }
            await loadDirectThreads()
            return directThreads.first(where: { $0.peerUserID == peerUserID })
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return nil
        }
    }

    func fetchDirectChatMessages(threadID: UUID) async -> [ChatMessage] {
        guard isRemoteMode, isAuthenticated else { return [] }
        do {
            return try await api.fetchDirectMessages(threadID: threadID)
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return []
        }
    }

    func sendDirectChatMessage(threadID: UUID, body: String) async -> Bool {
        guard isRemoteMode, isAuthenticated else { return false }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            _ = try await api.sendDirectMessage(threadID: threadID, body: trimmed)
            await loadDirectThreads()
            return true
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return false
        }
    }

    func loadProfileComments(targetUserID: UUID) async -> [ProfileComment] {
        guard isRemoteMode, isAuthenticated else { return [] }
        do {
            return try await api.fetchProfileComments(targetUserID: targetUserID)
        } catch {
            return []
        }
    }

    func postProfileComment(targetUserID: UUID, body: String) async -> String? {
        guard isRemoteMode, isAuthenticated else { return t(.errSignInRequired) }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return t(.commentRequired) }
        do {
            try await api.addProfileComment(targetUserID: targetUserID, body: trimmed)
            return nil
        } catch {
            return presentableError(error) ?? t(.errSomeDataRefresh)
        }
    }

    func loadVenuePublicProfile(venueID: UUID) async -> PublicVenueProfile? {
        guard isRemoteMode, isAuthenticated else { return nil }
        do {
            return try await api.fetchVenuePublicProfile(venueID: venueID)
        } catch {
            if let message = presentableError(error) { lastSyncError = message }
            return nil
        }
    }

    func toggleFollowVenue(_ profile: PublicVenueProfile) async -> PublicVenueProfile {
        if profile.isFollowing {
            await unfollowUser(profile.ownerUserID)
        } else {
            await followUser(profile.ownerUserID)
        }
        return await loadVenuePublicProfile(venueID: profile.id) ?? {
            var fallback = profile
            fallback.isFollowing.toggle()
            return fallback
        }()
    }

    /// Banner/alert text. `nil` means cancel/noise — do not show raw NSError codes.
    private func presentableError(_ error: Error) -> String? {
        friendlyErrorMessage(error)
    }

    private func friendlyErrorMessage(_ error: Error) -> String? {
        if error is CancellationError { return nil }

        let nsError = error as NSError
        if nsError.domain == MarviAPIError.errorDomain, nsError.code == 4 {
            return nil
        }

        if let apiError = error as? MarviAPIError {
            switch apiError {
            case .cancelled:
                return nil
            case .emailConfirmationRequired:
                return t(.errConfirmEmail)
            case .notAuthenticated:
                return t(.errNotAuthenticated)
            case .unauthorized:
                return t(.errSessionExpired)
            case .invalidResponse, .decoding, .network:
                return t(.errSomeDataRefresh)
            case .notConfigured:
                return t(.errServerConfig)
            case .server:
                break
            }
        }

        let raw: String = {
            if case MarviAPIError.server(let message) = error { return message }
            if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
                return localized
            }
            let bridged = nsError.localizedDescription
            let lower = bridged.lowercased()
            if lower.contains("marviapierror") {
                if lower.contains("error 4") || lower.contains("cancelled") {
                    return ""
                }
                return t(.errSomeDataRefresh)
            }
            return bridged
        }()
        let lower = raw.lowercased()

        if lower.contains("confirm your account") || lower.contains("confirmation link") {
            return t(.errConfirmEmail)
        }

        if lower.contains("cannot be reactivated") {
            return t(.errReactivateSupport)
        }
        if lower.contains("invalid login credentials")
            || lower.contains("invalid email or password")
            || lower.contains("invalid credentials") {
            return t(.errWrongPassword)
        }
        if lower.contains("already registered")
            || lower.contains("already been registered")
            || lower.contains("user already registered")
            || lower.contains("email address is already")
            || lower.contains("user already exists") {
            return t(.errAccountExists)
        }
        if lower.contains("instagram or tiktok handle required") {
            return t(.completeProfileToAccept)
        }
        if lower.contains("rsvp guest count required") {
            return t(.extrasRequiredSub)
        }
        if lower.contains("shipping address required") {
            return t(.extrasRequiredSub)
        }
        if lower.contains("no slots") || lower.contains("remaining_slots") {
            return t(.errInvitationFull)
        }
        if lower.contains("already accepted") || lower.contains("duplicate") {
            return t(.errAlreadyAccepted)
        }
        if lower.contains("invalid check-in") || lower.contains("check-in code") {
            return t(.errCheckInInvalid)
        }
        if lower.contains("unauthorized") || lower.contains("jwt") {
            return t(.errSessionExpired)
        }
        if lower.contains("maximum allowed size")
            || lower.contains("payload too large")
            || lower.contains("entity too large")
            || lower.contains("file size") {
            return t(.errPhotoTooLarge)
        }
        if lower.contains("could not choose the best candidate function") {
            return t(.errServerSetupOfferAccept)
        }
        if lower.contains("update is not allowed in a non-volatile function") {
            return t(.errServerSetupVenueCampaign)
        }
        if lower == "cancelled" || lower.contains("urlsession task was cancelled") {
            return nil
        }
        if lower.contains("no venue profile") || lower.contains("venue not found") {
            return t(.errProfileNotReady)
        }
        if lower.contains("venue must be approved") {
            return t(.locationPendingReview)
        }
        if lower.contains("creator profile") {
            return t(.errProfileNotReady)
        }
        if lower.contains("invalid invite") || lower.contains("invite code required") {
            return t(.errInviteInvalid)
        }
        if lower.contains("could not find the function") && lower.contains("fetch_my_venues") {
            return t(.errServerSetupMultiVenue)
        }
        if lower.contains("could not find the function") && lower.contains("redeem_referral_code") {
            return t(.errServerSetupReferral)
        }
        if lower.contains("not authenticated") {
            return t(.errNotAuthenticated)
        }
        if lower.contains("authenticationservices") || lower.contains("authorizationerror") {
            return t(.errAppleSignInUnavailable)
        }
        if lower.contains("provider") && lower.contains("apple") {
            return t(.errAppleSignInUnavailable)
        }
        if lower.contains("unsupported provider") || lower.contains("validation_failed") {
            return t(.errAppleSignInUnavailable)
        }
        if lower.contains("invalid api key") || lower.contains("invalid jwt") {
            return t(.errServerConfig)
        }
        if lower.contains("update did not apply") {
            return t(.profileSaveFailed)
        }
        if lower.contains("photo url missing") {
            return t(.photoUploadFailed)
        }
        if lower.contains("couldn't be read")
            || lower.contains("could not be read")
            || lower.contains("data couldn") {
            return t(.errSomeDataRefresh)
        }
        return raw.isEmpty ? nil : raw
    }

    private func saveSnapshot() {
        guard isPersistenceReady else { return }
        persistence.save(
            AppSnapshot(
                hasCompletedOnboarding: hasCompletedOnboarding,
                selectedRole: selectedRole,
                pushNotificationsEnabled: pushNotificationsEnabled,
                proofRemindersEnabled: proofRemindersEnabled,
                autoSaveProofLinks: autoSaveProofLinks,
                preferredLanguage: preferredLanguage,
                languageManuallySet: languageManuallySet
            )
        )
    }
}
