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
    @Published private(set) var languageManuallySet = false {
        didSet { saveSnapshot() }
    }
    @Published var preferredLanguage: AppLanguage = AppLanguage.inferredFromDevice() {
        didSet { saveSnapshot() }
    }

    private var lastNotifiedInstantOfferID: UUID?
    private var lastLocationUploadAt: Date?

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
        preferredLanguage = AppLanguage.isCoordinateInTurkey(latitude: latitude, longitude: longitude)
            ? .turkish
            : .english
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
            workspaceTabIndex = selectedRole == .creator ? profileTabIndex : 1
        case .profile:
            selectedRole = allowedRoles.contains(.creator) ? .creator : (allowedRoles.first ?? .creator)
            workspaceTabIndex = profileTabIndex
        case .admin:
            Task { await openAdminConsole() }
        case .offer(let offerID):
            selectedRole = .creator
            workspaceTabIndex = 0
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
            selectedRole = .creator
            workspaceTabIndex = 1
            highlightedBookingID = bookingID
        }
        pendingDeepLink = nil
    }

    func openInboxMessage(_ message: InboxMessage) {
        Task {
            if !message.isRead {
                try? await api.markNotificationRead(message.id)
                if let index = inboxMessages.firstIndex(where: { $0.id == message.id }) {
                    inboxMessages[index].isRead = true
                }
            }
            if let link = message.deepLink {
                navigate(to: link)
            }
            track("inbox_open", properties: ["type": message.notificationType])
        }
    }

    var inboxTabIndex: Int {
        switch selectedRole {
        case .creator: 2
        case .venue, .admin: 1
        }
    }

    var profileTabIndex: Int { 2 }

    var unreadInboxCount: Int {
        inboxMessages.filter { !$0.isRead }.count
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

        // Profile first — offers filter uses creator city.
        do {
            profile = try await api.fetchProfile()
            hasLoadedInitialData = true
        } catch {
            syncErrors.append("profile")
            if let message = friendlyErrorMessage(error) {
                lastSyncError = message
            }
        }

        do {
            offers = try await api.fetchOffers(city: profile.city.lowercased())
        } catch {
            syncErrors.append("offers")
            if lastSyncError == nil, let message = friendlyErrorMessage(error) {
                lastSyncError = message
            }
        }

        if let loadedBookings = try? await api.fetchBookings() { bookings = loadedBookings }
        else { syncErrors.append("bookings") }

        if let loadedInbox = try? await api.fetchNotifications() { inboxMessages = loadedInbox }
        if let loadedSaved = try? await api.fetchSavedOfferIDs() { savedOfferIDs = loadedSaved }
        else { syncErrors.append("saved offers") }

        if allowedRoles.contains(.admin) {
            do {
                adminTasks = try await api.fetchAdminTasks()
            } catch {
                syncErrors.append("admin queue")
                if lastSyncError == nil, let message = friendlyErrorMessage(error) {
                    lastSyncError = message
                }
            }
            if let loadedUsers = try? await api.fetchAdminUsers(search: nil, status: nil) {
                adminUsers = loadedUsers
            }
        } else if let loadedTasks = try? await api.fetchAdminTasks() {
            adminTasks = loadedTasks
        }

        if let loadedStrikes = try? await api.fetchStrikes() { strikes = loadedStrikes }

        await syncAllowedRoles()

        if allowedRoles.contains(.venue), let venues = try? await api.fetchMyVenues() {
            myVenues = venues
        }
        if let loadedCampaigns = try? await api.fetchCampaigns() { campaigns = loadedCampaigns }
        if allowedRoles.contains(.venue), let reviews = try? await api.fetchVenueReviewQueue() {
            venueReviewQueue = reviews
        }

        if syncErrors.contains("profile"), retryOnUnauthorized {
            do {
                try await api.refreshSession()
                lastSyncError = nil
                await refreshFromServer(retryOnUnauthorized: false)
            } catch {
                markSessionExpired(message: friendlyErrorMessage(error) ?? error.localizedDescription)
            }
            return
        }

        if !syncErrors.isEmpty {
            lastSyncError = lastSyncError ?? t(.errSomeDataRefresh)
        } else {
            lastSyncError = nil
        }
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
            accountPausedBySelf = context.pausedBySelf
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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

    /// True when the signed-in user already finished onboarding on the server.
    func isExistingMemberOnServer() async -> Bool {
        guard isRemoteMode, isAuthenticated else { return false }

        if let context = try? await api.fetchAccountContext() {
            if context.referralCode != nil { return true }
            if context.hasVenueProfile { return true }
            if context.role == .admin { return true }
            if context.membershipStatus == .approved { return true }
        }

        let handle = profile.handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = profile.city.trimmingCharacters(in: .whitespacesAndNewlines)
        if !handle.isEmpty, !city.isEmpty { return true }
        if !bookings.isEmpty { return true }

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
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
            let message = friendlyErrorMessage(error) ?? error.localizedDescription
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
            let message = friendlyErrorMessage(error) ?? error.localizedDescription
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
            let message = friendlyErrorMessage(error) ?? error.localizedDescription
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
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
            return false
        }
    }

    func registerVenue(
        name: String,
        area: String,
        category: OfferCategory,
        address: String = "",
        contactName: String = "",
        contactPhone: String = ""
    ) async -> Bool {
        guard isRemoteMode, isAuthenticated else { return false }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        let input = RegisterVenueInput(
            venueName: name,
            area: area,
            category: category,
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
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
            await refreshFromServer()
            return true
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
            return false
        }
    }

    func signInWithEmail(_ email: String, password: String, metadata: [String: String]) async {
        guard isRemoteMode else { return }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            try await api.signInWithEmail(email, password: password, metadata: metadata)
            isAuthenticated = true
            needsReauthentication = false
            await refreshFromServer()
            await syncAllowedRoles()
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
        }
    }

    func signUpWithEmail(_ email: String, password: String, metadata: [String: String]) async {
        guard isRemoteMode else { return }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            try await api.signUpWithEmail(email, password: password, metadata: metadata)
            isAuthenticated = true
            needsReauthentication = false
            await refreshFromServer()
            await syncAllowedRoles()
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
            isAuthenticated = true
            needsReauthentication = false
            await refreshFromServer()
            await syncAllowedRoles()
        } catch MarviAPIError.cancelled {
            // User dismissed Apple sign-in — no error banner.
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
        }
    }

    func signInWithGoogle(using service: GoogleSignInService, metadata: [String: String]) async {
        guard isRemoteMode else { return }
        guard let supabaseURL = APIConfig.supabaseURL, let anonKey = APIConfig.supabaseAnonKey else { return }

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
            isAuthenticated = true
            needsReauthentication = false
            await refreshFromServer()
            await syncAllowedRoles()
        } catch MarviAPIError.cancelled {
            // User dismissed Google sign-in — no error banner.
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
                lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
            }
        }
    }

    func accept(_ offer: Offer, options: AcceptOfferOptions = AcceptOfferOptions()) {
        guard isAuthenticated, !isAccepted(offer), offer.remaining > 0 else { return }
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
                lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
            return []
        }
    }

    func shortlistCreator(_ candidate: InfluencerCandidate, offerID: UUID? = nil) async {
        guard isAuthenticated else { return }
        do {
            try await api.shortlistCreator(candidate.id, offerID: offerID)
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
        }
    }

    func passCreator(_ candidate: InfluencerCandidate, offerID: UUID? = nil) async {
        guard isAuthenticated else { return }
        do {
            try await api.passCreator(candidate.id, offerID: offerID)
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
                lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
                lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
            return friendlyErrorMessage(error) ?? error.localizedDescription
        }
    }

    func validateReferralCode(_ code: String) async -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return false }
        do {
            return try await api.validateReferralCode(normalized)
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
            return false
        }
    }

    func redeemReferralCode(_ code: String) async -> String? {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return t(.errEnterInviteCode) }
        guard isAuthenticated else { return t(.errSignInRedeemInvite) }
        do {
            try await api.redeemReferralCode(normalized)
            return nil
        } catch {
            return friendlyErrorMessage(error) ?? error.localizedDescription
        }
    }

    func uploadProofScreenshot(for booking: Booking, imageData: Data, fileName: String) async -> String? {
        do {
            return try await api.uploadProofImage(
                bookingID: booking.id,
                imageData: imageData,
                fileName: fileName
            )
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
            return friendlyErrorMessage(error) ?? error.localizedDescription
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
        deliverables: [String]
    ) async -> Bool {
        let input = CreateCampaignInput(
            title: title,
            category: category,
            collaborationModel: collaborationModel,
            dateLabel: dateLabel,
            valueLabel: valueLabel,
            slots: slots,
            deliverables: deliverables
        )

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            let campaign = try await api.createCampaign(input, venueID: activeVenue?.id)
            campaigns.insert(campaign, at: 0)
            await refreshFromServer()
            return true
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
                lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
                lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
            }
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
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
        }
    }

    func loadAdminUserDetail(userID: UUID) async -> AdminUserDetail? {
        guard isRemoteMode, isAuthenticated, allowedRoles.contains(.admin) else { return nil }
        do {
            return try await api.fetchAdminUserDetail(userID: userID)
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
            return nil
        }
    }

    func adminSetUserStatus(userID: UUID, status: MembershipStatus) async -> String? {
        guard isRemoteMode, allowedRoles.contains(.admin) else {
            return t(.errAdminRequired)
        }
        do {
            try await api.adminSetMembershipStatus(userID: userID, status: status.rawValue)
            await loadAdminUsers()
            return nil
        } catch {
            return friendlyErrorMessage(error) ?? error.localizedDescription
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
            return friendlyErrorMessage(error) ?? error.localizedDescription
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
            return friendlyErrorMessage(error) ?? error.localizedDescription
        }
    }

    func adminSendInviteEmail(email: String, inviteCode: String?) async -> String? {
        guard isRemoteMode, allowedRoles.contains(.admin) else {
            return t(.errAdminRequired)
        }
        do {
            _ = try await api.adminSendInvite(email: email, inviteCode: inviteCode)
            return nil
        } catch {
            return friendlyErrorMessage(error) ?? error.localizedDescription
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
            return (nil, friendlyErrorMessage(error) ?? error.localizedDescription)
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
            return friendlyErrorMessage(error) ?? error.localizedDescription
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
            }
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
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
        venueReviewQueue = []
        myVenues = []
        inboxMessages = []
        strikes = []
        savedOfferIDs = []
        profile = .empty
    }

    private func friendlyErrorMessage(_ error: Error) -> String? {
        if case MarviAPIError.emailConfirmationRequired = error {
            return t(.errConfirmEmail)
        }

        let raw = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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
