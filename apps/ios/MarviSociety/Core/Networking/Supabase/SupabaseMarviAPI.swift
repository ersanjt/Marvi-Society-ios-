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
        try await applyOnboardingMetadata(metadata)
    }

    func signInWithEmail(_ email: String, password: String, metadata: [String: String]) async throws {
        try await client.signInWithEmail(email, password: password)
        if !metadata.isEmpty {
            try await applyOnboardingMetadata(metadata)
        }
    }

    func signUpWithEmail(_ email: String, password: String, metadata: [String: String]) async throws {
        try await client.signUp(email: email, password: password, metadata: metadata)
        try await applyOnboardingMetadata(metadata)
    }

    func signOut() async throws {
        try await client.signOut()
    }

    func restoreSession() async -> Bool {
        await client.restorePersistedSession()
    }

    func refreshSession() async throws {
        try await client.refreshSession()
    }

    func fetchAccountContext() async throws -> AccountContext {
        do {
            let rows: [AccountContextRow] = try await client.rpc(
                function: "fetch_account_context",
                body: [:]
            )
            if let row = rows.first {
                return row.context
            }
        } catch {
            // Migration may not be applied yet — fall back to direct profile read.
        }

        return try await fetchAccountContextFromProfiles()
    }

    func fetchAccountRole() async throws -> UserRole {
        try await fetchAccountContext().role
    }

    func fetchMembershipStatus() async throws -> MembershipStatus? {
        try await fetchAccountContext().membershipStatus
    }

    private func fetchAccountContextFromProfiles() async throws -> AccountContext {
        let rows: [ProfileRoleRow] = try await client.select(
            table: "profiles",
            query: [
                URLQueryItem(name: "select", value: "role,status,email"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        let role = rows.first?.role.flatMap(UserRole.fromAPI) ?? .creator
        let status = MembershipStatus.fromAPI(rows.first?.status)
        let hasVenue = try await hasVenueProfile()
        return AccountContext(role: role, membershipStatus: status, hasVenueProfile: hasVenue)
    }

    // MARK: - Read

    func fetchOffers(city: String) async throws -> [Offer] {
        // `offers_public` view: live offers from approved venues with venue_name + area joined.
        var query: [URLQueryItem] = [
            URLQueryItem(name: "order", value: "created_at.desc")
        ]

        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmedCity.isEmpty, trimmedCity != "istanbul" {
            query.append(URLQueryItem(name: "area", value: "ilike.*\(trimmedCity)*"))
        }

        let rows: [OfferRow] = try await client.select(table: "offers_public", query: query)
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
        if let profile = try await loadCreatorProfileRow() {
            return profile
        }

        do {
            let _: CreatorProfileHealRow = try await client.rpc(
                function: "ensure_creator_profile",
                body: [:]
            )
        } catch {
            // Migration may not be applied yet; retry read before failing.
        }

        if let profile = try await loadCreatorProfileRow() {
            return profile
        }

        throw MarviAPIError.server(message: "Creator profile could not be loaded. Please contact support.")
    }

    private func loadCreatorProfileRow() async throws -> CreatorProfile? {
        let rows: [CreatorProfileRow] = try await client.select(
            table: "creator_profiles",
            query: [URLQueryItem(name: "limit", value: "1")]
        )
        return rows.first?.toProfile()
    }

    func updateProfile(_ profile: CreatorProfile) async throws {
        guard let userID = await client.currentUserID() else {
            throw MarviAPIError.notAuthenticated
        }

        try await client.patch(
            table: "creator_profiles",
            query: [URLQueryItem(name: "user_id", value: "eq.\(userID)")],
            body: [
                "instagram_handle": profile.handle,
                "tiktok_handle": profile.tiktokHandle,
                "city": profile.city.lowercased(),
                "full_name": profile.name,
                "niches": profile.niches,
                "languages": profile.languages
            ]
        )
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

    func fetchCampaigns() async throws -> [Campaign] {
        guard let venue = try await fetchVenueSummary() else { return [] }

        let rows: [CampaignOfferRow] = try await client.select(
            table: "offers",
            query: [
                URLQueryItem(name: "select", value: "*,venue_profiles(venue_name,area)"),
                URLQueryItem(name: "venue_id", value: "eq.\(venue.id.uuidString)"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )
        return rows.map { $0.toCampaign() }
    }

    func createCampaign(_ input: CreateCampaignInput) async throws -> Campaign {
        guard let venue = try await fetchVenueSummary() else {
            throw MarviAPIError.server(message: "No venue profile linked to this account.")
        }

        struct OfferIDRow: Decodable { let id: UUID }

        let row: OfferIDRow = try await client.rpc(
            function: "submit_campaign_for_review",
            body: [
                "p_title": input.title,
                "p_category": input.category.apiValue,
                "p_model": input.collaborationModel.apiValue,
                "p_date_label": input.dateLabel,
                "p_value_label": input.valueLabel,
                "p_slots": input.slots,
                "p_deliverables": input.deliverables
            ]
        )

        return Campaign(
            id: row.id,
            title: input.title,
            venueName: venue.venueName,
            area: venue.area,
            category: input.category,
            dateLabel: input.dateLabel,
            valueLabel: input.valueLabel,
            slots: input.slots,
            matchedCreators: 0,
            status: .review,
            deliverables: input.deliverables
        )
    }

    func fetchVenueSummary() async throws -> VenueSummary? {
        let rows: [VenueProfileRow] = try await client.select(
            table: "venue_profiles",
            query: [URLQueryItem(name: "limit", value: "1")]
        )
        return rows.first?.toSummary()
    }

    func hasVenueProfile() async throws -> Bool {
        try await fetchVenueSummary() != nil
    }

    // MARK: - Write

    func acceptOffer(_ offerID: UUID) async throws -> Booking {
        let row: BookingRPCRow = try await client.rpc(
            function: "accept_offer",
            body: ["p_offer_id": offerID.uuidString]
        )
        let bookings = try await fetchBookings()
        guard let booking = bookings.first(where: { $0.id == row.id }) else {
            throw MarviAPIError.server(message: "Booking not found after accept")
        }
        return booking
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
        try await client.rpcVoid(
            function: "resolve_admin_task",
            body: [
                "p_task_id": taskID.uuidString,
                "p_action": "approve"
            ]
        )
    }

    func rejectTask(_ taskID: UUID) async throws {
        try await client.rpcVoid(
            function: "resolve_admin_task",
            body: [
                "p_task_id": taskID.uuidString,
                "p_action": "reject"
            ]
        )
    }

    func fetchSwipeCandidates(offerID: UUID?) async throws -> [InfluencerCandidate] {
        var body: [String: Any] = [:]
        if let offerID {
            body["p_offer_id"] = offerID.uuidString
        }
        let rows: [SwipeCandidateRow] = try await client.rpc(
            function: "fetch_swipe_candidates",
            body: body
        )
        return rows.map(\.candidate)
    }

    func shortlistCreator(_ creatorID: UUID, offerID: UUID?) async throws {
        var body: [String: Any] = ["p_creator_id": creatorID.uuidString]
        if let offerID {
            body["p_offer_id"] = offerID.uuidString
        }
        try await client.rpcVoid(function: "shortlist_creator", body: body)
    }

    func passCreator(_ creatorID: UUID, offerID: UUID?) async throws {
        var body: [String: Any] = ["p_creator_id": creatorID.uuidString]
        if let offerID {
            body["p_offer_id"] = offerID.uuidString
        }
        try await client.rpcVoid(function: "pass_creator", body: body)
    }

    func fetchVenueReviewQueue() async throws -> [VenueReviewItem] {
        let rows: [VenueReviewRow] = try await client.rpc(
            function: "fetch_venue_review_queue",
            body: [:]
        )
        return rows.map(\.item)
    }

    func submitVenueReview(
        bookingID: UUID,
        punctuality: Int,
        presentation: Int,
        comment: String
    ) async throws {
        try await client.rpcVoid(
            function: "submit_venue_review",
            body: [
                "p_booking_id": bookingID.uuidString,
                "p_punctuality": punctuality,
                "p_presentation": presentation,
                "p_comment": comment
            ]
        )
    }

    func issueStrikeForBooking(bookingID: UUID, reason: String) async throws {
        try await client.rpcVoid(
            function: "issue_strike_for_booking",
            body: [
                "p_booking_id": bookingID.uuidString,
                "p_reason": reason,
                "p_severity": "medium"
            ]
        )
    }

    func validateReferralCode(_ code: String) async throws -> Bool {
        let rows: [ReferralRow] = try await client.select(
            table: "referral_codes",
            query: [
                URLQueryItem(name: "select", value: "code"),
                URLQueryItem(name: "code", value: "eq.\(code.uppercased())"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        return !rows.isEmpty
    }

    func redeemReferralCode(_ code: String) async throws {
        try await client.rpcVoid(
            function: "redeem_referral_code",
            body: ["p_code": code.uppercased()]
        )
    }

    func fetchStrikes() async throws -> [Strike] {
        let rows: [StrikeRow] = try await client.select(
            table: "strikes",
            query: [URLQueryItem(name: "order", value: "created_at.desc")]
        )
        return rows.map { $0.toStrike() }
    }

    func uploadProofImage(bookingID: UUID, imageData: Data, fileName: String) async throws -> String {
        guard let userID = await client.currentUserID() else {
            throw MarviAPIError.server(message: "Not authenticated")
        }
        let path = "\(userID)/\(bookingID.uuidString)/\(fileName)"
        return try await client.uploadObject(
            bucket: "proof-uploads",
            path: path,
            data: imageData,
            contentType: "image/jpeg"
        )
    }

    func issueStrike(creatorID: UUID, bookingID: UUID?, reason: String) async throws {
        var body: [String: Any] = [
            "creator_id": creatorID.uuidString,
            "reason": reason,
            "severity": "medium"
        ]
        if let bookingID {
            body["booking_id"] = bookingID.uuidString
        }
        try await client.insert(table: "strikes", body: body)
    }

    // MARK: - Private

    private func applyOnboardingMetadata(_ metadata: [String: String]) async throws {
        guard let userID = await client.currentUserID() else { return }

        var body: [String: Any] = [:]
        if let handle = metadata["instagram_handle"] {
            body["instagram_handle"] = handle
        }
        if let city = metadata["city"] {
            body["city"] = city.lowercased()
        }
        if let name = metadata["full_name"], !name.isEmpty {
            body["full_name"] = name
        }
        guard !body.isEmpty else { return }

        try await client.patch(
            table: "creator_profiles",
            query: [URLQueryItem(name: "user_id", value: "eq.\(userID)")],
            body: body
        )
    }
}

private struct ProfileRoleRow: Decodable {
    let role: String?
    let status: String?
    let email: String?
}

private struct AccountContextRow: Decodable {
    let role: String
    let status: String?
    let has_venue_profile: Bool?

    var context: AccountContext {
        AccountContext(
            role: UserRole.fromAPI(role) ?? .creator,
            membershipStatus: MembershipStatus.fromAPI(status),
            hasVenueProfile: has_venue_profile ?? false
        )
    }
}

private struct CreatorProfileHealRow: Decodable {
    let user_id: UUID
}

private struct ReferralRow: Decodable {
    let code: String
}

private struct StrikeRow: Decodable {
    let id: UUID
    let reason: String
    let severity: String
    let created_at: String

    func toStrike() -> Strike {
        Strike(
            id: id,
            reason: reason,
            severity: severity,
            createdAtLabel: created_at.prefix(10).description
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
        let lat: Double?
        let lng: Double?
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
            collaborationModel: CollaborationModel.fromAPI(nested.model),
            latitude: nested.lat,
            longitude: nested.lng
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

private struct SwipeCandidateRow: Decodable {
    let creator_id: UUID
    let full_name: String
    let instagram_handle: String
    let audience_count: Int
    let score: Double
    let proof_rate: Double
    let niches: [String]?

    var candidate: InfluencerCandidate {
        let niche = niches?.first ?? "Creator"
        let punctuality = min(99, max(60, Int(proof_rate)))
        let presentation = min(99, max(60, Int(score)))
        let followers: String
        if audience_count >= 1000 {
            followers = String(format: "%.1fK", Double(audience_count) / 1000)
        } else {
            followers = "\(audience_count)"
        }
        return InfluencerCandidate(
            id: creator_id,
            name: full_name.isEmpty ? instagram_handle : full_name,
            niche: niche,
            score: Int(score),
            punctuality: punctuality,
            presentation: presentation,
            followers: followers
        )
    }
}

private struct VenueReviewRow: Decodable {
    let booking_id: UUID
    let creator_name: String
    let instagram_handle: String
    let offer_title: String
    let stage: String
    let proof_status: String?
    let checked_in_label: String
    let has_review: Bool?

    var item: VenueReviewItem {
        VenueReviewItem(
            id: booking_id,
            creatorName: creator_name,
            instagramHandle: instagram_handle,
            offerTitle: offer_title,
            stage: BookingStage.fromAPI(stage),
            proofStatus: ProofStatus.fromAPI(proof_status),
            stageLabel: stage.replacingOccurrences(of: "_", with: " ").capitalized,
            checkedInLabel: checked_in_label,
            hasReview: has_review ?? false
        )
    }
}
