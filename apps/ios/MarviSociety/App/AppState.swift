import SwiftUI

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
    @Published var offers: [Offer] = []
    @Published var savedOfferIDs: Set<UUID> = []
    @Published var bookings: [Booking] = []
    @Published var campaigns: [Campaign] = []
    @Published var adminTasks: [AdminTask] = []
    @Published var inboxMessages: [InboxMessage] = []
    @Published var profile = CreatorProfile.empty
    @Published var strikes: [Strike] = []
    @Published var pushNotificationsEnabled = true {
        didSet { saveSnapshot() }
    }
    @Published var proofRemindersEnabled = true {
        didSet { saveSnapshot() }
    }
    @Published var autoSaveProofLinks = false {
        didSet { saveSnapshot() }
    }

    @Published var isSyncing = false
    @Published var isBootstrapping = false
    @Published var hasLoadedInitialData = false
    @Published var needsReauthentication = false
    @Published var lastSyncError: String?
    @Published var isAuthenticated = false
    @Published var allowedRoles: [UserRole] = [.creator]
    @Published var accountRole: UserRole = .creator
    @Published var pendingOfferIDs: Set<UUID> = []
    @Published var venueReviewQueue: [VenueReviewItem] = []

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
        }

        isPersistenceReady = true

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

    var openAdminTasks: [AdminTask] {
        adminTasks.filter { $0.status == .open }
    }

    var backendLabel: String { "Supabase" }

    var userCoordinate: (lat: Double, lng: Double)? {
        guard let coordinate = locationService.coordinate else { return nil }
        return (coordinate.latitude, coordinate.longitude)
    }

    func refreshLocation() {
        locationService.refreshLocation()
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
        Task { _ = await PushNotificationService.requestAuthorization() }
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
            await refreshFromServer(retryOnUnauthorized: true)
            await syncAllowedRoles()
            return
        }

        if hasCompletedOnboarding {
            needsReauthentication = true
            isAuthenticated = false
            lastSyncError = "Your session expired. Please sign in again."
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
        if let loadedTasks = try? await api.fetchAdminTasks() { adminTasks = loadedTasks }
        if let loadedStrikes = try? await api.fetchStrikes() { strikes = loadedStrikes }
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
            lastSyncError = lastSyncError ?? "Some data could not be refreshed. Pull down to try again."
        } else {
            lastSyncError = nil
        }

        await syncAllowedRoles()
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
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
        }
    }

    func signOut() async {
        try? await api.signOut()
        clearServerState()
        hasCompletedOnboarding = false
        needsReauthentication = false
        hasLoadedInitialData = false
        isAuthenticated = false
        allowedRoles = [.creator]
        accountRole = .creator
        selectedRole = .creator
        SessionKeychain.clear()
        persistence.reset()
    }

    func loadVenueSummary() async -> VenueSummary? {
        guard isRemoteMode, isAuthenticated else { return nil }
        do {
            return try await api.fetchVenueSummary()
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
            return nil
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

    func accept(_ offer: Offer) {
        guard isAuthenticated, !isAccepted(offer), offer.remaining > 0 else { return }
        pendingOfferIDs.insert(offer.id)
        Task {
            defer { pendingOfferIDs.remove(offer.id) }
            do {
                let booking = try await api.acceptOffer(offer.id)
                bookings.insert(booking, at: 0)
                syncProofReminders()
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
            lastSyncError = "This task has no linked booking."
            return
        }
        Task {
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
        guard isAuthenticated else { return "Please sign in to check in." }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "Enter the check-in code from the venue host." }

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
        guard !normalized.isEmpty else { return "Enter a valid invite code." }
        guard isAuthenticated else { return "Sign in before redeeming your invite." }
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
        guard isAuthenticated else { return "Please sign in to submit proof." }
        var proofLinks = links
        if let imageData, !imageData.isEmpty {
            if let url = await uploadProofScreenshot(for: booking, imageData: imageData, fileName: fileName) {
                proofLinks.append(url)
            } else if links.isEmpty {
                return lastSyncError ?? "Could not upload screenshot."
            }
        }
        guard !proofLinks.isEmpty else { return "Add at least one proof link or screenshot." }
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
            let campaign = try await api.createCampaign(input)
            campaigns.insert(campaign, at: 0)
            await refreshFromServer()
            return true
        } catch {
            lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
            return false
        }
    }

    func approveTask(_ task: AdminTask) {
        Task {
            do {
                try await api.approveTask(task.id)
                await refreshFromServer()
            } catch {
                lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
            }
        }
    }

    func rejectTask(_ task: AdminTask) {
        Task {
            do {
                try await api.rejectTask(task.id)
                await refreshFromServer()
            } catch {
                lastSyncError = friendlyErrorMessage(error) ?? error.localizedDescription
            }
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
        venueReviewQueue = []
        inboxMessages = []
        strikes = []
        savedOfferIDs = []
        profile = .empty
    }

    private func friendlyErrorMessage(_ error: Error) -> String? {
        let raw = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let lower = raw.lowercased()

        if lower.contains("no slots") || lower.contains("remaining_slots") {
            return "This invitation is full. Try another event."
        }
        if lower.contains("already accepted") || lower.contains("duplicate") {
            return "You already accepted this invitation."
        }
        if lower.contains("invalid check-in") || lower.contains("check-in code") {
            return "Invalid check-in code. Ask the venue host for the correct code."
        }
        if lower.contains("unauthorized") || lower.contains("jwt") {
            return "Your session expired. Please sign in again."
        }
        if lower.contains("creator profile") {
            return "Your creator profile is not set up yet. Contact support."
        }
        if lower.contains("not authenticated") {
            return "Please sign in to continue."
        }
        if lower.contains("authenticationservices") || lower.contains("authorizationerror") {
            return "Sign in with Apple is not available on this build. Use email sign-in."
        }
        if lower.contains("invalid api key") || lower.contains("invalid jwt") {
            return "Server configuration error. Check Supabase anon key in Secrets.xcconfig."
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
                autoSaveProofLinks: autoSaveProofLinks
            )
        )
    }
}
