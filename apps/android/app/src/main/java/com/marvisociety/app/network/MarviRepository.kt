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
    fun supabaseClient(): SupabaseClient = client

    suspend fun completeGoogleOAuth(uri: android.net.Uri): AuthSession =
        GoogleOAuth.completeIfPossible(uri, client)
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
        val rows = client.select(
            "profiles",
            mapOf("select" to "role,status,referral_code,paused_by_self", "limit" to "1")
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
        val rows = client.select("creator_profiles", mapOf("limit" to "1")) { it.asArrayOrEmpty() }
        val row = rows.firstOrNull() ?: return CreatorProfile()
        return parseCreatorProfile(row)
    }

    suspend fun updateProfile(profile: CreatorProfile) {
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
            }
        )
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
        val path = "$userId/$kind/$fileName"
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
        val path = "$venueId/campaigns/${System.currentTimeMillis()}-$fileName"
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
        val rows = client.select("notifications", mapOf("order" to "created_at.desc")) { it.asArrayOrEmpty() }
        return rows.mapNotNull { row ->
            val obj = row.asObjectOrNull() ?: return@mapNotNull null
            InboxMessage(
                id = obj.string("id") ?: return@mapNotNull null,
                title = obj.string("title") ?: "",
                body = obj.string("body") ?: "",
                dateLabel = formatRelative(obj.string("created_at")),
                isRead = obj["read_at"]?.let { it !is kotlinx.serialization.json.JsonNull } == true
            )
        }
    }

    suspend fun markNotificationRead(id: String) {
        client.rpcVoid("mark_notification_read", buildJsonObject { put("p_notification_id", id) })
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

    suspend fun acceptOffer(offerId: String): Booking {
        val row = client.rpcJson(
            "accept_offer",
            buildJsonObject { put("p_offer_id", offerId) }
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
        val rows = client.select("admin_tasks", mapOf("order" to "created_at.desc")) { it.asArrayOrEmpty() }
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
                venueName = venue?.string("venue_name") ?: obj.string("venue_name") ?: "",
                dateLabel = formatRelative(obj.string("created_at"))
            )
        }
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

    private fun parseAdminUser(el: JsonElement): AdminUserSummary? {
        val obj = el.asObjectOrNull() ?: return null
        return AdminUserSummary(
            id = obj.string("id") ?: return null,
            email = obj.string("email") ?: "",
            fullName = obj.string("full_name") ?: "",
            city = obj.string("city") ?: "",
            role = UserRole.fromApi(obj.string("role")) ?: UserRole.CREATOR,
            status = membershipFromApi(obj.string("membership_status")),
            createdLabel = formatRelative(obj.string("created_at"))
        )
    }

    private fun parseVenueSummary(el: JsonElement): VenueSummary? {
        val obj = el.asObjectOrNull() ?: return null
        return VenueSummary(
            id = obj.string("id") ?: return null,
            name = obj.string("venue_name") ?: "",
            area = obj.string("area") ?: "",
            category = OfferCategory.fromApi(obj.string("category")),
            isActive = obj.bool("is_active") == true
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
