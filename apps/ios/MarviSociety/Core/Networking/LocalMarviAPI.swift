import Foundation

/// Offline demo implementation — mirrors SampleData workflows without network.
final class LocalMarviAPI: MarviAPI, @unchecked Sendable {
    func signInWithApple(idToken: String, nonce: String, metadata: [String: String]) async throws {}
    func signInWithEmail(_ email: String, password: String) async throws {}
    func signOut() async throws {}

    func fetchOffers(city: String) async throws -> [Offer] {
        SampleData.offers
    }

    func fetchBookings() async throws -> [Booking] {
        SampleData.bookings
    }

    func fetchProfile() async throws -> CreatorProfile {
        SampleData.profile
    }

    func fetchNotifications() async throws -> [InboxMessage] {
        SampleData.inboxMessages
    }

    func fetchSavedOfferIDs() async throws -> Set<UUID> {
        [SampleData.offers[0].id, SampleData.offers[2].id]
    }

    func fetchAdminTasks() async throws -> [AdminTask] {
        SampleData.adminTasks
    }

    func acceptOffer(_ offerID: UUID) async throws -> Booking {
        guard let offer = SampleData.offers.first(where: { $0.id == offerID }) else {
            throw MarviAPIError.server(message: "Offer not found")
        }
        return Booking(
            id: UUID(),
            offer: offer,
            stage: .confirmed,
            proofDeadline: "\(offer.dateLabel), 22:00",
            checklist: [
                "Confirm guest details",
                "Check in with venue host",
                "Upload story, post, or review links"
            ],
            proofStatus: .notStarted,
            checkInCode: String(Int.random(in: 1200...9899)),
            guestName: "",
            proofLinks: []
        )
    }

    func cancelOffer(_ offerID: UUID) async throws {}

    func checkIn(bookingID: UUID, code: String) async throws -> Booking {
        guard var booking = SampleData.bookings.first(where: { $0.id == bookingID }) else {
            throw MarviAPIError.server(message: "Booking not found")
        }
        booking.stage = .checkedIn
        return booking
    }

    func submitProof(bookingID: UUID, links: [String]) async throws -> Booking {
        guard var booking = SampleData.bookings.first(where: { $0.id == bookingID }) else {
            throw MarviAPIError.server(message: "Booking not found")
        }
        booking.stage = .completed
        booking.proofStatus = .pending
        booking.proofLinks = links
        return booking
    }

    func toggleSavedOffer(_ offerID: UUID) async throws -> Bool {
        true
    }

    func approveTask(_ taskID: UUID) async throws {}
    func rejectTask(_ taskID: UUID) async throws {}
}
