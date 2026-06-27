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

    func signInWithGoogle(accessToken: String, refreshToken: String?, metadata: [String: String]) async throws {
        try await client.signInWithOAuth(accessToken: accessToken, refreshToken: refreshToken)
        try await applyOnboardingMetadata(metadata)
    }

    func signInWithEmail(_ email: String, password: String, metadata: [String: String]) async throws {
        try await client.signInWithEmail(email, password: password)
        if !metadata.isEmpty {
            try await applyOnboardingMetadata(metadata)
        }
    }

    func signUpWithEmail(_ email: String, password: String, metadata: [String: String]) async throws {
        let sessionCreated = try await client.signUp(email: email, password: password, metadata: metadata)
        guard sessionCreated else {
            // Supabase has email confirmation enabled: no session yet.
            throw MarviAPIError.emailConfirmationRequired
        }
        try await applyOnboardingMetadata(metadata)
    }

    func resetPassword(_ email: String) async throws {
        try await client.resetPassword(email: email)
    }

    func pauseOwnAccount() async throws {
        try await client.rpcVoid(function: "pause_own_account", body: [:])
    }

    func reactivateOwnAccount() async throws {
        try await client.rpcVoid(function: "reactivate_own_account", body: [:])
    }

    func deleteOwnAccountPermanently() async throws {
        _ = try await client.invokeFunction(
            name: "delete-own-account",
            body: ["confirm": "DELETE"]
        )
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
                let base = row.context
                if let profileContext = try? await fetchAccountContextFromProfiles() {
                    return AccountContext(
                        role: base.role,
                        membershipStatus: base.membershipStatus ?? profileContext.membershipStatus,
                        hasVenueProfile: base.hasVenueProfile || profileContext.hasVenueProfile,
                        referralCode: profileContext.referralCode,
                        pausedBySelf: profileContext.pausedBySelf
                    )
                }
                return base
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
                URLQueryItem(name: "select", value: "role,status,email,referral_code,paused_by_self"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        let role = rows.first?.role.flatMap(UserRole.fromAPI) ?? .creator
        let status = MembershipStatus.fromAPI(rows.first?.status)
        let hasVenue = try await hasVenueProfile()
        return AccountContext(
            role: role,
            membershipStatus: status,
            hasVenueProfile: hasVenue,
            referralCode: rows.first?.referral_code,
            pausedBySelf: rows.first?.paused_by_self ?? false
        )
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
                "bio": profile.bio,
                "niches": profile.niches,
                "languages": profile.languages
            ]
        )

        let locale: String = {
            if profile.languages.contains(where: { $0.lowercased().contains("turk") }) { return "tr" }
            let city = profile.city.lowercased()
            if city.contains("istanbul") || ["kadıköy", "kadikoy", "beşiktaş", "besiktas"].contains(city) {
                return "tr"
            }
            return "en"
        }()

        try await client.patch(
            table: "profiles",
            query: [URLQueryItem(name: "id", value: "eq.\(userID)")],
            body: ["preferred_locale": locale]
        )
    }

    func fetchNotifications() async throws -> [InboxMessage] {
        let rows: [NotificationRow] = try await client.select(
            table: "notifications",
            query: [URLQueryItem(name: "order", value: "created_at.desc")]
        )
        return rows.map { $0.toMessage() }
    }

    func markNotificationRead(_ id: UUID) async throws {
        try await client.rpcVoid(
            function: "mark_notification_read",
            body: ["p_notification_id": id.uuidString]
        )
    }

    func registerDeviceToken(_ token: String, platform: String) async throws {
        try await client.rpcVoid(
            function: "register_device_token",
            body: [
                "p_token": token,
                "p_platform": platform
            ]
        )
    }

    func trackEvent(_ name: String, properties: [String: String]) async throws {
        try await client.rpcVoid(
            function: "track_analytics_event",
            body: [
                "p_name": name,
                "p_properties": properties
            ]
        )
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

    func fetchCreatorProfile(userID: UUID) async throws -> CreatorProfile? {
        let rows: [CreatorProfileRow] = try await client.select(
            table: "creator_profiles",
            query: [URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)")]
        )
        return rows.first?.toProfile()
    }

    func fetchVenueProfile(id: UUID) async throws -> VenueSummary? {
        let rows: [VenueProfileRow] = try await client.select(
            table: "venue_profiles",
            query: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")]
        )
        return rows.first?.toSummary()
    }

    func fetchCampaigns() async throws -> [Campaign] {
        let rows: [CampaignOfferRow] = try await client.select(
            table: "offers",
            query: [
                URLQueryItem(name: "select", value: "*,venue_profiles(venue_name,area)"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )
        return rows.map { $0.toCampaign() }
    }

    func createCampaign(_ input: CreateCampaignInput, venueID: UUID?) async throws -> Campaign {
        guard let venue = try await fetchVenueSummary() else {
            throw MarviAPIError.server(message: "No venue profile linked to this account.")
        }

        var body: [String: Any] = [
            "p_title": input.title,
            "p_category": input.category.apiValue,
            "p_model": input.collaborationModel.apiValue,
            "p_date_label": input.dateLabel,
            "p_value_label": input.valueLabel,
            "p_slots": input.slots,
            "p_deliverables": input.deliverables
        ]
        if let venueID {
            body["p_venue_id"] = venueID.uuidString
        }

        struct OfferIDRow: Decodable { let id: UUID }

        let row: OfferIDRow
        do {
            row = try await client.rpc(function: "submit_campaign_for_review", body: body)
        } catch {
            guard venueID != nil else { throw error }
            var legacyBody = body
            legacyBody.removeValue(forKey: "p_venue_id")
            row = try await client.rpc(function: "submit_campaign_for_review", body: legacyBody)
        }

        let targetVenue: VenueSummary
        if let venueID, venueID != venue.id, let selected = try await fetchVenueProfile(id: venueID) {
            targetVenue = selected
        } else {
            targetVenue = venue
        }

        return Campaign(
            id: row.id,
            title: input.title,
            venueName: targetVenue.venueName,
            area: targetVenue.area,
            category: input.category,
            dateLabel: input.dateLabel,
            valueLabel: input.valueLabel,
            slots: input.slots,
            matchedCreators: 0,
            status: .review,
            deliverables: input.deliverables
        )
    }

    func fetchMyVenues() async throws -> [VenueSummary] {
        do {
            let rows: [MyVenueRow] = try await client.rpc(
                function: "fetch_my_venues",
                body: [:]
            )
            return rows.map { $0.toSummary() }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            guard message.lowercased().contains("could not find the function") else {
                throw error
            }

            guard let userID = await client.currentUserID() else { return [] }
            let rows: [VenueProfileRow] = try await client.select(
                table: "venue_profiles",
                query: [
                    URLQueryItem(name: "owner_user_id", value: "eq.\(userID)"),
                    URLQueryItem(name: "order", value: "created_at.asc")
                ]
            )
            return rows.enumerated().map { index, row in
                row.toSummary(isActive: index == 0)
            }
        }
    }

    func setActiveVenue(_ venueID: UUID) async throws {
        do {
            try await client.rpcVoid(
                function: "set_active_venue",
                body: ["p_venue_id": venueID.uuidString]
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if message.lowercased().contains("could not find the function") {
                return
            }
            throw error
        }
    }

    func registerVenueLocation(_ input: RegisterVenueInput) async throws -> VenueSummary {
        do {
            let venueID: UUID = try await client.rpc(
                function: "register_venue_location",
                body: [
                    "p_venue_name": input.venueName,
                    "p_area": input.area,
                    "p_category": input.category.apiValue,
                    "p_address": input.address,
                    "p_contact_name": input.contactName,
                    "p_contact_phone": input.contactPhone
                ]
            )

            guard let venue = try await fetchVenueProfile(id: venueID) else {
                throw MarviAPIError.server(message: "Venue created but could not be loaded.")
            }
            return venue
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            guard message.lowercased().contains("could not find the function") else {
                throw error
            }

            struct VenueIDRow: Decodable { let id: UUID }
            let row: VenueIDRow = try await client.insertReturning(
                table: "venue_profiles",
                body: [
                    "venue_name": input.venueName,
                    "area": input.area,
                    "category": input.category.apiValue,
                    "address": input.address,
                    "contact_name": input.contactName,
                    "contact_phone": input.contactPhone,
                    "status": "under_review"
                ]
            )

            try await client.insert(
                table: "admin_tasks",
                body: [
                    "type": "venue_application",
                    "subject_id": row.id.uuidString,
                    "title": input.venueName,
                    "subtitle": "\(input.area) · new location on existing account",
                    "priority": "High",
                    "status": "open"
                ]
            )

            guard let venue = try await fetchVenueProfile(id: row.id) else {
                throw MarviAPIError.server(message: "Venue created but could not be loaded.")
            }
            return venue
        }
    }

    func fetchVenueSummary() async throws -> VenueSummary? {
        let venues = try await fetchMyVenues()
        if let active = venues.first(where: \.isActive) {
            return active
        }
        return venues.first
    }

    func hasVenueProfile() async throws -> Bool {
        !(try await fetchMyVenues()).isEmpty
    }

    // MARK: - Write

    func acceptOffer(_ offerID: UUID, options: AcceptOfferOptions = AcceptOfferOptions()) async throws -> Booking {
        var body: [String: Any] = ["p_offer_id": offerID.uuidString]
        if let shippingAddress = options.shippingAddress?.trimmingCharacters(in: .whitespacesAndNewlines),
           !shippingAddress.isEmpty {
            body["p_shipping_address"] = shippingAddress
        }
        if let rsvpGuests = options.rsvpGuests {
            body["p_rsvp_guests"] = rsvpGuests
        }

        let row: BookingRPCRow = try await client.rpc(
            function: "accept_offer",
            body: body
        )
        let bookings = try await fetchBookings()
        if let booking = bookings.first(where: { $0.id == row.id }) {
            return booking
        }

        // Join can fail if nested offer data is missing — build from RPC row + live offers.
        let offers = try await fetchOffers(city: "istanbul")
        if let offer = offers.first(where: { $0.id == offerID }) {
            return row.toBooking(offer: offer)
        }

        throw MarviAPIError.server(message: "Booking not found after accept")
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
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return false }

        let filterValue = postgrestEqualsFilter(normalized)
        let rows: [ReferralRow] = try await client.select(
            table: "referral_codes",
            query: [
                URLQueryItem(name: "select", value: "code,uses_count,max_uses"),
                URLQueryItem(name: "code", value: filterValue),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let row = rows.first else { return false }
        if let maxUses = row.max_uses, row.uses_count >= maxUses { return false }
        return true
    }

    private func postgrestEqualsFilter(_ value: String) -> String {
        let needsQuotes = value.contains { !$0.isLetter && !$0.isNumber }
        if needsQuotes {
            return "eq.\"\(value)\""
        }
        return "eq.\(value)"
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

    func upsertUserLocation(lat: Double, lng: Double) async throws {
        try await client.rpcVoid(
            function: "upsert_user_location",
            body: ["p_lat": lat, "p_lng": lng]
        )
    }

    func fetchAdminUsers(search: String?, status: String?) async throws -> [AdminUserSummary] {
        var body: [String: Any] = ["p_limit": 100]
        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["p_search"] = search
        }
        if let status, !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["p_status"] = status
        }
        let rows: [AdminUserSummary] = try await client.rpc(
            function: "admin_list_users",
            body: body,
            type: [AdminUserSummary].self,
            decoder: Self.adminDecoder
        )
        return rows
    }

    func fetchAdminUserDetail(userID: UUID) async throws -> AdminUserDetail {
        try await client.rpc(
            function: "admin_get_user_detail",
            body: ["p_user_id": userID.uuidString],
            type: AdminUserDetail.self,
            decoder: Self.adminDecoder
        )
    }

    func adminSetMembershipStatus(userID: UUID, status: String) async throws {
        try await client.rpcVoid(
            function: "admin_set_membership_status",
            body: [
                "p_user_id": userID.uuidString,
                "p_status": status
            ]
        )
    }

    func adminSendNotification(userID: UUID, title: String, body: String) async throws {
        try await client.rpcVoid(
            function: "admin_send_notification",
            body: [
                "p_user_id": userID.uuidString,
                "p_title": title,
                "p_body": body,
                "p_type": "admin"
            ]
        )
    }

    func adminSendEmail(userID: UUID, subject: String, body: String) async throws {
        _ = try await client.rpcVoid(
            function: "admin_send_email",
            body: [
                "p_user_id": userID.uuidString,
                "p_subject": subject,
                "p_body": body
            ]
        )
    }

    func adminSendInvite(email: String, inviteCode: String?) async throws -> AdminInviteResult {
        var body: [String: Any] = [
            "p_email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "p_max_uses": 1
        ]
        if let inviteCode, !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["p_invite_code"] = inviteCode.uppercased()
        }
        return try await client.rpc(
            function: "admin_send_invite",
            body: body,
            type: AdminInviteResult.self,
            decoder: Self.adminDecoder
        )
    }

    func adminNotifyUsersInRadius(lat: Double, lng: Double, radiusKm: Double, title: String, body: String) async throws -> Int {
        try await client.rpc(
            function: "admin_notify_users_in_radius",
            body: [
                "p_lat": lat,
                "p_lng": lng,
                "p_radius_km": radiusKm,
                "p_title": title,
                "p_body": body
            ],
            type: Int.self,
            decoder: Self.adminDecoder
        )
    }

    func adminCreateUser(
        email: String,
        password: String?,
        fullName: String,
        city: String,
        autoApprove: Bool
    ) async throws -> AdminProvisionResult {
        var body: [String: Any] = [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "full_name": fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            "city": city.trimmingCharacters(in: .whitespacesAndNewlines),
            "auto_approve": autoApprove,
            "send_welcome_email": true
        ]
        if let password, !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["password"] = password
        }

        let data = try await client.invokeFunction(name: "admin-provision-user", body: body)
        let response = try JSONDecoder().decode(AdminProvisionResponse.self, from: data)
        return AdminProvisionResult(
            userID: response.userID,
            email: response.email,
            temporaryPassword: response.temporaryPassword,
            autoApproved: response.autoApproved
        )
    }

    private static let adminDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Private

    private func applyOnboardingMetadata(_ metadata: [String: String]) async throws {
        guard let userID = await client.currentUserID() else { return }

        var creatorBody: [String: Any] = [:]
        var profileBody: [String: Any] = [:]

        if let handle = metadata["instagram_handle"] {
            creatorBody["instagram_handle"] = handle
        }
        if let city = metadata["city"] {
            creatorBody["city"] = city.lowercased()
        }
        if let name = metadata["full_name"], !name.isEmpty {
            creatorBody["full_name"] = name
        }
        if let locale = metadata["locale"], !locale.isEmpty {
            profileBody["preferred_locale"] = locale.lowercased().hasPrefix("tr") ? "tr" : "en"
        }

        if !creatorBody.isEmpty {
            try await client.patch(
                table: "creator_profiles",
                query: [URLQueryItem(name: "user_id", value: "eq.\(userID)")],
                body: creatorBody
            )
        }

        if !profileBody.isEmpty {
            try await client.patch(
                table: "profiles",
                query: [URLQueryItem(name: "id", value: "eq.\(userID)")],
                body: profileBody
            )
        }
    }
}

private struct ProfileRoleRow: Decodable {
    let role: String?
    let status: String?
    let email: String?
    let referral_code: String?
    let paused_by_self: Bool?
}

private struct AccountContextRow: Decodable {
    let role: String
    let status: String?
    let has_venue_profile: Bool?

    var context: AccountContext {
        AccountContext(
            role: UserRole.fromAPI(role) ?? .creator,
            membershipStatus: MembershipStatus.fromAPI(status),
            hasVenueProfile: has_venue_profile ?? false,
            referralCode: nil,
            pausedBySelf: false
        )
    }
}

private struct AdminProvisionResponse: Decodable {
    let userID: UUID
    let email: String
    let temporaryPassword: String?
    let autoApproved: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case temporaryPassword = "temporary_password"
        case autoApproved = "auto_approved"
    }
}

private struct CreatorProfileHealRow: Decodable {
    let user_id: UUID
}

private struct ReferralRow: Decodable {
    let code: String
    let uses_count: Int
    let max_uses: Int?
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
