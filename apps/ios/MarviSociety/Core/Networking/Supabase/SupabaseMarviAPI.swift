import Foundation

final class SupabaseMarviAPI: MarviAPI, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    var usesRemoteBackend: Bool { true }

    var accessToken: String? {
        get async { await client.accessToken }
    }

    // MARK: - Auth

    func signInWithApple(idToken: String, nonce: String, metadata: [String: String]) async throws {
        try await client.signInWithApple(idToken: idToken, nonce: nonce)
        _ = metadata
    }

    func signInWithEmail(_ email: String, password: String) async throws {
        try await client.signInWithEmail(email, password: password)
    }

    func signOut() async throws {
        try await client.signOut()
    }

    // MARK: - Read

    func fetchOffers(city: String) async throws -> [Offer] {
        let rows: [OfferRow] = try await client.select(
            table: "offers",
            query: [
                URLQueryItem(name: "select", value: "*,venue_profiles(venue_name,area)"),
                URLQueryItem(name: "status", value: "eq.live"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )
        return rows.map { $0.toOffer() }
    }

    func fetchBookings() async throws -> [Booking] {
        let rows: [BookingJoinRow] = try await client.select(
            table: "bookings",
            query: [
                URLQueryItem(name: "select", value: "*,offers(*,venue_profiles(venue_name,area))"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )
        return rows.compactMap { $0.toBooking() }
    }

    func fetchProfile() async throws -> CreatorProfile {
        let rows: [CreatorProfileRow] = try await client.select(
            table: "creator_profiles",
            query: [URLQueryItem(name: "limit", value: "1")]
        )
        guard let row = rows.first else {
            throw MarviAPIError.server(message: "Creator profile not found")
        }
        return row.toProfile()
    }

    func fetchNotifications() async throws -> [InboxMessage] {
        let rows: [NotificationRow] = try await client.select(
            table: "notifications",
            query: [URLQueryItem(name: "order", value: "created_at.desc")]
        )
        return rows.map { $0.toMessage() }
    }

    func fetchSavedOfferIDs() async throws -> Set<UUID> {
        let rows: [SavedOfferRow] = try await client.select(table: "saved_offers")
        return Set(rows.map(\.offer_id))
    }

    func fetchAdminTasks() async throws -> [AdminTask] {
        let rows: [AdminTaskRow] = try await client.select(
            table: "admin_tasks",
            query: [
                URLQueryItem(name: "status", value: "eq.open"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )
        return rows.map { $0.toTask() }
    }

    // MARK: - Write

    func acceptOffer(_ offerID: UUID) async throws -> Booking {
        let row: BookingRPCRow = try await client.rpc(
            function: "accept_offer",
            body: ["p_offer_id": offerID.uuidString]
        )
        let offers = try await fetchOffers(city: "istanbul")
        guard let offer = offers.first(where: { $0.id == offerID }) else {
            throw MarviAPIError.server(message: "Offer not found after accept")
        }
        return row.toBooking(offer: offer)
    }

    func cancelOffer(_ offerID: UUID) async throws {
        let bookings: [BookingIDRow] = try await client.select(
            table: "bookings",
            query: [
                URLQueryItem(name: "select", value: "id"),
                URLQueryItem(name: "offer_id", value: "eq.\(offerID.uuidString)"),
                URLQueryItem(name: "stage", value: "neq.cancelled")
            ]
        )
        guard let bookingID = bookings.first?.id else { return }
        let _: BookingRPCRow = try await client.rpc(
            function: "cancel_booking",
            body: ["p_booking_id": bookingID.uuidString]
        )
    }

    func checkIn(bookingID: UUID, code: String) async throws -> Booking {
        let _: BookingRPCRow = try await client.rpc(
            function: "check_in_booking",
            body: [
                "p_booking_id": bookingID.uuidString,
                "p_code": code
            ]
        )
        let bookings = try await fetchBookings()
        guard let booking = bookings.first(where: { $0.id == bookingID }) else {
            throw MarviAPIError.invalidResponse
        }
        return booking
    }

    func submitProof(bookingID: UUID, links: [String]) async throws -> Booking {
        let _: BookingRPCRow = try await client.rpc(
            function: "submit_proof",
            body: [
                "p_booking_id": bookingID.uuidString,
                "p_links": links
            ]
        )
        let bookings = try await fetchBookings()
        guard let booking = bookings.first(where: { $0.id == bookingID }) else {
            throw MarviAPIError.invalidResponse
        }
        return booking
    }

    func toggleSavedOffer(_ offerID: UUID) async throws -> Bool {
        try await client.rpc(
            function: "toggle_saved_offer",
            body: ["p_offer_id": offerID.uuidString],
            type: Bool.self
        )
    }

    func approveTask(_ taskID: UUID) async throws {
        try await client.patch(
            table: "admin_tasks",
            id: taskID,
            body: [
                "status": "approved",
                "resolved_at": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    func rejectTask(_ taskID: UUID) async throws {
        try await client.patch(
            table: "admin_tasks",
            id: taskID,
            body: [
                "status": "rejected",
                "resolved_at": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }
}

// MARK: - Join row types

private struct VenueEmbed: Decodable {
    let venue_name: String
    let area: String
}

private struct BookingRPCRow: Decodable {
    let id: UUID
    let offer_id: UUID
    let stage: String
    let check_in_code: String
    let guest_name: String?
    let proof_deadline_label: String?
    let proof_status: String?
    let proof_links: [String]?

    func toBooking(offer: Offer) -> Booking {
        Booking(
            id: id,
            offer: offer,
            stage: BookingStage.fromAPI(stage),
            proofDeadline: proof_deadline_label ?? "Today, 22:00",
            checklist: [
                "Confirm guest details",
                "Check in with venue host",
                "Upload story, post, or review links"
            ],
            proofStatus: ProofStatus.fromAPI(proof_status),
            checkInCode: check_in_code,
            guestName: guest_name ?? "",
            proofLinks: proof_links ?? []
        )
    }
}

private struct BookingIDRow: Decodable {
    let id: UUID
}

private struct BookingJoinRow: Decodable {
    let id: UUID
    let offer_id: UUID?
    let stage: String
    let check_in_code: String
    let guest_name: String?
    let proof_deadline_label: String?
    let proof_status: String?
    let proof_links: [String]?
    let offers: NestedOffer?

    struct NestedOffer: Decodable {
        let id: UUID?
        let title: String?
        let category: String?
        let model: String?
        let date_label: String?
        let time_label: String?
        let value_label: String?
        let capacity: Int?
        let remaining_slots: Int?
        let image_name: String?
        let description: String?
        let deliverables: [String]?
        let requirements: [String]?
        let host_note: String?
        let checklist: [String]?
        let venue_profiles: VenueEmbed?
    }

    func toBooking() -> Booking? {
        guard let nested = offers else { return nil }
        let offer = Offer(
            id: nested.id ?? offer_id ?? id,
            title: nested.title ?? "Offer",
            venue: nested.venue_profiles?.venue_name ?? "Venue",
            area: nested.venue_profiles?.area ?? "Istanbul",
            category: OfferCategory.fromAPI(nested.category),
            dateLabel: nested.date_label ?? "TBD",
            timeLabel: nested.time_label ?? "",
            valueLabel: nested.value_label ?? "",
            capacity: nested.capacity ?? 1,
            remaining: nested.remaining_slots ?? 0,
            imageName: nested.image_name ?? "venue-placeholder",
            description: nested.description ?? "",
            deliverables: nested.deliverables ?? [],
            requirements: nested.requirements ?? [],
            hostNote: nested.host_note ?? "",
            collaborationModel: CollaborationModel.fromAPI(nested.model)
        )

        return Booking(
            id: id,
            offer: offer,
            stage: BookingStage.fromAPI(stage),
            proofDeadline: proof_deadline_label ?? "Today, 22:00",
            checklist: nested.checklist ?? [
                "Confirm guest details",
                "Check in with venue host",
                "Upload story, post, or review links"
            ],
            proofStatus: ProofStatus.fromAPI(proof_status),
            checkInCode: check_in_code,
            guestName: guest_name ?? "",
            proofLinks: proof_links ?? []
        )
    }
}
