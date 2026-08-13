package com.marvisociety.app.network

import com.marvisociety.app.data.*
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class MarviRepository(private val client: SupabaseClient = SupabaseClient()) {
    fun setSessionObserver(observer: suspend (String?, String?) -> Unit) =
        client.setSessionObserver(observer)
    val usesRemoteBackend: Boolean get() = client.usesRemoteBackend
    val isAuthenticated: Boolean get() = client.isAuthenticated

    fun restoreSession(access: String?, refresh: String?) {
        if (!access.isNullOrBlank()) client.setSession(access, refresh)
    }

    suspend fun signInWithEmail(email: String, password: String) = client.signInWithEmail(email, password)
    suspend fun signUpWithEmail(email: String, password: String, metadata: Map<String, String>) =
        client.signUpWithEmail(email, password, metadata)
    suspend fun resetPassword(email: String) = client.resetPassword(email)
    suspend fun signOut() = client.signOut()
    suspend fun refreshSession() = client.refreshSession()
    fun currentUserId(): String? = client.currentUserId()
    fun accessToken(): String? = client.accessToken
    fun refreshToken(): String? = client.refreshToken
    fun supabaseClient(): SupabaseClient = client

    suspend fun <T> withAuthRetry(block: suspend () -> T): T = client.withAuthRetry(block)

    suspend fun deleteOwnAccountPermanently() {
        client.invokeFunction(
            "delete-own-account",
            buildJsonObject { put("confirm", "DELETE") }
        )
        client.clearSession()
    }

    suspend fun completeGoogleOAuth(uri: android.net.Uri, context: android.content.Context): GoogleOAuth.Completion =
        GoogleOAuth.completeIfPossible(uri, client, context)
            ?: throw MarviApiException("Not a Google auth callback")

    suspend fun fetchAccountContext(): AccountContext {
        // `fetch_account_context` RETURNS TABLE(role, status, has_venue_profile) → PostgREST array.
        val obj = runCatching {
            client.rpcJson("fetch_account_context", buildJsonObject { })
                .asArrayOrEmpty().firstOrNull()?.asObjectOrNull()
        }.getOrNull() ?: return fetchAccountContextFromProfiles()

        // referral_code + paused_by_self are not returned by the RPC — read them from profiles.
        val profile = runCatching { fetchProfileRow() }.getOrNull()
        return AccountContext(
            role = UserRole.fromApi(obj.string("role")) ?: UserRole.CREATOR,
            membershipStatus = membershipFromApi(obj.string("status"))
                ?: profile?.let { membershipFromApi(it.string("status")) },
            hasVenueProfile = obj.bool("has_venue_profile") == true,
            referralCode = profile?.string("referral_code"),
            pausedBySelf = profile?.bool("paused_by_self") == true
        )
    }

    private suspend fun fetchProfileRow(): JsonObject? {
        // Admins can SELECT every profiles row; always scope to the signed-in user.
        val userId = client.currentUserId() ?: return null
        val rows = client.select(
            "profiles",
            mapOf(
                "select" to "role,status,referral_code,paused_by_self",
                "id" to "eq.$userId",
                "limit" to "1"
            )
        ) { it.asArrayOrEmpty() }
        return rows.firstOrNull()?.asObjectOrNull()
    }

    private suspend fun fetchAccountContextFromProfiles(): AccountContext {
        val obj = fetchProfileRow() ?: return AccountContext()
        return AccountContext(
            role = UserRole.fromApi(obj.string("role")) ?: UserRole.CREATOR,
            membershipStatus = membershipFromApi(obj.string("status")),
            hasVenueProfile = runCatching { fetchMyVenues().isNotEmpty() }.getOrDefault(false),
            referralCode = obj.string("referral_code"),
            pausedBySelf = obj.bool("paused_by_self") == true
        )
    }

    suspend fun fetchOffers(city: String): List<Offer> {
        val query = mutableMapOf("order" to "created_at.desc")
        val trimmed = city.trim().lowercase()
        if (trimmed.isNotEmpty() && trimmed != "istanbul") {
            query["area"] = "ilike.*$trimmed*"
        }
        val rows = client.select("offers_public", query) { it.asArrayOrEmpty() }
        return rows.mapNotNull { parseOffer(it) }
    }

    suspend fun fetchBookings(): List<Booking> {
        val rows = client.select(
            "bookings",
            mapOf(
                "select" to "*,offers(*,venue_profiles(venue_name,area))",
                "order" to "created_at.desc"
            )
        ) { it.asArrayOrEmpty() }
        return rows.mapNotNull { parseBooking(it) }
    }

    suspend fun fetchProfile(): CreatorProfile {
        // Admins can SELECT every creator_profiles row via RLS. An unscoped
        // `limit=1` often returns someone else's row, so edits/photos look like
        // they never saved after refresh.
        val userId = client.currentUserId() ?: throw MarviApiException("Not authenticated")
        suspend fun loadOwn(): JsonElement? =
            client.select(
                "creator_profiles",
                mapOf("user_id" to "eq.$userId", "limit" to "1")
            ) { it.asArrayOrEmpty() }.firstOrNull()

        loadOwn()?.let { return parseCreatorProfile(it) }

        runCatching {
            client.rpcJson("ensure_creator_profile", buildJsonObject { })
        }

        val row = loadOwn() ?: return CreatorProfile()
        return parseCreatorProfile(row)
    }

    suspend fun updateProfile(profile: CreatorProfile) {
        client.currentUserId() ?: throw MarviApiException("Not authenticated")
        try {
            client.rpcJson(
                "upsert_my_creator_profile",
                buildJsonObject {
                    put("p_full_name", profile.name)
                    put("p_instagram_handle", profile.handle.removePrefix("@"))
                    put("p_tiktok_handle", profile.tiktokHandle.removePrefix("@"))
                    put("p_city", profile.city.lowercase())
                    put("p_bio", profile.bio)
                    putJsonArray("p_niches") { profile.niches.forEach { add(it) } }
                    putJsonArray("p_languages") { profile.languages.forEach { add(it) } }
                    if (profile.avatarUrl.isNotBlank()) put("p_avatar_url", profile.avatarUrl)
                    if (profile.coverUrl.isNotBlank()) put("p_cover_url", profile.coverUrl)
                }
            )
        } catch (first: Exception) {
            // Fallback when migration is not applied yet.
            val userId = client.currentUserId() ?: throw MarviApiException("Not authenticated")
            client.patch(
                table = "creator_profiles",
                filters = mapOf("user_id" to "eq.$userId"),
                body = buildJsonObject {
                    put("full_name", profile.name)
                    put("instagram_handle", profile.handle.removePrefix("@"))
                    put("tiktok_handle", profile.tiktokHandle.removePrefix("@"))
                    put("city", profile.city.lowercase())
                    put("bio", profile.bio)
                    put("niches", JsonArray(profile.niches.map { kotlinx.serialization.json.JsonPrimitive(it) }))
                    put("languages", JsonArray(profile.languages.map { kotlinx.serialization.json.JsonPrimitive(it) }))
                    if (profile.avatarUrl.isNotBlank()) put("avatar_url", profile.avatarUrl)
                    if (profile.coverUrl.isNotBlank()) put("cover_url", profile.coverUrl)
                },
                requireRows = true
            )
        }
    }

    suspend fun setMyProfileImage(kind: String, url: String) {
        val trimmed = url.trim()
        if (trimmed.isEmpty()) throw MarviApiException("Photo URL missing after upload.")
        try {
            client.rpcJson(
                "set_my_profile_image",
                buildJsonObject {
                    put("p_kind", kind)
                    put("p_url", trimmed)
                }
            )
        } catch (first: Exception) {
            val userId = client.currentUserId() ?: throw MarviApiException("Not authenticated")
            val column = if (kind == "cover") "cover_url" else "avatar_url"
            client.patch(
                table = "creator_profiles",
                filters = mapOf("user_id" to "eq.$userId"),
                body = buildJsonObject { put(column, trimmed) },
                requireRows = true
            )
        }
    }

    /** Uploads to private `proof-uploads` and returns the relative storage path for `p_links`. */
    suspend fun uploadProofImage(bookingId: String, imageData: ByteArray, fileName: String): String {
        val userId = client.currentUserId() ?: throw MarviApiException("Not authenticated")
        val path = "$userId/$bookingId/$fileName"
        return client.uploadObject(
            bucket = "proof-uploads",
            path = path,
            data = imageData,
            contentType = "image/jpeg"
        )
    }

    /** Uploads to public `profile-media` and returns a cache-busted public URL. */
    suspend fun uploadProfileImage(imageData: ByteArray, fileName: String, kind: String): String {
        val userId = client.currentUserId() ?: throw MarviApiException("Not authenticated")
        val unique = "${System.currentTimeMillis()}-$fileName"
        val path = "$userId/$kind/$unique"
        client.uploadObject(
            bucket = "profile-media",
            path = path,
            data = imageData,
            contentType = "image/jpeg"
        )
        return client.publicStorageUrl("profile-media", path)
    }

    /** Uploads campaign cover to public `venue-media` and returns a cache-busted public URL. */
    suspend fun uploadVenueCampaignImage(venueId: String, imageData: ByteArray, fileName: String): String {
        val userId = client.currentUserId() ?: throw MarviApiException("Not authenticated")
        val path = "$userId/$venueId/campaigns/${System.currentTimeMillis()}-$fileName"
        client.uploadObject(
            bucket = "venue-media",
            path = path,
            data = imageData,
            contentType = "image/jpeg"
        )
        return client.publicStorageUrl("venue-media", path)
    }

    suspend fun createCampaign(
        title: String,
        category: String,
        model: String,
        dateLabel: String,
        valueLabel: String,
        slots: Int,
        deliverables: List<String>,
        venueId: String?,
        imageName: String = "",
        description: String = "",
        timeLabel: String = "Flexible",
        requirements: List<String> = emptyList(),
        hostNote: String = ""
    ): String {
        val body = buildJsonObject {
            put("p_title", title)
            put("p_category", category)
            put("p_model", model)
            put("p_date_label", dateLabel)
            put("p_value_label", valueLabel)
            put("p_slots", slots)
            putJsonArray("p_deliverables") { deliverables.forEach { add(it) } }
            if (!venueId.isNullOrBlank()) put("p_venue_id", venueId)
            if (imageName.isNotBlank()) put("p_image_name", imageName)
            if (description.isNotBlank()) put("p_description", description)
            if (timeLabel.isNotBlank()) put("p_time_label", timeLabel)
            if (requirements.isNotEmpty()) {
                putJsonArray("p_requirements") { requirements.forEach { add(it) } }
            }
            if (hostNote.isNotBlank()) put("p_host_note", hostNote)
        }
        val row = client.rpcJson("submit_campaign_for_review", body)
        return row.asObjectOrNull()?.string("id")
            ?: row.toString().trim('"').takeIf { it.isNotBlank() && it != "null" }
            ?: throw MarviApiException("Campaign submit returned empty id")
    }

    suspend fun fetchNotifications(): List<InboxMessage> {
        val userId = client.currentUserId() ?: throw MarviApiException("Not authenticated")
        val rows = client.select(
            "notifications",
            mapOf(
                "user_id" to "eq.$userId",
                "read_at" to "is.null",
                "order" to "created_at.desc",
                "limit" to "100"
            )
        ) { it.asArrayOrEmpty() }
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            val payload = obj["payload"]?.asObjectOrNull()
            InboxMessage(
                id = obj.string("id") ?: return@mapNotNull null,
                title = obj.string("title") ?: "",
                body = obj.string("body") ?: "",
                dateLabel = formatRelative(obj.string("created_at")),
                isRead = false,
                notificationType = obj.string("type") ?: "general",
                icon = obj.string("icon") ?: "bell.fill",
                tint = obj.string("tint") ?: "rose",
                bookingId = obj.string("booking_id") ?: payload?.string("booking_id"),
                offerId = obj.string("offer_id") ?: payload?.string("offer_id"),
                conversationId = payload?.string("conversation_id")
            )
        }
    }

    suspend fun markNotificationRead(id: String) {
        client.rpcVoid("mark_notification_read", buildJsonObject { put("p_notification_id", id) })
    }

    suspend fun markAllNotificationsRead() {
        client.rpcVoid("mark_all_notifications_read", buildJsonObject {})
    }

    suspend fun fetchSavedOfferIds(): Set<String> {
        val rows = client.select("saved_offers", emptyMap()) { it.asArrayOrEmpty() }
        return rows.mapNotNull { it.asObjectOrNull()?.string("offer_id") }.toSet()
    }

    suspend fun toggleSavedOffer(offerId: String): Boolean {
        val result = client.rpcJson(
            "toggle_saved_offer",
            buildJsonObject { put("p_offer_id", offerId) }
        )
        return result.asObjectOrNull()?.bool("saved")
            ?: result.toString().contains("true", ignoreCase = true)
    }

    suspend fun acceptOffer(
        offerId: String,
        options: AcceptOfferOptions = AcceptOfferOptions()
    ): Booking {
        val row = client.rpcJson(
            "accept_offer",
            buildJsonObject {
                put("p_offer_id", offerId)
                val shipping = options.shippingAddress?.trim()
                if (!shipping.isNullOrEmpty()) put("p_shipping_address", shipping)
                options.rsvpGuests?.let { put("p_rsvp_guests", it) }
            }
        )
        return hydrateBooking(row)
    }

    suspend fun cancelBooking(bookingId: String) {
        client.rpcVoid("cancel_booking", buildJsonObject { put("p_booking_id", bookingId) })
    }

    suspend fun venueConfirmBooking(bookingId: String): Booking {
        val row = client.rpcJson(
            "venue_confirm_booking",
            buildJsonObject { put("p_booking_id", bookingId) }
        )
        return hydrateBooking(row)
    }

    suspend fun creatorDeclineCollaboration(requestId: String) {
        client.rpcVoid(
            "creator_decline_collaboration",
            buildJsonObject { put("p_request_id", requestId) }
        )
    }

    suspend fun setActiveVenue(venueId: String) {
        client.rpcVoid(
            "set_active_venue",
            buildJsonObject { put("p_venue_id", venueId) }
        )
    }

    suspend fun adminSetOfferStatus(offerId: String, status: String, reason: String? = null) {
        client.rpcVoid(
            "admin_set_offer_status",
            buildJsonObject {
                put("p_offer_id", offerId)
                put("p_status", status)
                val trimmed = reason?.trim()
                if (!trimmed.isNullOrEmpty()) put("p_reason", trimmed)
            }
        )
    }

    suspend fun submitCreatorReview(
        bookingId: String,
        hospitality: Int,
        experience: Int,
        comment: String
    ) {
        client.rpcVoid(
            "submit_creator_review",
            buildJsonObject {
                put("p_booking_id", bookingId)
                put("p_hospitality", hospitality)
                put("p_experience", experience)
                put("p_comment", comment.trim())
            }
        )
    }

    suspend fun fetchConversations(): List<ChatConversation> {
        val rows = client.rpcJson("get_my_conversations", buildJsonObject { }).asArrayOrEmpty()
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            val id = obj.string("id") ?: return@mapNotNull null
            ChatConversation(
                id = id,
                bookingId = obj.string("booking_id") ?: "",
                offerTitle = obj.string("offer_title") ?: "",
                venueName = obj.string("venue_name") ?: "",
                lastMessage = obj.string("last_message") ?: "",
                lastMessageAt = formatRelative(obj.string("last_message_at") ?: obj.string("created_at"))
            )
        }
    }

    suspend fun fetchConversationMessages(conversationId: String): List<ChatMessage> {
        val rows = client.rpcJson(
            "get_conversation_messages",
            buildJsonObject { put("p_conversation_id", conversationId) }
        ).asArrayOrEmpty()
        val myId = client.currentUserId()
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            val senderId = obj.string("sender_user_id") ?: return@mapNotNull null
            ChatMessage(
                id = obj.string("id") ?: UUID.randomUUID().toString(),
                senderId = senderId,
                body = obj.string("body") ?: "",
                createdLabel = formatRelative(obj.string("created_at")),
                isMine = senderId == myId
            )
        }
    }

    suspend fun sendConversationMessage(conversationId: String, body: String): ChatMessage {
        val row = client.rpcJson(
            "send_message",
            buildJsonObject {
                put("p_conversation_id", conversationId)
                put("p_body", body.trim())
            }
        )
        val obj = row.asObjectOrNull() ?: throw MarviApiException("Invalid message response")
        val senderId = obj.string("sender_user_id") ?: client.currentUserId().orEmpty()
        return ChatMessage(
            id = obj.string("id") ?: UUID.randomUUID().toString(),
            senderId = senderId,
            body = obj.string("body") ?: body,
            createdLabel = formatRelative(obj.string("created_at")),
            isMine = senderId == client.currentUserId()
        )
    }

    suspend fun fetchPendingCollaborationRequests(): List<PendingCollaborationRequest> {
        val rows = client.rpcJson("get_my_pending_collaboration_requests", buildJsonObject { }).asArrayOrEmpty()
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            val id = obj.string("id") ?: return@mapNotNull null
            PendingCollaborationRequest(
                id = id,
                offerId = obj.string("offer_id") ?: "",
                offerTitle = obj.string("offer_title") ?: "",
                venueName = obj.string("venue_name") ?: "",
                status = obj.string("status") ?: "",
                createdLabel = formatRelative(obj.string("created_at"))
            )
        }
    }

    suspend fun creatorAcceptCollaboration(requestId: String): Booking {
        val row = client.rpcJson(
            "creator_accept_collaboration",
            buildJsonObject { put("p_request_id", requestId) }
        )
        return hydrateBooking(row)
    }

    suspend fun checkIn(bookingId: String, code: String): Booking {
        val row = client.rpcJson(
            "check_in_booking",
            buildJsonObject {
                put("p_booking_id", bookingId)
                put("p_code", code.trim())
            }
        )
        return hydrateBooking(row)
    }

    suspend fun submitProof(bookingId: String, links: List<String>): Booking {
        val row = client.rpcJson(
            "submit_proof",
            buildJsonObject {
                put("p_booking_id", bookingId)
                put("p_links", JsonArray(links.map { kotlinx.serialization.json.JsonPrimitive(it) }))
            }
        )
        return hydrateBooking(row)
    }

    // RPC booking rows do not embed the offer join — re-fetch the full booking list to hydrate.
    private suspend fun hydrateBooking(row: JsonElement): Booking {
        val fallback = parseBooking(row)
        val bookingId = row.asObjectOrNull()?.string("id") ?: fallback?.id
        if (bookingId != null) {
            val bookings = runCatching { fetchBookings() }.getOrDefault(emptyList())
            bookings.firstOrNull { it.id == bookingId }?.let { return it }
        }
        return fallback ?: throw MarviApiException("Invalid booking response")
    }

    suspend fun validateReferralCode(code: String): Boolean {
        val normalized = code.trim().uppercase()
        if (normalized.isEmpty()) return false
        return client.rpcBool("validate_referral_code", buildJsonObject { put("p_code", normalized) })
    }

    suspend fun redeemReferralCode(code: String) {
        client.rpcVoid("redeem_referral_code", buildJsonObject { put("p_code", code.trim().uppercase()) })
    }

        suspend fun fetchAdminTasks(): List<AdminTask> {
        val rows = client.select(
            "admin_tasks",
            mapOf(
                "status" to "eq.open",
                "order" to "created_at.desc"
            )
        ) { it.asArrayOrEmpty() }
        return rows.mapNotNull { parseAdminTask(it) }
    }

    suspend fun approveTask(taskId: String) {
        client.rpcVoid(
            "resolve_admin_task",
            buildJsonObject {
                put("p_task_id", taskId)
                put("p_action", "approve")
            }
        )
    }

    suspend fun rejectTask(taskId: String) {
        client.rpcVoid(
            "resolve_admin_task",
            buildJsonObject {
                put("p_task_id", taskId)
                put("p_action", "reject")
            }
        )
    }

    suspend fun fetchAdminUsers(search: String?, status: String?): List<AdminUserSummary> {
        val body = buildJsonObject {
            put("p_limit", 50)
            if (!search.isNullOrBlank()) put("p_search", search.trim())
            if (!status.isNullOrBlank()) put("p_status", status.trim())
        }
        val rows = client.rpcJson("admin_list_users", body).asArrayOrEmpty()
        return rows.mapNotNull { parseAdminUser(it) }
    }

    suspend fun fetchAdminVenues(search: String?, status: String?): List<AdminVenueSummary> {
        val body = buildJsonObject {
            put("p_limit", 100)
            if (!search.isNullOrBlank()) put("p_search", search.trim())
            if (!status.isNullOrBlank()) put("p_status", status.trim())
        }
        val rows = client.rpcJson("admin_list_venues", body).asArrayOrEmpty()
        return rows.mapNotNull { parseAdminVenue(it) }
    }

    suspend fun fetchAdminBookings(search: String?, stage: String?): List<AdminBookingSummary> {
        val body = buildJsonObject {
            put("p_limit", 100)
            if (!search.isNullOrBlank()) put("p_search", search.trim())
            if (!stage.isNullOrBlank()) put("p_stage", stage.trim())
        }
        val rows = client.rpcJson("admin_list_bookings", body).asArrayOrEmpty()
        return rows.mapNotNull { parseAdminBooking(it) }
    }

    suspend fun adminSetVenueStatus(venueId: String, status: MembershipStatus) {
        client.rpcVoid(
            "admin_set_venue_status",
            buildJsonObject {
                put("p_venue_id", venueId)
                put("p_status", status.apiValue)
            }
        )
    }

    suspend fun adminDeleteVenue(venueId: String) {
        client.rpcVoid(
            "admin_delete_venue",
            buildJsonObject { put("p_venue_id", venueId) }
        )
    }

    suspend fun adminSetMembershipStatus(userId: String, status: MembershipStatus) {
        client.rpcVoid(
            "admin_set_membership_status",
            buildJsonObject {
                put("p_user_id", userId)
                put("p_status", status.apiValue)
            }
        )
    }

    suspend fun adminSetUserRole(userId: String, role: UserRole) {
        client.rpcVoid(
            "admin_set_user_role",
            buildJsonObject {
                put("p_user_id", userId)
                put("p_role", role.apiValue)
            }
        )
    }

    suspend fun fetchAdminInviteCodes(): List<AdminInviteCodeItem> {
        val rows = client.rpcJson("admin_list_invite_codes", buildJsonObject { }).asArrayOrEmpty()
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            AdminInviteCodeItem(
                code = obj.string("code") ?: return@mapNotNull null,
                ownerType = obj.string("owner_type") ?: "creator",
                maxUses = obj.int("max_uses") ?: 1,
                useCount = obj.int("use_count") ?: 0,
                inviteEmail = obj.string("invite_email"),
                createdLabel = formatRelative(obj.string("created_at"))
            )
        }
    }

    suspend fun fetchAdminActivity(limit: Int = 150): List<ActivityEventItem> {
        val rows = client.rpcJson(
            "admin_list_activity",
            buildJsonObject { put("p_limit", limit) }
        ).asArrayOrEmpty()
        return rows.mapNotNull { parseActivityEvent(it) }
    }

    suspend fun adminNotifyUsersInRadius(
        lat: Double,
        lng: Double,
        radiusKm: Double,
        title: String,
        body: String
    ): Int {
        val result = client.rpcJson(
            "admin_notify_users_in_radius",
            buildJsonObject {
                put("p_lat", lat)
                put("p_lng", lng)
                put("p_radius_km", radiusKm)
                put("p_title", title)
                put("p_body", body)
            }
        )
        return when (result) {
            is kotlinx.serialization.json.JsonPrimitive -> result.content.toIntOrNull() ?: 0
            is JsonArray -> result.firstOrNull()?.asObjectOrNull()?.int("count")
                ?: result.firstOrNull().let { el ->
                    (el as? kotlinx.serialization.json.JsonPrimitive)?.content?.toIntOrNull()
                } ?: 0
            else -> result.asObjectOrNull()?.int("count") ?: 0
        }
    }

    suspend fun adminCreateInviteCode(code: String?, ownerType: String, maxUses: Int, inviteEmail: String?) {
        client.rpcVoid(
            "admin_create_invite_code",
            buildJsonObject {
                if (!code.isNullOrBlank()) put("p_code", code.trim().uppercase())
                put("p_owner_type", ownerType)
                put("p_max_uses", maxUses)
                if (!inviteEmail.isNullOrBlank()) put("p_invite_email", inviteEmail.trim())
            }
        )
    }

    suspend fun adminUpdateInviteCodeQuota(code: String, maxUses: Int) {
        client.rpcVoid(
            "admin_update_invite_code",
            buildJsonObject {
                put("p_code", code.trim().uppercase())
                put("p_max_uses", maxUses)
            }
        )
    }

    suspend fun fetchMyVenues(): List<VenueSummary> {
        val rows = client.rpcJson("fetch_my_venues", buildJsonObject { }).asArrayOrEmpty()
        return rows.mapNotNull { parseVenueSummary(it) }
    }

    suspend fun registerVenueLocation(
        name: String,
        area: String,
        category: String,
        contactName: String
    ): String {
        val result = client.rpcJson(
            "register_venue_location",
            buildJsonObject {
                put("p_venue_name", name.trim())
                put("p_area", area.trim())
                put("p_category", category)
                put("p_address", "")
                put("p_contact_name", contactName.trim())
                put("p_contact_phone", "")
            }
        )
        return result.asObjectOrNull()?.string("id")
            ?: result.asObjectOrNull()?.string("venue_id")
            ?: result.toString().trim('"').takeIf { it.isNotBlank() && it != "null" }
            ?: throw MarviApiException("Venue registration returned empty id")
    }

    suspend fun fetchMyBrands(): List<BrandSummary> {
        val rows = client.rpcJson("fetch_my_brands", buildJsonObject { }).asArrayOrEmpty()
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            BrandSummary(
                organizationId = obj.string("organization_id") ?: return@mapNotNull null,
                organizationName = obj.string("organization_name") ?: "",
                brandId = obj.string("brand_id") ?: return@mapNotNull null,
                brandName = obj.string("brand_name") ?: ""
            )
        }
    }

    suspend fun createOrganizationWithBrand(
        organizationName: String,
        brandName: String
    ): OrganizationBrandCreated {
        val row = client.rpcJson(
            "create_organization_with_brand",
            buildJsonObject {
                put("p_organization_name", organizationName.trim())
                put("p_brand_name", brandName.trim())
            }
        )
        val obj = row.asObjectOrNull() ?: throw MarviApiException("Invalid organization/brand response")
        return OrganizationBrandCreated(
            organizationId = obj.string("organization_id")
                ?: throw MarviApiException("Missing organization_id"),
            organizationName = obj.string("organization_name") ?: organizationName.trim(),
            brandId = obj.string("brand_id")
                ?: throw MarviApiException("Missing brand_id"),
            brandName = obj.string("brand_name") ?: brandName.trim()
        )
    }

    suspend fun createEstablishmentDraft(brandId: String, establishmentName: String): String {
        val result = client.rpcJson(
            "create_establishment_draft",
            buildJsonObject {
                put("p_brand_id", brandId)
                put("p_establishment_name", establishmentName.trim())
            }
        )
        return result.asObjectOrNull()?.string("id")
            ?: result.asObjectOrNull()?.string("venue_id")
            ?: result.toString().trim('"').takeIf { it.isNotBlank() && it != "null" }
            ?: throw MarviApiException("Establishment draft returned empty id")
    }

    suspend fun fetchEstablishmentDraft(venueId: String): EstablishmentDraft {
        val result = client.rpcJson(
            "fetch_establishment_draft",
            buildJsonObject { put("p_venue_id", venueId) }
        )
        val obj = result.asObjectOrNull() ?: throw MarviApiException("Establishment draft missing")
        return EstablishmentDraft(
            id = obj.string("id") ?: venueId,
            venueName = obj.string("venue_name") ?: "",
            draftName = obj.string("draft_name") ?: "",
            area = obj.string("area") ?: "",
            city = obj.string("city") ?: "",
            country = obj.string("country") ?: "",
            address = obj.string("address") ?: "",
            addressLine1 = obj.string("address_line1") ?: "",
            addressLine2 = obj.string("address_line2") ?: "",
            postalCode = obj.string("postal_code") ?: "",
            instagramHandle = obj.string("instagram_handle") ?: "",
            description = obj.string("description") ?: "",
            contactName = obj.string("contact_name") ?: "",
            contactPhone = obj.string("contact_phone") ?: "",
            contactIsSelf = obj.bool("contact_is_self") == true,
            isPhysical = obj.bool("is_physical") != false,
            categories = result.stringList("categories"),
            logoUrl = obj.string("logo_url") ?: "",
            detailsComplete = obj.bool("details_complete") == true,
            addressComplete = obj.bool("address_complete") == true,
            photosComplete = obj.bool("photos_complete") == true,
            lat = obj.double("lat"),
            lng = obj.double("lng")
        )
    }

    suspend fun upsertEstablishmentDetails(
        venueId: String,
        instagramHandle: String,
        description: String,
        categories: List<String>,
        contactName: String,
        contactPhone: String,
        contactIsSelf: Boolean,
        offerCategory: String
    ) {
        client.rpcVoid(
            "upsert_establishment_details",
            buildJsonObject {
                put("p_venue_id", venueId)
                put("p_instagram_handle", instagramHandle.trim().removePrefix("@"))
                put("p_description", description.trim())
                putJsonArray("p_categories") { categories.forEach { add(it) } }
                put("p_contact_name", contactName.trim())
                put("p_contact_phone", contactPhone.trim())
                put("p_contact_is_self", contactIsSelf)
                put("p_offer_category", offerCategory)
            }
        )
    }

    suspend fun upsertEstablishmentAddress(
        venueId: String,
        isPhysical: Boolean,
        country: String,
        city: String,
        locationLabel: String,
        addressLine1: String,
        addressLine2: String = "",
        postalCode: String = "",
        lat: Double? = null,
        lng: Double? = null
    ) {
        client.rpcVoid(
            "upsert_establishment_address",
            buildJsonObject {
                put("p_venue_id", venueId)
                put("p_is_physical", isPhysical)
                put("p_country", country.trim())
                put("p_city", city.trim())
                put("p_location_label", locationLabel.trim())
                put("p_address_line1", addressLine1.trim())
                put("p_address_line2", addressLine2.trim())
                put("p_postal_code", postalCode.trim())
                if (lat != null) put("p_lat", lat)
                if (lng != null) put("p_lng", lng)
            }
        )
    }

    suspend fun upsertEstablishmentPhotos(
        venueId: String,
        logoUrl: String,
        galleryUrls: List<String>
    ) {
        client.rpcVoid(
            "upsert_establishment_photos",
            buildJsonObject {
                put("p_venue_id", venueId)
                put("p_logo_url", logoUrl.trim())
                putJsonArray("p_gallery_urls") { galleryUrls.forEach { add(it) } }
            }
        )
    }

    suspend fun submitEstablishmentForReview(venueId: String) {
        client.rpcVoid(
            "submit_establishment_for_review",
            buildJsonObject { put("p_venue_id", venueId) }
        )
    }

    /** Uploads establishment logo to `venue-media/{userId}/{venueId}/logo.jpg`. */
    suspend fun uploadVenueLogo(venueId: String, imageData: ByteArray): String {
        val userId = client.currentUserId() ?: throw MarviApiException("Not authenticated")
        val path = "$userId/$venueId/logo.jpg"
        client.uploadObject(
            bucket = "venue-media",
            path = path,
            data = imageData,
            contentType = "image/jpeg"
        )
        return client.publicStorageUrl("venue-media", path)
    }

    /** Uploads gallery photo to `venue-media/{userId}/{venueId}/gallery-{index}.jpg`. */
    suspend fun uploadVenueGalleryImage(venueId: String, imageData: ByteArray, index: Int): String {
        val userId = client.currentUserId() ?: throw MarviApiException("Not authenticated")
        val path = "$userId/$venueId/gallery-$index.jpg"
        client.uploadObject(
            bucket = "venue-media",
            path = path,
            data = imageData,
            contentType = "image/jpeg"
        )
        return client.publicStorageUrl("venue-media", path)
    }

    suspend fun venueSoftDeleteOffer(offerId: String, reason: String? = null) {
        client.rpcVoid(
            "venue_soft_delete_offer",
            buildJsonObject {
                put("p_offer_id", offerId)
                if (!reason.isNullOrBlank()) put("p_reason", reason)
            }
        )
    }

    suspend fun fetchCampaigns(): List<Campaign> {
        val rows = client.select(
            "offers",
            mapOf(
                "select" to "*,venue_profiles(venue_name,area)",
                "order" to "created_at.desc"
            )
        ) { it.asArrayOrEmpty() }
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            val venue = obj["venue_profiles"]?.asObjectOrNull()
            Campaign(
                id = obj.string("id") ?: return@mapNotNull null,
                title = obj.string("title") ?: "Campaign",
                status = obj.string("status") ?: "Draft",
                venueId = obj.string("venue_id"),
                venueName = venue?.string("venue_name") ?: obj.string("venue_name") ?: "",
                dateLabel = formatRelative(obj.string("created_at")),
                isDeleted = !obj.string("deleted_at").isNullOrBlank()
            )
        }
    }

    suspend fun fetchSwipeCandidates(offerId: String?): List<InfluencerCandidate> {
        val body = buildJsonObject {
            if (!offerId.isNullOrBlank()) put("p_offer_id", offerId)
        }
        val rows = client.rpcJson("fetch_swipe_candidates", body).asArrayOrEmpty()
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            val audience = obj.int("audience_count") ?: 0
            val score = obj.double("score")?.toInt() ?: obj.int("score") ?: 0
            val proofRate = obj.double("proof_rate")?.toInt() ?: obj.int("proof_rate") ?: 0
            val followers = if (audience >= 1000) {
                String.format(Locale.US, "%.1fK", audience / 1000.0)
            } else audience.toString()
            val niche = row.stringList("niches").firstOrNull() ?: "Creator"
            val name = obj.string("full_name")?.takeIf { it.isNotBlank() }
                ?: obj.string("instagram_handle") ?: ""
            InfluencerCandidate(
                id = obj.string("creator_id") ?: obj.string("id") ?: return@mapNotNull null,
                name = name,
                niche = niche,
                score = score,
                punctuality = proofRate.coerceIn(60, 99),
                presentation = score.coerceIn(60, 99),
                followers = followers
            )
        }
    }

    suspend fun shortlistCreator(creatorId: String, offerId: String?) {
        client.rpcVoid(
            "shortlist_creator",
            buildJsonObject {
                put("p_creator_id", creatorId)
                if (!offerId.isNullOrBlank()) put("p_offer_id", offerId)
            }
        )
    }

    suspend fun passCreator(creatorId: String, offerId: String?) {
        client.rpcVoid(
            "pass_creator",
            buildJsonObject {
                put("p_creator_id", creatorId)
                if (!offerId.isNullOrBlank()) put("p_offer_id", offerId)
            }
        )
    }

    suspend fun fetchVenueReviewQueue(): List<VenueReviewItem> {
        val rows = client.rpcJson("fetch_venue_review_queue", buildJsonObject { }).asArrayOrEmpty()
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            val stageRaw = obj.string("stage") ?: ""
            VenueReviewItem(
                id = obj.string("booking_id") ?: obj.string("id") ?: return@mapNotNull null,
                creatorName = obj.string("creator_name") ?: "",
                instagramHandle = obj.string("instagram_handle") ?: "",
                offerTitle = obj.string("offer_title") ?: "",
                stageLabel = stageRaw.replace('_', ' ').replaceFirstChar { it.uppercase() },
                checkedInLabel = obj.string("checked_in_label") ?: "",
                hasReview = obj.bool("has_review") == true
            )
        }
    }

    suspend fun submitVenueReview(bookingId: String, punctuality: Int, presentation: Int, comment: String) {
        client.rpcVoid(
            "submit_venue_review",
            buildJsonObject {
                put("p_booking_id", bookingId)
                put("p_punctuality", punctuality)
                put("p_presentation", presentation)
                put("p_comment", comment)
            }
        )
    }

    suspend fun searchMembers(query: String?): List<MemberSearchResult> {
        val body = buildJsonObject {
            put("p_limit", 30)
            if (!query.isNullOrBlank()) put("p_query", query.trim())
        }
        val rows = client.rpcJson("search_members", body).asArrayOrEmpty()
        return rows.mapNotNull { parseMemberSearch(it) }
    }

    suspend fun fetchFollowingActivity(limit: Int = 30): List<MemberActivityItem> {
        val rows = client.rpcJson(
            "get_following_activity",
            buildJsonObject { put("p_limit", limit) }
        ).asArrayOrEmpty()
        return rows.mapNotNull { parseActivity(it) }
    }

    suspend fun fetchDirectThreads(): List<DirectThread> {
        val rows = client.rpcJson("get_my_direct_threads", buildJsonObject { }).asArrayOrEmpty()
        return rows.mapNotNull { parseDirectThread(it) }
    }

    suspend fun ensureDirectThread(peerUserId: String): String {
        val row = client.rpcJson(
            "ensure_direct_thread",
            buildJsonObject { put("p_target", peerUserId) }
        )
        return row.asObjectOrNull()?.string("thread_id")
            ?: row.toString().trim('"')
    }

    suspend fun fetchDirectMessages(threadId: String): List<ChatMessage> {
        val rows = client.rpcJson(
            "get_direct_messages",
            buildJsonObject { put("p_thread_id", threadId) }
        ).asArrayOrEmpty()
        val myId = client.currentUserId()
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            val senderId = obj.string("sender_user_id") ?: return@mapNotNull null
            ChatMessage(
                id = obj.string("id") ?: UUID.randomUUID().toString(),
                senderId = senderId,
                body = obj.string("body") ?: "",
                createdLabel = formatRelative(obj.string("created_at")),
                isMine = senderId == myId
            )
        }
    }

    suspend fun sendDirectMessage(threadId: String, body: String): ChatMessage {
        val row = client.rpcJson(
            "send_direct_message",
            buildJsonObject {
                put("p_thread_id", threadId)
                put("p_body", body.trim())
            }
        )
        val obj = row.asObjectOrNull() ?: throw MarviApiException("Invalid message response")
        val senderId = obj.string("sender_user_id") ?: client.currentUserId().orEmpty()
        return ChatMessage(
            id = obj.string("id") ?: UUID.randomUUID().toString(),
            senderId = senderId,
            body = obj.string("body") ?: body,
            createdLabel = formatRelative(obj.string("created_at")),
            isMine = true
        )
    }

    suspend fun fetchProfileComments(targetUserId: String): List<ProfileComment> {
        val rows = client.rpcJson(
            "list_profile_comments",
            buildJsonObject { put("p_target_user_id", targetUserId) }
        ).asArrayOrEmpty()
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            ProfileComment(
                id = obj.string("id") ?: return@mapNotNull null,
                authorId = obj.string("author_user_id") ?: obj.string("author_id") ?: "",
                authorName = obj.string("author_name") ?: "",
                authorHandle = obj.string("author_handle") ?: "",
                body = obj.string("body") ?: "",
                createdLabel = formatRelative(obj.string("created_at"))
            )
        }
    }

    suspend fun addProfileComment(targetUserId: String, body: String) {
        client.rpcVoid(
            "add_profile_comment",
            buildJsonObject {
                put("p_target_user_id", targetUserId)
                put("p_body", body.trim())
            }
        )
    }

    suspend fun fetchCreatorPublicProfile(creatorId: String): PublicCreatorProfile? {
        val row = client.rpcJson(
            "get_creator_public_profile_by_creator_id",
            buildJsonObject { put("p_creator_id", creatorId) }
        )
        val obj = row.asObjectOrNull() ?: return null
        return PublicCreatorProfile(
            id = obj.string("creator_id") ?: obj.string("id") ?: creatorId,
            name = obj.string("full_name") ?: obj.string("display_name") ?: "",
            handle = obj.string("instagram_handle") ?: "",
            tiktokHandle = obj.string("tiktok_handle") ?: "",
            city = obj.string("city") ?: "",
            bio = obj.string("bio") ?: "",
            avatarUrl = obj.string("avatar_url"),
            coverUrl = obj.string("cover_url"),
            score = obj.int("score") ?: 0,
            isFollowing = obj.bool("is_following") == true,
            followerCount = obj.int("followers") ?: obj.int("follower_count") ?: 0,
            followingCount = obj.int("following") ?: obj.int("following_count") ?: 0
        )
    }

    suspend fun fetchVenuePublicProfile(venueId: String): PublicVenueProfile? {
        val row = client.rpcJson(
            "get_venue_public_profile",
            buildJsonObject { put("p_venue_id", venueId) }
        )
        val obj = row.asObjectOrNull() ?: return null
        return PublicVenueProfile(
            id = obj.string("venue_id") ?: obj.string("id") ?: venueId,
            name = obj.string("venue_name") ?: "",
            area = obj.string("area") ?: "",
            category = OfferCategory.fromApi(obj.string("category")),
            bio = obj.string("bio") ?: obj.string("address") ?: "",
            avatarUrl = obj.string("avatar_url"),
            isFollowing = obj.bool("is_following") == true,
            followerCount = obj.int("followers") ?: obj.int("follower_count") ?: 0
        )
    }

    suspend fun followUser(userId: String) {
        client.rpcVoid("follow_user", buildJsonObject { put("p_target", userId) })
    }

    suspend fun unfollowUser(userId: String) {
        client.rpcVoid("unfollow_user", buildJsonObject { put("p_target", userId) })
    }

    suspend fun fetchMyFollowCounts(): FollowCounts {
        val row = client.rpcJson("get_my_follow_counts", buildJsonObject { })
        val obj = row.asObjectOrNull() ?: return FollowCounts.ZERO
        return FollowCounts(
            followers = obj.int("followers") ?: 0,
            following = obj.int("following") ?: 0
        )
    }

    suspend fun fetchStrikes(): List<Strike> {
        val rows = client.select("strikes", mapOf("order" to "created_at.desc")) { it.asArrayOrEmpty() }
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            Strike(
                id = obj.string("id") ?: return@mapNotNull null,
                reason = obj.string("reason") ?: "",
                dateLabel = formatRelative(obj.string("created_at"))
            )
        }
    }

    suspend fun fetchMyShowcase(): List<ShowcaseItem> {
        val rows = client.rpcJson("get_my_showcase", buildJsonObject { }).asArrayOrEmpty()
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            ShowcaseItem(
                id = obj.string("id") ?: return@mapNotNull null,
                mediaType = ShowcaseMediaType.fromApi(obj.string("media_type")),
                mediaUrl = obj.string("media_url") ?: "",
                externalUrl = obj.string("external_url") ?: "",
                caption = obj.string("caption") ?: ""
            )
        }
    }

    suspend fun addShowcaseItem(mediaType: ShowcaseMediaType, mediaUrl: String, externalUrl: String, caption: String) {
        client.insert(
            "creator_showcase",
            buildJsonObject {
                put("media_type", mediaType.api)
                put("media_url", mediaUrl)
                put("external_url", externalUrl)
                put("caption", caption)
            }
        )
    }

    suspend fun deleteShowcaseItem(id: String) {
        client.rpcVoid("delete_showcase_item", buildJsonObject { put("p_id", id) })
    }

    suspend fun fetchMyCollaborationHistory(): List<CollaborationEntry> {
        val rows = client.rpcJson("get_my_collaboration_history", buildJsonObject { }).asArrayOrEmpty()
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            val venueRating = obj["venue_rating"]?.asObjectOrNull()?.let { rating ->
                val p = rating.int("punctuality")
                val pr = rating.int("presentation")
                if (p != null && pr != null) (p + pr) / 2.0 else null
            }
            CollaborationEntry(
                id = obj.string("booking_id") ?: obj.string("id") ?: return@mapNotNull null,
                venueName = obj.string("venue_name") ?: "",
                area = obj.string("area") ?: "",
                title = obj.string("title") ?: "",
                dateLabel = formatDate(obj.string("date")),
                venueRating = venueRating
            )
        }
    }

    suspend fun pauseOwnAccount() {
        client.rpcVoid("pause_own_account", buildJsonObject { })
    }

    suspend fun reactivateOwnAccount() {
        client.rpcVoid("reactivate_own_account", buildJsonObject { })
    }

    suspend fun ensureSocialVerificationCode(): SocialVerificationStatus {
        val row = client.rpcJson("ensure_social_verification_code", buildJsonObject { })
        return parseSocialVerification(row)
    }

    suspend fun submitSocialVerificationDm(): SocialVerificationStatus {
        val row = client.rpcJson("submit_social_verification_dm", buildJsonObject { })
        return parseSocialVerification(row)
    }

    suspend fun adminVerifySocialDm(userId: String) {
        client.rpcVoid(
            "admin_verify_social_dm",
            buildJsonObject { put("p_user_id", userId) }
        )
    }

    private fun parseSocialVerification(el: JsonElement): SocialVerificationStatus {
        val obj = el.asObjectOrNull() ?: return SocialVerificationStatus()
        return SocialVerificationStatus(
            state = SocialVerificationState.fromApi(obj.string("status")),
            code = obj.string("code"),
            instagramHandle = obj.string("instagram_handle") ?: "",
            tiktokHandle = obj.string("tiktok_handle") ?: "",
            marviInstagramHandle = obj.string("marvi_instagram") ?: "marvisociety"
        )
    }

    private fun parseOffer(el: JsonElement): Offer? {
        val obj = el.asObjectOrNull() ?: return null
        return Offer(
            id = obj.string("id") ?: return null,
            title = obj.string("title") ?: "",
            venue = obj.string("venue_name") ?: "Venue",
            area = obj.string("area") ?: "Istanbul",
            category = OfferCategory.fromApi(obj.string("category")),
            dateLabel = obj.string("date_label") ?: "TBD",
            timeLabel = obj.string("time_label") ?: "",
            valueLabel = obj.string("value_label") ?: "",
            capacity = obj.int("capacity") ?: 1,
            remaining = obj.int("remaining_slots") ?: 0,
            imageName = obj.string("image_name") ?: "venue-placeholder",
            description = obj.string("description") ?: "",
            deliverables = el.stringList("deliverables"),
            requirements = el.stringList("requirements"),
            hostNote = obj.string("host_note") ?: "",
            collaborationModel = CollaborationModel.fromApi(obj.string("model")),
            latitude = obj.double("lat"),
            longitude = obj.double("lng")
        )
    }

    private fun parseBooking(el: JsonElement): Booking? {
        val obj = el.asObjectOrNull() ?: return null
        // PostgREST embeds the joined offer under the "offers" key (relationship name).
        val offerObj = obj["offers"]?.asObjectOrNull() ?: obj["offer"]?.asObjectOrNull()
        val offer = if (offerObj != null) {
            val venueEmbed = offerObj["venue_profiles"]?.asObjectOrNull()
            Offer(
                id = offerObj.string("id") ?: obj.string("offer_id") ?: "",
                title = offerObj.string("title") ?: "Offer",
                venue = venueEmbed?.string("venue_name") ?: offerObj.string("venue_name") ?: "Venue",
                area = venueEmbed?.string("area") ?: offerObj.string("area") ?: "Istanbul",
                category = OfferCategory.fromApi(offerObj.string("category")),
                dateLabel = offerObj.string("date_label") ?: "TBD",
                timeLabel = offerObj.string("time_label") ?: "",
                valueLabel = offerObj.string("value_label") ?: "",
                capacity = offerObj.int("capacity") ?: 1,
                remaining = offerObj.int("remaining_slots") ?: 0,
                imageName = offerObj.string("image_name") ?: "venue-placeholder",
                description = offerObj.string("description") ?: "",
                deliverables = offerObj.stringList("deliverables"),
                requirements = offerObj.stringList("requirements"),
                hostNote = offerObj.string("host_note") ?: "",
                collaborationModel = CollaborationModel.fromApi(offerObj.string("model")),
                latitude = offerObj.double("lat"),
                longitude = offerObj.double("lng")
            )
        } else {
            parseOffer(obj) ?: Offer(
                id = obj.string("offer_id") ?: "",
                title = obj.string("offer_title") ?: "Offer",
                venue = obj.string("venue_name") ?: "",
                area = obj.string("area") ?: "Istanbul",
                category = OfferCategory.DINING,
                dateLabel = "",
                timeLabel = "",
                valueLabel = "",
                capacity = 1,
                remaining = 0
            )
        }
        return Booking(
            id = obj.string("id") ?: obj.string("booking_id") ?: return null,
            offer = offer,
            stage = BookingStage.fromApi(obj.string("stage")),
            proofDeadline = obj.string("proof_deadline_label") ?: formatDate(obj.string("proof_deadline")),
            checkInCode = obj.string("check_in_code") ?: ""
        )
    }

    private fun parseCreatorProfile(el: JsonElement): CreatorProfile {
        val obj = el.asObjectOrNull() ?: return CreatorProfile()
        val audience = obj.int("audience_count") ?: 0
        val audienceLabel = if (audience >= 1000) {
            String.format(Locale.US, "%.1fK", audience / 1000.0)
        } else {
            audience.toString()
        }
        return CreatorProfile(
            name = obj.string("full_name") ?: "",
            handle = obj.string("instagram_handle") ?: "",
            tiktokHandle = obj.string("tiktok_handle") ?: "",
            city = obj.string("city")?.replaceFirstChar { it.uppercase() } ?: "Istanbul",
            status = membershipFromApi(obj.string("status")) ?: MembershipStatus.UNDER_REVIEW,
            score = obj.int("score") ?: obj.double("score")?.toInt() ?: 0,
            audienceLabel = audienceLabel,
            niches = el.stringList("niches"),
            proofRate = obj.double("proof_rate")?.let { "${it.toInt()}%" } ?: "—",
            bio = obj.string("bio") ?: "",
            languages = el.stringList("languages"),
            avatarUrl = obj.string("avatar_url") ?: "",
            coverUrl = obj.string("cover_url") ?: ""
        )
    }

    private fun parseAdminTask(el: JsonElement): AdminTask? {
        val obj = el.asObjectOrNull() ?: return null
        return AdminTask(
            id = obj.string("id") ?: return null,
            subjectId = obj.string("subject_id"),
            title = obj.string("title") ?: "",
            subtitle = obj.string("subtitle") ?: "",
            dateLabel = formatRelative(obj.string("created_at")),
            priority = obj.string("priority") ?: "Medium",
            status = when (obj.string("status")?.lowercase()) {
                "approved" -> AdminTaskStatus.APPROVED
                "rejected" -> AdminTaskStatus.REJECTED
                else -> AdminTaskStatus.OPEN
            },
            type = AdminTaskType.fromApi(obj.string("type"))
        )
    }

    private fun parseActivityEvent(el: JsonElement): ActivityEventItem? {
        val obj = el.asObjectOrNull() ?: return null
        val id = obj.string("id") ?: return null
        val createdRaw = obj.string("created_at")
        val metaEl = obj["metadata"]
        val metadata = buildMap {
            val metaObj = metaEl?.asObjectOrNull()
            if (metaObj != null) {
                metaObj.keys.forEach { key ->
                    put(key, metaObj.string(key) ?: metaObj[key]?.toString()?.trim('"').orEmpty())
                }
            }
        }
        val actorId = obj.string("actor_user_id")
        val actorName = obj.string("actor_name")?.trim().orEmpty()
        return ActivityEventItem(
            id = id,
            action = obj.string("action") ?: "",
            subjectType = obj.string("subject_type") ?: "",
            subjectId = obj.string("subject_id"),
            createdAtMillis = parseMillis(createdRaw),
            createdLabel = formatRelative(createdRaw),
            actorLabel = actorName.ifBlank { actorId?.take(8)?.uppercase() ?: "system" },
            actorKind = obj.string("actor_kind") ?: "member",
            metadata = metadata
        )
    }

    private fun parseAdminUser(el: JsonElement): AdminUserSummary? {
        val obj = el.asObjectOrNull() ?: return null
        return AdminUserSummary(
            id = obj.string("user_id") ?: obj.string("id") ?: return null,
            email = obj.string("email") ?: "",
            fullName = obj.string("full_name") ?: "",
            city = obj.string("city") ?: "",
            role = UserRole.fromApi(obj.string("role")) ?: UserRole.CREATOR,
            status = membershipFromApi(obj.string("status") ?: obj.string("membership_status")),
            createdLabel = formatRelative(obj.string("last_seen_at") ?: obj.string("created_at")),
            avatarUrl = obj.string("avatar_url") ?: "",
            coverUrl = obj.string("cover_url") ?: "",
            lastLat = obj.double("last_lat"),
            lastLng = obj.double("last_lng")
        )
    }

    private fun parseAdminVenue(el: JsonElement): AdminVenueSummary? {
        val obj = el.asObjectOrNull() ?: return null
        return AdminVenueSummary(
            id = obj.string("venue_id") ?: return null,
            venueName = obj.string("venue_name") ?: "",
            area = obj.string("area") ?: "",
            category = obj.string("category") ?: "",
            status = membershipFromApi(obj.string("status")),
            ownerEmail = obj.string("owner_email") ?: "",
            ownerName = obj.string("owner_name") ?: "",
            offerCount = obj.int("offer_count") ?: 0,
            liveOfferCount = obj.int("live_offer_count") ?: 0,
            bookingCount = obj.int("booking_count") ?: 0
        )
    }

    private fun parseAdminBooking(el: JsonElement): AdminBookingSummary? {
        val obj = el.asObjectOrNull() ?: return null
        return AdminBookingSummary(
            id = obj.string("booking_id") ?: return null,
            offerTitle = obj.string("offer_title") ?: "",
            venueName = obj.string("venue_name") ?: "",
            guestName = obj.string("guest_name") ?: "",
            guestEmail = obj.string("guest_email") ?: "",
            stage = obj.string("stage") ?: "",
            dateLabel = obj.string("date_label") ?: "",
            proofStatus = obj.string("proof_status") ?: ""
        )
    }

    private fun parseVenueSummary(el: JsonElement): VenueSummary? {
        val obj = el.asObjectOrNull() ?: return null
        return VenueSummary(
            id = obj.string("id") ?: return null,
            name = obj.string("venue_name") ?: "",
            area = obj.string("area") ?: "",
            category = OfferCategory.fromApi(obj.string("category")),
            isActive = obj.bool("is_active") == true,
            status = MembershipStatus.fromApi(obj.string("status"))
        )
    }

    private fun parseMemberSearch(el: JsonElement): MemberSearchResult? {
        val obj = el.asObjectOrNull() ?: return null
        val userId = obj.string("user_id")
        // `id` = creator/venue profile ref (public-profile lookup); `userId` = auth user id (follow/DM).
        return MemberSearchResult(
            id = obj.string("profile_ref_id")
                ?: obj.string("creator_id")
                ?: obj.string("id")
                ?: userId
                ?: return null,
            userId = userId ?: "",
            displayName = obj.string("full_name") ?: obj.string("display_name") ?: "",
            handle = (obj.string("instagram_handle") ?: obj.string("handle") ?: "").removePrefix("@"),
            city = obj.string("city")?.replaceFirstChar { it.uppercase() } ?: "",
            avatarUrl = obj.string("avatar_url")?.takeIf { it.isNotBlank() },
            isVenue = obj.string("member_type")?.equals("venue", ignoreCase = true) == true
                || obj.bool("is_venue") == true,
            isFollowing = obj.bool("is_following") == true
        )
    }

    private fun parseActivity(el: JsonElement): MemberActivityItem? {
        val obj = el.asObjectOrNull() ?: return null
        return MemberActivityItem(
            id = obj.string("activity_id") ?: obj.string("id") ?: return null,
            actorId = obj.string("actor_user_id") ?: obj.string("actor_id") ?: "",
            actorName = obj.string("actor_name") ?: "",
            actorHandle = obj.string("actor_handle") ?: "",
            actorAvatarUrl = obj.string("actor_avatar_url"),
            activityType = obj.string("action_type") ?: obj.string("activity_type") ?: "",
            title = obj.string("title") ?: "",
            subtitle = obj.string("subtitle") ?: "",
            venueId = obj.string("venue_id"),
            venueName = obj.string("venue_name"),
            createdLabel = formatRelative(obj.string("created_at"))
        )
    }

    private fun parseDirectThread(el: JsonElement): DirectThread? {
        val obj = el.asObjectOrNull() ?: return null
        return DirectThread(
            id = obj.string("thread_id") ?: obj.string("id") ?: return null,
            peerUserId = obj.string("peer_user_id") ?: "",
            peerName = obj.string("peer_name") ?: "",
            peerHandle = obj.string("peer_handle") ?: "",
            peerAvatarUrl = obj.string("peer_avatar_url"),
            lastMessage = obj.string("last_message") ?: "",
            lastMessageAt = formatRelative(obj.string("last_message_at")),
            unreadCount = obj.int("unread_count") ?: 0
        )
    }

    private fun membershipFromApi(raw: String?): MembershipStatus? = when (raw?.lowercase()) {
        "approved" -> MembershipStatus.APPROVED
        "paused" -> MembershipStatus.PAUSED
        "under review", "under_review" -> MembershipStatus.UNDER_REVIEW
        else -> null
    }

    private fun parseMillis(raw: String?): Long {
        if (raw.isNullOrBlank()) return System.currentTimeMillis()
        val formats = listOf(
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US),
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        )
        return formats.firstNotNullOfOrNull { fmt ->
            runCatching { fmt.parse(raw)?.time }.getOrNull()
        } ?: System.currentTimeMillis()
    }

    private fun formatRelative(raw: String?): String {
        if (raw.isNullOrBlank()) return "Now"
        val formats = listOf(
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US),
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        )
        val date = formats.firstNotNullOfOrNull { fmt ->
            runCatching { fmt.parse(raw) }.getOrNull()
        } ?: return raw.take(10)
        val seconds = ((Date().time - date.time) / 1000).toInt()
        if (seconds < 60) return "Now"
        if (seconds < 3600) return "${seconds / 60}m ago"
        if (seconds < 86400) return "${seconds / 3600}h ago"
        if (seconds < 604800) return "${seconds / 86400}d ago"
        return SimpleDateFormat("MMM d, yyyy", Locale.getDefault()).format(date)
    }

    private fun formatDate(raw: String?): String {
        if (raw.isNullOrBlank()) return ""
        return formatRelative(raw)
    }
}
