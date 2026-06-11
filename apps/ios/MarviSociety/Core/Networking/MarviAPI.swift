import Foundation

/// Contract-first API surface for Supabase production.
protocol MarviAPI: Sendable {
    var usesRemoteBackend: Bool { get }
    var accessToken: String? { get async }

    func signInWithApple(idToken: String, nonce: String, metadata: [String: String]) async throws
    func signInWithEmail(_ email: String, password: String, metadata: [String: String]) async throws
    func signUpWithEmail(_ email: String, password: String, metadata: [String: String]) async throws
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
    func fetchSavedOfferIDs() async throws -> Set<UUID>
    func fetchAdminTasks() async throws -> [AdminTask]
    func fetchCampaigns() async throws -> [Campaign]
    func createCampaign(_ input: CreateCampaignInput) async throws -> Campaign
    func fetchVenueSummary() async throws -> VenueSummary?
    func hasVenueProfile() async throws -> Bool

    func acceptOffer(_ offerID: UUID) async throws -> Booking
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
        AccountContext(role: .creator, membershipStatus: nil, hasVenueProfile: false)
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

    func fetchVenueReviewQueue() async throws -> [VenueReviewItem] { [] }

    func submitVenueReview(bookingID: UUID, punctuality: Int, presentation: Int, comment: String) async throws {}

    func issueStrikeForBooking(bookingID: UUID, reason: String) async throws {}

    func fetchCampaigns() async throws -> [Campaign] { [] }

    func createCampaign(_ input: CreateCampaignInput) async throws -> Campaign {
        _ = input
        throw MarviAPIError.server(message: "Campaigns require Supabase mode")
    }

    func fetchVenueSummary() async throws -> VenueSummary? { nil }

    func hasVenueProfile() async throws -> Bool { false }
}
