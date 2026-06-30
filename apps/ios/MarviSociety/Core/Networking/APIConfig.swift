import Foundation

enum APIMode: String {
    case supabase
}

enum APIConfig {
    private static let secretsPlist: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist
    }()

    private static func stringValue(for key: String) -> String? {
        if let fromSecrets = secretsPlist?[key] as? String,
           !fromSecrets.isEmpty,
           !fromSecrets.hasPrefix("$(") {
            return fromSecrets
        }
        return Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    static var mode: APIMode {
        guard let raw = stringValue(for: "MARVI_API_MODE"),
              let parsed = APIMode(rawValue: raw.lowercased()) else {
            return .supabase
        }
        return parsed
    }

    static var supabaseURL: URL? {
        guard let raw = stringValue(for: "MARVI_SUPABASE_URL"),
              !raw.isEmpty,
              !raw.contains("YOUR_PROJECT"),
              let url = URL(string: raw) else {
            return nil
        }
        return url
    }

    static var supabaseAnonKey: String? {
        guard let raw = stringValue(for: "MARVI_SUPABASE_ANON_KEY"),
              !raw.isEmpty,
              !raw.contains("your-anon") else {
            return nil
        }
        return raw
    }

    static var isSupabaseConfigured: Bool {
        mode == .supabase && supabaseURL != nil && supabaseAnonKey != nil
    }

    /// Sign in with Apple requires Supabase Apple provider + Services ID. Off by default for App Store safety.
    static var appleSignInEnabled: Bool {
        guard let raw = stringValue(for: "MARVI_APPLE_SIGN_IN_ENABLED")?.lowercased() else {
            return false
        }
        return raw == "1" || raw == "true" || raw == "yes"
    }

    /// Google (Gmail) OAuth via Supabase. Requires Google provider in Supabase Dashboard.
    static var googleSignInEnabled: Bool {
        guard let raw = stringValue(for: "MARVI_GOOGLE_SIGN_IN_ENABLED")?.lowercased() else {
            return false
        }
        return raw == "1" || raw == "true" || raw == "yes"
    }

    static func makeAPI() -> any MarviAPI {
        guard isSupabaseConfigured, let url = supabaseURL, let key = supabaseAnonKey else {
            return UnconfiguredMarviAPI.shared
        }
        let client = SupabaseClient(baseURL: url, anonKey: key)
        return SupabaseMarviAPI(client: client)
    }
}

/// Returned when Supabase credentials are missing from the build configuration.
final class UnconfiguredMarviAPI: MarviAPI, @unchecked Sendable {
    static let shared = UnconfiguredMarviAPI()

    var usesRemoteBackend: Bool { false }

    private func notConfigured() -> MarviAPIError {
        .notConfigured
    }

    var accessToken: String? {
        get async { nil }
    }

    func signInWithApple(idToken: String, nonce: String, metadata: [String: String]) async throws {
        throw notConfigured()
    }

    func signInWithGoogle(accessToken: String, refreshToken: String?, metadata: [String: String]) async throws {
        throw notConfigured()
    }

    func signInWithEmail(_ email: String, password: String, metadata: [String: String]) async throws {
        throw notConfigured()
    }

    func signUpWithEmail(_ email: String, password: String, metadata: [String: String]) async throws {
        throw notConfigured()
    }

    func resetPassword(_ email: String) async throws {
        throw notConfigured()
    }

    func pauseOwnAccount() async throws { throw notConfigured() }
    func reactivateOwnAccount() async throws { throw notConfigured() }
    func deleteOwnAccountPermanently() async throws { throw notConfigured() }

    func signOut() async throws {}

    func restoreSession() async -> Bool { false }

    func refreshSession() async throws {
        throw notConfigured()
    }

    func fetchAccountRole() async throws -> UserRole { throw notConfigured() }
    func fetchMembershipStatus() async throws -> MembershipStatus? { throw notConfigured() }
    func fetchAccountContext() async throws -> AccountContext { throw notConfigured() }
    func fetchOffers(city: String) async throws -> [Offer] { throw notConfigured() }
    func fetchBookings() async throws -> [Booking] { throw notConfigured() }
    func fetchProfile() async throws -> CreatorProfile { throw notConfigured() }
    func updateProfile(_ profile: CreatorProfile) async throws { throw notConfigured() }
    func fetchNotifications() async throws -> [InboxMessage] { throw notConfigured() }
    func markNotificationRead(_ id: UUID) async throws { throw notConfigured() }
    func registerDeviceToken(_ token: String, platform: String) async throws { throw notConfigured() }
    func trackEvent(_ name: String, properties: [String: String]) async throws { throw notConfigured() }
    func fetchSavedOfferIDs() async throws -> Set<UUID> { throw notConfigured() }
    func fetchAdminTasks() async throws -> [AdminTask] { throw notConfigured() }
    func fetchCreatorProfile(userID: UUID) async throws -> CreatorProfile? { throw notConfigured() }
    func fetchCreatorPublicProfile(creatorID: UUID) async throws -> PublicCreatorProfile? { throw notConfigured() }
    func fetchVenueProfile(id: UUID) async throws -> VenueSummary? { throw notConfigured() }
    func fetchMyVenues() async throws -> [VenueSummary] { throw notConfigured() }
    func setActiveVenue(_ venueID: UUID) async throws { throw notConfigured() }
    func registerVenueLocation(_ input: RegisterVenueInput) async throws -> VenueSummary { throw notConfigured() }
    func fetchCampaigns() async throws -> [Campaign] { throw notConfigured() }
    func createCampaign(_ input: CreateCampaignInput, venueID: UUID?) async throws -> Campaign { throw notConfigured() }
    func fetchVenueSummary() async throws -> VenueSummary? { throw notConfigured() }
    func hasVenueProfile() async throws -> Bool { throw notConfigured() }
    func acceptOffer(_ offerID: UUID, options: AcceptOfferOptions) async throws -> Booking { throw notConfigured() }
    func cancelOffer(_ offerID: UUID) async throws { throw notConfigured() }
    func checkIn(bookingID: UUID, code: String) async throws -> Booking { throw notConfigured() }
    func submitProof(bookingID: UUID, links: [String]) async throws -> Booking { throw notConfigured() }
    func toggleSavedOffer(_ offerID: UUID) async throws -> Bool { throw notConfigured() }
    func approveTask(_ taskID: UUID) async throws { throw notConfigured() }
    func rejectTask(_ taskID: UUID) async throws { throw notConfigured() }
    func fetchSwipeCandidates(offerID: UUID?) async throws -> [InfluencerCandidate] { [] }
    func shortlistCreator(_ creatorID: UUID, offerID: UUID?) async throws { throw notConfigured() }
    func passCreator(_ creatorID: UUID, offerID: UUID?) async throws { throw notConfigured() }
    func redeemReferralCode(_ code: String) async throws { throw notConfigured() }
    func fetchVenueReviewQueue() async throws -> [VenueReviewItem] { [] }
    func submitVenueReview(bookingID: UUID, punctuality: Int, presentation: Int, comment: String) async throws {
        throw notConfigured()
    }
    func submitCreatorReview(bookingID: UUID, hospitality: Int, experience: Int, comment: String) async throws {
        throw notConfigured()
    }
    func uploadProfileImage(data: Data, fileName: String, kind: ProfileImageKind) async throws -> String {
        throw notConfigured()
    }
    func uploadShowcaseMedia(data: Data, fileName: String, contentType: String) async throws -> String { throw notConfigured() }
    func fetchMyShowcase() async throws -> [ShowcaseItem] { [] }
    func fetchShowcase(userID: UUID) async throws -> [ShowcaseItem] { [] }
    func addShowcaseItem(mediaType: ShowcaseMediaType, mediaURL: String, externalURL: String, caption: String) async throws -> ShowcaseItem { throw notConfigured() }
    func deleteShowcaseItem(_ id: UUID) async throws { throw notConfigured() }
    func issueStrikeForBooking(bookingID: UUID, reason: String) async throws {
        throw notConfigured()
    }
    func validateReferralCode(_ code: String) async throws -> Bool { throw notConfigured() }
    func fetchStrikes() async throws -> [Strike] { throw notConfigured() }
    func uploadProofImage(bookingID: UUID, imageData: Data, fileName: String) async throws -> String {
        throw notConfigured()
    }
    func issueStrike(creatorID: UUID, bookingID: UUID?, reason: String) async throws {
        throw notConfigured()
    }
    func upsertUserLocation(lat: Double, lng: Double) async throws { throw notConfigured() }
    func fetchAdminUsers(search: String?, status: String?) async throws -> [AdminUserSummary] { throw notConfigured() }
    func fetchAdminUserDetail(userID: UUID) async throws -> AdminUserDetail { throw notConfigured() }
    func adminSetMembershipStatus(userID: UUID, status: String) async throws { throw notConfigured() }
    func adminSendNotification(userID: UUID, title: String, body: String) async throws { throw notConfigured() }
    func adminSendEmail(userID: UUID, subject: String, body: String) async throws { throw notConfigured() }
    func adminSendInvite(email: String, inviteCode: String?) async throws -> AdminInviteResult { throw notConfigured() }
    func sendCreatorInvite(email: String) async throws -> AdminInviteResult { throw notConfigured() }
    func fetchMyCollaborationHistory() async throws -> [CollaborationEntry] { [] }
    func fetchMyFollowCounts() async throws -> FollowCounts { .zero }
    func followUser(_ userID: UUID) async throws { throw notConfigured() }
    func unfollowUser(_ userID: UUID) async throws { throw notConfigured() }
    func adminNotifyUsersInRadius(lat: Double, lng: Double, radiusKm: Double, title: String, body: String) async throws -> Int {
        throw notConfigured()
    }
    func adminCreateUser(email: String, password: String?, fullName: String, city: String, autoApprove: Bool) async throws -> AdminProvisionResult {
        throw notConfigured()
    }
    func fetchConversations() async throws -> [ChatConversation] { [] }
    func fetchMessages(conversationID: UUID) async throws -> [ChatMessage] { [] }
    func sendMessage(conversationID: UUID, body: String) async throws -> ChatMessage { throw notConfigured() }
    func venueConfirmBooking(_ bookingID: UUID) async throws -> Booking { throw notConfigured() }
    func creatorAcceptCollaboration(_ requestID: UUID) async throws -> Booking { throw notConfigured() }
    func fetchPendingCollaborationRequests() async throws -> [PendingCollaborationRequest] { [] }
    func fetchAdminActivity(limit: Int) async throws -> [ActivityEventItem] { [] }
    func resolveCurrentUserID() async -> UUID? { nil }
}
