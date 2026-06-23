import Foundation

/// Contract-first API surface for Supabase production.
protocol MarviAPI: Sendable {
    var usesRemoteBackend: Bool { get }
    var accessToken: String? { get async }

    func signInWithApple(idToken: String, nonce: String, metadata: [String: String]) async throws
    func signInWithEmail(_ email: String, password: String, metadata: [String: String]) async throws
    func signUpWithEmail(_ email: String, password: String, metadata: [String: String]) async throws
    func resetPassword(_ email: String) async throws
    func pauseOwnAccount() async throws
    func reactivateOwnAccount() async throws
    func deleteOwnAccountPermanently() async throws
    func signOut() async throws
    func restoreSession() async -> Bool
    func refreshSession() async throws

    func fetchAccountRole() async throws -> UserRole
    func fetchMembershipStatus() async throws -> MembershipStatus?
    func fetchAccountContext() async throws -> AccountContext
    func fetchOffers(city: String) async throws -> [Offer]
    func fetchBookings() async throws -> [Booking]
    func fetchProfile() async throws -> CreatorProfile
    func updateProfile(_ profile: CreatorProfile) async throws
    func fetchNotifications() async throws -> [InboxMessage]
    func markNotificationRead(_ id: UUID) async throws
    func registerDeviceToken(_ token: String, platform: String) async throws
    func trackEvent(_ name: String, properties: [String: String]) async throws
    func fetchSavedOfferIDs() async throws -> Set<UUID>
    func fetchAdminTasks() async throws -> [AdminTask]
    func fetchCreatorProfile(userID: UUID) async throws -> CreatorProfile?
    func fetchVenueProfile(id: UUID) async throws -> VenueSummary?
    func fetchMyVenues() async throws -> [VenueSummary]
    func setActiveVenue(_ venueID: UUID) async throws
    func registerVenueLocation(_ input: RegisterVenueInput) async throws -> VenueSummary
    func fetchCampaigns() async throws -> [Campaign]
    func createCampaign(_ input: CreateCampaignInput, venueID: UUID?) async throws -> Campaign
    func fetchVenueSummary() async throws -> VenueSummary?
    func hasVenueProfile() async throws -> Bool

    func acceptOffer(_ offerID: UUID, options: AcceptOfferOptions) async throws -> Booking
    func cancelOffer(_ offerID: UUID) async throws
    func checkIn(bookingID: UUID, code: String) async throws -> Booking
    func submitProof(bookingID: UUID, links: [String]) async throws -> Booking
    func toggleSavedOffer(_ offerID: UUID) async throws -> Bool
    func approveTask(_ taskID: UUID) async throws
    func rejectTask(_ taskID: UUID) async throws
    func fetchSwipeCandidates(offerID: UUID?) async throws -> [InfluencerCandidate]
    func shortlistCreator(_ creatorID: UUID, offerID: UUID?) async throws
    func passCreator(_ creatorID: UUID, offerID: UUID?) async throws
    func redeemReferralCode(_ code: String) async throws
    func fetchVenueReviewQueue() async throws -> [VenueReviewItem]
    func submitVenueReview(bookingID: UUID, punctuality: Int, presentation: Int, comment: String) async throws
    func issueStrikeForBooking(bookingID: UUID, reason: String) async throws
    func validateReferralCode(_ code: String) async throws -> Bool
    func fetchStrikes() async throws -> [Strike]
    func uploadProofImage(bookingID: UUID, imageData: Data, fileName: String) async throws -> String
    func issueStrike(creatorID: UUID, bookingID: UUID?, reason: String) async throws

    func upsertUserLocation(lat: Double, lng: Double) async throws
    func fetchAdminUsers(search: String?, status: String?) async throws -> [AdminUserSummary]
    func fetchAdminUserDetail(userID: UUID) async throws -> AdminUserDetail
    func adminSetMembershipStatus(userID: UUID, status: String) async throws
    func adminSendNotification(userID: UUID, title: String, body: String) async throws
    func adminSendEmail(userID: UUID, subject: String, body: String) async throws
    func adminSendInvite(email: String, inviteCode: String?) async throws -> AdminInviteResult
    func adminNotifyUsersInRadius(lat: Double, lng: Double, radiusKm: Double, title: String, body: String) async throws -> Int
    func adminCreateUser(email: String, password: String?, fullName: String, city: String, autoApprove: Bool) async throws -> AdminProvisionResult
}

extension MarviAPI {
    var usesRemoteBackend: Bool { false }

    var accessToken: String? {
        get async { nil }
    }

    func restoreSession() async -> Bool { false }

    func refreshSession() async throws {}

    func fetchAccountRole() async throws -> UserRole { .creator }

    func fetchMembershipStatus() async throws -> MembershipStatus? { nil }

    func fetchAccountContext() async throws -> AccountContext {
        AccountContext(role: .creator, membershipStatus: nil, hasVenueProfile: false, referralCode: nil, pausedBySelf: false)
    }

    func updateProfile(_ profile: CreatorProfile) async throws {
        _ = profile
    }

    func validateReferralCode(_ code: String) async throws -> Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func fetchStrikes() async throws -> [Strike] { [] }

    func uploadProofImage(bookingID: UUID, imageData: Data, fileName: String) async throws -> String {
        _ = bookingID
        _ = imageData
        _ = fileName
        throw MarviAPIError.server(message: "Proof upload requires Supabase mode")
    }

    func issueStrike(creatorID: UUID, bookingID: UUID?, reason: String) async throws {
        _ = creatorID
        _ = bookingID
        _ = reason
    }

    func fetchSwipeCandidates(offerID: UUID?) async throws -> [InfluencerCandidate] { [] }

    func shortlistCreator(_ creatorID: UUID, offerID: UUID?) async throws {}

    func passCreator(_ creatorID: UUID, offerID: UUID?) async throws {}

    func redeemReferralCode(_ code: String) async throws {}

    func signUpWithEmail(_ email: String, password: String, metadata: [String: String]) async throws {
        throw MarviAPIError.server(message: "Sign up requires Supabase mode")
    }

    func resetPassword(_ email: String) async throws {
        throw MarviAPIError.server(message: "Password reset requires Supabase mode")
    }

    func pauseOwnAccount() async throws {
        throw MarviAPIError.server(message: "Account pause requires Supabase mode")
    }

    func reactivateOwnAccount() async throws {
        throw MarviAPIError.server(message: "Account reactivation requires Supabase mode")
    }

    func deleteOwnAccountPermanently() async throws {
        throw MarviAPIError.server(message: "Account deletion requires Supabase mode")
    }

    func fetchVenueReviewQueue() async throws -> [VenueReviewItem] { [] }

    func submitVenueReview(bookingID: UUID, punctuality: Int, presentation: Int, comment: String) async throws {}

    func issueStrikeForBooking(bookingID: UUID, reason: String) async throws {}

    func fetchCampaigns() async throws -> [Campaign] { [] }

    func createCampaign(_ input: CreateCampaignInput, venueID: UUID?) async throws -> Campaign {
        _ = input
        _ = venueID
        throw MarviAPIError.server(message: "Campaigns require Supabase mode")
    }

    func fetchMyVenues() async throws -> [VenueSummary] { [] }

    func setActiveVenue(_ venueID: UUID) async throws {
        _ = venueID
    }

    func registerVenueLocation(_ input: RegisterVenueInput) async throws -> VenueSummary {
        _ = input
        throw MarviAPIError.server(message: "Venue registration requires Supabase mode")
    }

    func fetchVenueSummary() async throws -> VenueSummary? { nil }

    func hasVenueProfile() async throws -> Bool { false }

    func fetchCreatorProfile(userID: UUID) async throws -> CreatorProfile? { nil }

    func fetchVenueProfile(id: UUID) async throws -> VenueSummary? { nil }

    func upsertUserLocation(lat: Double, lng: Double) async throws {
        _ = lat
        _ = lng
    }

    func fetchAdminUsers(search: String?, status: String?) async throws -> [AdminUserSummary] { [] }

    func fetchAdminUserDetail(userID: UUID) async throws -> AdminUserDetail {
        _ = userID
        throw MarviAPIError.server(message: "Admin detail requires Supabase mode")
    }

    func adminSetMembershipStatus(userID: UUID, status: String) async throws {
        _ = userID
        _ = status
    }

    func adminSendNotification(userID: UUID, title: String, body: String) async throws {
        _ = userID
        _ = title
        _ = body
    }

    func adminSendEmail(userID: UUID, subject: String, body: String) async throws {
        _ = userID
        _ = subject
        _ = body
    }

    func adminSendInvite(email: String, inviteCode: String?) async throws -> AdminInviteResult {
        _ = email
        _ = inviteCode
        throw MarviAPIError.server(message: "Admin invite requires Supabase mode")
    }

    func adminNotifyUsersInRadius(lat: Double, lng: Double, radiusKm: Double, title: String, body: String) async throws -> Int {
        _ = lat
        _ = lng
        _ = radiusKm
        _ = title
        _ = body
        return 0
    }

    func adminCreateUser(email: String, password: String?, fullName: String, city: String, autoApprove: Bool) async throws -> AdminProvisionResult {
        _ = email
        _ = password
        _ = fullName
        _ = city
        _ = autoApprove
        throw MarviAPIError.server(message: "Admin create user requires Supabase mode")
    }
}

extension MarviAPI {
    func acceptOffer(_ offerID: UUID) async throws -> Booking {
        try await acceptOffer(offerID, options: AcceptOfferOptions())
    }

    func markNotificationRead(_ id: UUID) async throws {}

    func registerDeviceToken(_ token: String, platform: String) async throws {}

    func trackEvent(_ name: String, properties: [String: String]) async throws {}
}
