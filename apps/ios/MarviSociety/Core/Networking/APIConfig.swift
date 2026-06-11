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

    func signInWithEmail(_ email: String, password: String, metadata: [String: String]) async throws {
        throw notConfigured()
    }

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
    func fetchSavedOfferIDs() async throws -> Set<UUID> { throw notConfigured() }
    func fetchAdminTasks() async throws -> [AdminTask] { throw notConfigured() }
    func fetchCampaigns() async throws -> [Campaign] { throw notConfigured() }
    func createCampaign(_ input: CreateCampaignInput) async throws -> Campaign { throw notConfigured() }
    func fetchVenueSummary() async throws -> VenueSummary? { throw notConfigured() }
    func hasVenueProfile() async throws -> Bool { throw notConfigured() }
    func acceptOffer(_ offerID: UUID) async throws -> Booking { throw notConfigured() }
    func cancelOffer(_ offerID: UUID) async throws { throw notConfigured() }
    func checkIn(bookingID: UUID, code: String) async throws -> Booking { throw notConfigured() }
    func submitProof(bookingID: UUID, links: [String]) async throws -> Booking { throw notConfigured() }
    func toggleSavedOffer(_ offerID: UUID) async throws -> Bool { throw notConfigured() }
    func approveTask(_ taskID: UUID) async throws { throw notConfigured() }
    func rejectTask(_ taskID: UUID) async throws { throw notConfigured() }
    func fetchSwipeCandidates(offerID: UUID?) async throws -> [InfluencerCandidate] { [] }
    func shortlistCreator(_ creatorID: UUID, offerID: UUID?) async throws { throw notConfigured() }
    func fetchVenueReviewQueue() async throws -> [VenueReviewItem] { [] }
    func submitVenueReview(bookingID: UUID, punctuality: Int, presentation: Int, comment: String) async throws {
        throw notConfigured()
    }
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
}
