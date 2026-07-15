package com.marvisociety.app.data

enum class AppLanguage { ENGLISH, TURKISH }

enum class UserRole(val label: String) {
    CREATOR("Creator"),
    VENUE("Venue"),
    ADMIN("Admin");

    companion object {
        fun fromApi(raw: String?): UserRole? = when (raw?.lowercase()) {
            "creator" -> CREATOR
            "venue" -> VENUE
            "admin" -> ADMIN
            else -> null
        }

        fun allowedWorkspaces(accountRole: UserRole): List<UserRole> = when (accountRole) {
            ADMIN -> listOf(CREATOR, ADMIN)
            VENUE -> listOf(VENUE)
            CREATOR -> listOf(CREATOR)
        }
    }
}

enum class MembershipStatus { UNDER_REVIEW, APPROVED, PAUSED }

enum class CollaborationModel(val api: String) {
    INVITATION("invitation"),
    EVENT("event"),
    GIFT("gift"),
    INSTANT("instant");

    companion object {
        fun fromApi(raw: String?): CollaborationModel = entries.find {
            it.api.equals(raw, ignoreCase = true) || it.name.equals(raw, ignoreCase = true)
        } ?: INVITATION
    }
}

enum class OfferCategory(val api: String) {
    DINING("dining"),
    NIGHTLIFE("nightlife"),
    WELLNESS("wellness"),
    BEAUTY("beauty"),
    FITNESS("fitness"),
    RETAIL("retail");

    companion object {
        fun fromApi(raw: String?): OfferCategory = entries.find {
            it.api.equals(raw, ignoreCase = true) || it.name.equals(raw, ignoreCase = true)
        } ?: DINING
    }
}

enum class BookingStage {
    INVITED, CONFIRMED, CHECKED_IN, PROOF_DUE, COMPLETED, CANCELLED;

    companion object {
        fun fromApi(raw: String?): BookingStage = when (raw?.lowercase()) {
            "invited" -> INVITED
            "confirmed" -> CONFIRMED
            "checked in", "checked_in" -> CHECKED_IN
            "proof due", "proof_due" -> PROOF_DUE
            "completed" -> COMPLETED
            "cancelled", "canceled" -> CANCELLED
            else -> INVITED
        }
    }
}

enum class AdminTaskStatus { OPEN, APPROVED, REJECTED }

enum class AdminTaskType {
    CREATOR_APPLICATION,
    VENUE_APPLICATION,
    CAMPAIGN_REVIEW,
    PROOF_REVIEW,
    SOCIAL_VERIFICATION;

    companion object {
        fun fromApi(raw: String?): AdminTaskType = when (raw?.lowercase()?.replace(' ', '_')) {
            "venue_application" -> VENUE_APPLICATION
            "campaign_review" -> CAMPAIGN_REVIEW
            "proof_review" -> PROOF_REVIEW
            "social_verification" -> SOCIAL_VERIFICATION
            "creator_application" -> CREATOR_APPLICATION
            else -> CREATOR_APPLICATION
        }
    }
}

data class AccountContext(
    val role: UserRole = UserRole.CREATOR,
    val membershipStatus: MembershipStatus? = null,
    val hasVenueProfile: Boolean = false,
    val referralCode: String? = null,
    val pausedBySelf: Boolean = false
)

data class Offer(
    val id: String,
    val title: String,
    val venue: String,
    val area: String,
    val category: OfferCategory,
    val dateLabel: String,
    val timeLabel: String,
    val valueLabel: String,
    val capacity: Int,
    val remaining: Int,
    val imageName: String = "venue-placeholder",
    val description: String = "",
    val deliverables: List<String> = emptyList(),
    val requirements: List<String> = emptyList(),
    val hostNote: String = "",
    val collaborationModel: CollaborationModel = CollaborationModel.INVITATION,
    val latitude: Double? = null,
    val longitude: Double? = null
) {
    val modelLabel: String get() = collaborationModel.name.lowercase().replaceFirstChar { it.uppercase() }
}

data class Booking(
    val id: String,
    val offer: Offer,
    val stage: BookingStage,
    val proofDeadline: String = "",
    val checkInCode: String = ""
)

data class CreatorProfile(
    val name: String = "",
    val handle: String = "",
    val tiktokHandle: String = "",
    val city: String = "Istanbul",
    val status: MembershipStatus = MembershipStatus.UNDER_REVIEW,
    val score: Int = 0,
    val audienceLabel: String = "—",
    val niches: List<String> = emptyList(),
    val proofRate: String = "—",
    val bio: String = "",
    val languages: List<String> = emptyList(),
    val avatarUrl: String = "",
    val coverUrl: String = ""
)

data class InboxMessage(
    val id: String,
    val title: String,
    val body: String,
    val dateLabel: String,
    val isRead: Boolean = false,
    val bookingId: String? = null,
    val offerId: String? = null
)

data class AdminTask(
    val id: String,
    val subjectId: String? = null,
    val title: String,
    val subtitle: String,
    val dateLabel: String,
    val priority: String,
    val status: AdminTaskStatus,
    val type: AdminTaskType
)

data class AdminUserSummary(
    val id: String,
    val email: String,
    val fullName: String,
    val city: String,
    val role: UserRole,
    val status: MembershipStatus?,
    val createdLabel: String
)

data class AdminInviteCodeItem(
    val code: String,
    val ownerType: String,
    val maxUses: Int,
    val useCount: Int,
    val inviteEmail: String?,
    val createdLabel: String
)

data class VenueSummary(
    val id: String,
    val name: String,
    val area: String,
    val category: OfferCategory,
    val isActive: Boolean = false
)

data class Campaign(
    val id: String,
    val title: String,
    val status: String,
    val venueName: String,
    val dateLabel: String
)

data class MemberSearchResult(
    val id: String,
    val userId: String = "",
    val displayName: String,
    val handle: String,
    val city: String,
    val avatarUrl: String?,
    val isVenue: Boolean,
    val isFollowing: Boolean
)

data class MemberActivityItem(
    val id: String,
    val actorId: String,
    val actorName: String,
    val actorHandle: String,
    val actorAvatarUrl: String?,
    val activityType: String,
    val title: String,
    val subtitle: String,
    val venueId: String?,
    val venueName: String?,
    val createdLabel: String
)

data class DirectThread(
    val id: String,
    val peerUserId: String,
    val peerName: String,
    val peerHandle: String,
    val peerAvatarUrl: String?,
    val lastMessage: String,
    val lastMessageAt: String,
    val unreadCount: Int
)

data class ChatMessage(
    val id: String,
    val senderId: String,
    val body: String,
    val createdLabel: String,
    val isMine: Boolean
)

data class ProfileComment(
    val id: String,
    val authorId: String,
    val authorName: String,
    val authorHandle: String,
    val body: String,
    val createdLabel: String
)

data class PublicCreatorProfile(
    val id: String,
    val name: String,
    val handle: String,
    val tiktokHandle: String,
    val city: String,
    val bio: String,
    val avatarUrl: String?,
    val coverUrl: String?,
    val score: Int,
    val isFollowing: Boolean,
    val followerCount: Int,
    val followingCount: Int
)

data class PublicVenueProfile(
    val id: String,
    val name: String,
    val area: String,
    val category: OfferCategory,
    val bio: String,
    val avatarUrl: String?,
    val isFollowing: Boolean,
    val followerCount: Int
)

data class FollowCounts(val followers: Int, val following: Int) {
    companion object {
        val ZERO = FollowCounts(0, 0)
    }
}

data class Strike(
    val id: String,
    val reason: String,
    val dateLabel: String
)

enum class ShowcaseMediaType(val api: String) {
    IMAGE("image"), VIDEO("video"), LINK("link");

    companion object {
        fun fromApi(raw: String?): ShowcaseMediaType = when (raw?.lowercase()) {
            "image" -> IMAGE
            "video" -> VIDEO
            else -> LINK
        }
    }
}

data class ShowcaseItem(
    val id: String,
    val mediaType: ShowcaseMediaType,
    val mediaUrl: String,
    val externalUrl: String,
    val caption: String
)

data class CollaborationEntry(
    val id: String,
    val venueName: String,
    val area: String,
    val title: String,
    val dateLabel: String,
    val venueRating: Double?
)

/** Extra info collected at accept time depending on the collaboration model. */
data class AcceptOfferOptions(
    val shippingAddress: String? = null,
    val rsvpGuests: Int? = null
)

/** A booking-scoped collaboration chat thread between a creator and a venue. */
data class ChatConversation(
    val id: String,
    val bookingId: String,
    val offerTitle: String,
    val venueName: String,
    val lastMessage: String,
    val lastMessageAt: String
) {
    val title: String get() = venueName.ifBlank { offerTitle }
    val preview: String get() = lastMessage.trim().ifEmpty { offerTitle }
}

/** A venue-initiated collaboration invite awaiting the creator's acceptance. */
data class PendingCollaborationRequest(
    val id: String,
    val offerId: String,
    val offerTitle: String,
    val venueName: String,
    val status: String,
    val createdLabel: String
) {
    val isPendingCreator: Boolean get() = status == "pending_creator"
}

data class InfluencerCandidate(
    val id: String,
    val name: String,
    val niche: String,
    val score: Int,
    val punctuality: Int,
    val presentation: Int,
    val followers: String
)

data class VenueReviewItem(
    val id: String,
    val creatorName: String,
    val instagramHandle: String,
    val offerTitle: String,
    val stageLabel: String,
    val checkedInLabel: String,
    val hasReview: Boolean
)

data class AppSnapshot(
    val hasCompletedOnboarding: Boolean = false,
    val selectedRole: UserRole = UserRole.CREATOR,
    val preferredLanguage: AppLanguage = AppLanguage.TURKISH,
    val languageManuallySet: Boolean = false,
    val pushNotificationsEnabled: Boolean = true,
    val proofRemindersEnabled: Boolean = true
)

enum class SocialVerificationState {
    NEEDS_HANDLES, PENDING, SUBMITTED, VERIFIED;

    companion object {
        fun fromApi(raw: String?): SocialVerificationState = when (raw?.lowercase()) {
            "needs_handles" -> NEEDS_HANDLES
            "submitted" -> SUBMITTED
            "verified" -> VERIFIED
            else -> PENDING
        }
    }
}

data class SocialVerificationStatus(
    val state: SocialVerificationState = SocialVerificationState.NEEDS_HANDLES,
    val code: String? = null,
    val instagramHandle: String = "",
    val tiktokHandle: String = "",
    val marviInstagramHandle: String = "marvisociety"
) {
    val isVerified: Boolean get() = state == SocialVerificationState.VERIFIED
    val dmMessage: String
        get() {
            val codePart = code ?: return ""
            val ig = instagramHandle.removePrefix("@")
            val tt = tiktokHandle.removePrefix("@")
            return "$codePart · Instagram @$ig · TikTok @$tt"
        }
}
