import Foundation

/// Contract-first API surface shared by local demo and Supabase production.
protocol MarviAPI: Sendable {
    var usesRemoteBackend: Bool { get }
    var accessToken: String? { get async }

    func signInWithApple(idToken: String, nonce: String, metadata: [String: String]) async throws
    func signInWithEmail(_ email: String, password: String) async throws
    func signOut() async throws

    func fetchOffers(city: String) async throws -> [Offer]
    func fetchBookings() async throws -> [Booking]
    func fetchProfile() async throws -> CreatorProfile
    func fetchNotifications() async throws -> [InboxMessage]
    func fetchSavedOfferIDs() async throws -> Set<UUID>
    func fetchAdminTasks() async throws -> [AdminTask]

    func acceptOffer(_ offerID: UUID) async throws -> Booking
    func cancelOffer(_ offerID: UUID) async throws
    func checkIn(bookingID: UUID, code: String) async throws -> Booking
    func submitProof(bookingID: UUID, links: [String]) async throws -> Booking
    func toggleSavedOffer(_ offerID: UUID) async throws -> Bool
    func approveTask(_ taskID: UUID) async throws
    func rejectTask(_ taskID: UUID) async throws
}

extension MarviAPI {
    var usesRemoteBackend: Bool { false }
}
