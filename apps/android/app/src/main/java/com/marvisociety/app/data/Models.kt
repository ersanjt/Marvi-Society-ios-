package com.marvisociety.app.data

enum class AppLanguage { ENGLISH, TURKISH }

enum class UserRole(val label: String) {
    CREATOR("Creator"),
    VENUE("Venue"),
    ADMIN("Admin");

    val apiValue: String
        get() = when (this) {
            CREATOR -> "creator"
            VENUE -> "venue"
            ADMIN -> "admin"
        }

    companion object {
        fun fromApi(raw: String?): UserRole? = when (raw?.lowercase()) {
            "creator" -> CREATOR
            "venue", "business", "brand" -> VENUE
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

enum class MembershipStatus {
    UNDER_REVIEW, APPROVED, PAUSED;

    val apiValue: String
        get() = when (this) {
            UNDER_REVIEW -> "under_review"
            APPROVED -> "approved"
            PAUSED -> "paused"
        }

    companion object {
        fun fromApi(raw: String?): MembershipStatus? = when (raw?.lowercase()) {
            "under_review", "pending" -> UNDER_REVIEW
            "approved" -> APPROVED
            "paused", "rejected" -> PAUSED
            else -> null
        }
    }
}

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

data class BusinessCategoryOption(
    val key: String,
    val english: String,
    val turkish: String,
    val offerCategory: OfferCategory
) {
    fun label(language: AppLanguage): String = if (language == AppLanguage.TURKISH) turkish else english
}

object BusinessCategoryCatalog {
    /** Product order: Hotel → Restaurant → Cafe → then rest. */
    val all = listOf(
        BusinessCategoryOption("hotel", "Hotel", "Otel", OfferCategory.WELLNESS),
        BusinessCategoryOption("restaurant", "Restaurant", "Restoran", OfferCategory.DINING),
        BusinessCategoryOption("cafe", "Cafe", "Kafe", OfferCategory.DINING),
        BusinessCategoryOption("coffee-shop", "Coffee shop", "Kahve dükkanı", OfferCategory.DINING),
        BusinessCategoryOption("bakery", "Bakery", "Fırın", OfferCategory.DINING),
        BusinessCategoryOption("patisserie", "Patisserie", "Pastane", OfferCategory.DINING),
        BusinessCategoryOption("dessert-shop", "Dessert shop", "Tatlıcı", OfferCategory.DINING),
        BusinessCategoryOption("fast-food", "Fast food", "Fast food", OfferCategory.DINING),
        BusinessCategoryOption("food-truck", "Food truck", "Yemek kamyonu", OfferCategory.DINING),
        BusinessCategoryOption("catering", "Catering", "Catering", OfferCategory.DINING),
        BusinessCategoryOption("resort", "Resort", "Tatil köyü", OfferCategory.WELLNESS),
        BusinessCategoryOption("hostel", "Hostel", "Hostel", OfferCategory.WELLNESS),
        BusinessCategoryOption("bar-pub", "Bar / Pub", "Bar / Pub", OfferCategory.NIGHTLIFE),
        BusinessCategoryOption("lounge", "Lounge", "Lounge", OfferCategory.NIGHTLIFE),
        BusinessCategoryOption("nightclub", "Nightclub", "Gece kulübü", OfferCategory.NIGHTLIFE),
        BusinessCategoryOption("live-music-venue", "Live music venue", "Canlı müzik mekanı", OfferCategory.NIGHTLIFE),
        BusinessCategoryOption("spa", "Spa", "Spa", OfferCategory.WELLNESS),
        BusinessCategoryOption("wellness-center", "Wellness center", "Wellness merkezi", OfferCategory.WELLNESS),
        BusinessCategoryOption("yoga-pilates", "Yoga / Pilates studio", "Yoga / Pilates stüdyosu", OfferCategory.WELLNESS),
        BusinessCategoryOption("gym-fitness", "Gym / Fitness center", "Spor salonu", OfferCategory.FITNESS),
        BusinessCategoryOption("sports-club", "Sports club", "Spor kulübü", OfferCategory.FITNESS),
        BusinessCategoryOption("dance-studio", "Dance studio", "Dans stüdyosu", OfferCategory.FITNESS),
        BusinessCategoryOption("beauty-salon", "Beauty salon", "Güzellik salonu", OfferCategory.BEAUTY),
        BusinessCategoryOption("hair-salon", "Hair salon / Barber", "Kuaför / Berber", OfferCategory.BEAUTY),
        BusinessCategoryOption("nail-studio", "Nail studio", "Tırnak stüdyosu", OfferCategory.BEAUTY),
        BusinessCategoryOption("cosmetics", "Cosmetics", "Kozmetik", OfferCategory.BEAUTY),
        BusinessCategoryOption("clinic", "Clinic", "Klinik", OfferCategory.WELLNESS),
        BusinessCategoryOption("dentist", "Dentist", "Diş kliniği", OfferCategory.WELLNESS),
        BusinessCategoryOption("pharmacy", "Pharmacy", "Eczane", OfferCategory.WELLNESS),
        BusinessCategoryOption("fashion", "Fashion / Clothing", "Moda / Giyim", OfferCategory.RETAIL),
        BusinessCategoryOption("shoes-accessories", "Shoes / Accessories", "Ayakkabı / Aksesuar", OfferCategory.RETAIL),
        BusinessCategoryOption("jewelry", "Jewelry", "Mücevher", OfferCategory.RETAIL),
        BusinessCategoryOption("home-decor", "Home decor / Furniture", "Ev dekorasyonu / Mobilya", OfferCategory.RETAIL),
        BusinessCategoryOption("electronics", "Electronics", "Elektronik", OfferCategory.RETAIL),
        BusinessCategoryOption("grocery-market", "Grocery / Market", "Market", OfferCategory.RETAIL),
        BusinessCategoryOption("bookstore", "Bookstore", "Kitapçı", OfferCategory.RETAIL),
        BusinessCategoryOption("concept-store", "Concept store", "Konsept mağaza", OfferCategory.RETAIL),
        BusinessCategoryOption("ecommerce", "E-commerce / Online store", "E-ticaret / Online mağaza", OfferCategory.RETAIL),
        BusinessCategoryOption("cinema-theater", "Cinema / Theater", "Sinema / Tiyatro", OfferCategory.NIGHTLIFE),
        BusinessCategoryOption("museum-gallery", "Museum / Art gallery", "Müze / Sanat galerisi", OfferCategory.RETAIL),
        BusinessCategoryOption("entertainment-center", "Entertainment center", "Eğlence merkezi", OfferCategory.NIGHTLIFE),
        BusinessCategoryOption("event-venue", "Event venue", "Etkinlik mekanı", OfferCategory.NIGHTLIFE),
        BusinessCategoryOption("event-planner", "Event planner", "Etkinlik organizasyonu", OfferCategory.RETAIL),
        BusinessCategoryOption("photography-studio", "Photography / Video studio", "Fotoğraf / Video stüdyosu", OfferCategory.RETAIL),
        BusinessCategoryOption("education-training", "Education / Training", "Eğitim / Kurs", OfferCategory.RETAIL),
        BusinessCategoryOption("coworking", "Coworking space", "Ortak çalışma alanı", OfferCategory.RETAIL),
        BusinessCategoryOption("professional-services", "Professional services", "Profesyonel hizmetler", OfferCategory.RETAIL),
        BusinessCategoryOption("real-estate", "Real estate", "Gayrimenkul", OfferCategory.RETAIL),
        BusinessCategoryOption("travel-tourism", "Travel / Tourism", "Seyahat / Turizm", OfferCategory.WELLNESS),
        BusinessCategoryOption("car-dealer-rental", "Car dealer / Rental", "Otomotiv / Araç kiralama", OfferCategory.RETAIL),
        BusinessCategoryOption("pet-services", "Pet shop / Pet services", "Evcil hayvan hizmetleri", OfferCategory.RETAIL),
        BusinessCategoryOption("kids-family", "Kids / Family services", "Çocuk / Aile hizmetleri", OfferCategory.RETAIL),
        BusinessCategoryOption("home-services", "Home services", "Ev hizmetleri", OfferCategory.RETAIL),
        BusinessCategoryOption("digital-technology", "Digital / Technology", "Dijital / Teknoloji", OfferCategory.RETAIL),
        BusinessCategoryOption("nonprofit-community", "Nonprofit / Community", "STK / Topluluk", OfferCategory.RETAIL)
    )

    fun offerCategoryFor(label: String): OfferCategory {
        val normalized = label.trim().lowercase()
        all.firstOrNull {
            it.key == normalized || it.english.lowercase() == normalized || it.turkish.lowercase() == normalized
        }?.let { return it.offerCategory }
        val legacy = mapOf(
            "live-music" to OfferCategory.NIGHTLIFE,
            "wellness" to OfferCategory.WELLNESS,
            "gym" to OfferCategory.FITNESS,
            "accessories" to OfferCategory.RETAIL,
            "grocery" to OfferCategory.RETAIL,
            "entertainment" to OfferCategory.NIGHTLIFE,
            "photo-video" to OfferCategory.RETAIL,
            "education" to OfferCategory.RETAIL,
            "professional" to OfferCategory.RETAIL,
            "travel" to OfferCategory.WELLNESS,
            "automotive" to OfferCategory.RETAIL,
            "technology" to OfferCategory.RETAIL,
            "community" to OfferCategory.RETAIL,
            "dessert" to OfferCategory.DINING
        )
        legacy[normalized]?.let { return it }
        return when {
            Regex("hotel|otel|resort|hostel").containsMatchIn(normalized) -> OfferCategory.WELLNESS
            Regex("restaurant|restoran|cafe|coffee|food|bakery|kafe|yemek").containsMatchIn(normalized) -> OfferCategory.DINING
            Regex("bar|pub|club|lounge|night|music|event|gece|etkinlik").containsMatchIn(normalized) -> OfferCategory.NIGHTLIFE
            Regex("gym|fitness|sport|yoga|pilates|spor").containsMatchIn(normalized) -> OfferCategory.FITNESS
            Regex("beauty|salon|hair|nail|cosmetic|güzellik|kuaför").containsMatchIn(normalized) -> OfferCategory.BEAUTY
            Regex("spa|wellness|clinic|health|sağlık").containsMatchIn(normalized) -> OfferCategory.WELLNESS
            else -> OfferCategory.RETAIL
        }
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
    val notificationType: String = "general",
    val icon: String = "bell.fill",
    val tint: String = "rose",
    val bookingId: String? = null,
    val offerId: String? = null,
    val conversationId: String? = null
) {
    val section: InboxSection
        get() = InboxSection.from(notificationType)
}

enum class InboxSection {
    ACTION_NEEDED, BOOKINGS, MESSAGES, ACCOUNT, OPS;

    companion object {
        fun from(type: String): InboxSection = when (type.lowercase()) {
            "collaboration", "shortlist" -> ACTION_NEEDED
            "booking", "proof" -> BOOKINGS
            "message" -> MESSAGES
            "membership", "social" -> ACCOUNT
            "admin", "campaign", "ops" -> OPS
            else -> ACTION_NEEDED
        }

        fun ordered(role: UserRole): List<InboxSection> = when (role) {
            UserRole.ADMIN -> listOf(OPS, ACTION_NEEDED, MESSAGES, ACCOUNT, BOOKINGS)
            UserRole.VENUE -> listOf(ACTION_NEEDED, BOOKINGS, MESSAGES, ACCOUNT, OPS)
            UserRole.CREATOR -> listOf(ACTION_NEEDED, BOOKINGS, MESSAGES, ACCOUNT, OPS)
        }
    }
}

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
    val createdLabel: String,
    val avatarUrl: String = "",
    val coverUrl: String = "",
    val lastLat: Double? = null,
    val lastLng: Double? = null
) {
    val hasLiveLocation: Boolean get() = lastLat != null && lastLng != null
    val displayName: String get() = fullName.ifBlank { email.substringBefore("@").ifBlank { "Member" } }
}

data class AdminInviteCodeItem(
    val code: String,
    val ownerType: String,
    val maxUses: Int,
    val useCount: Int,
    val inviteEmail: String?,
    val createdLabel: String
)

data class AdminVenueSummary(
    val id: String,
    val venueName: String,
    val area: String,
    val category: String,
    val status: MembershipStatus?,
    val ownerEmail: String,
    val ownerName: String,
    val offerCount: Int,
    val liveOfferCount: Int,
    val bookingCount: Int
)

data class AdminBookingSummary(
    val id: String,
    val offerTitle: String,
    val venueName: String,
    val guestName: String,
    val guestEmail: String,
    val stage: String,
    val dateLabel: String,
    val proofStatus: String
)

data class VenueSummary(
    val id: String,
    val name: String,
    val area: String,
    val category: OfferCategory,
    val isActive: Boolean = false,
    val status: MembershipStatus? = null
)

data class EstablishmentDraft(
    val id: String,
    val venueName: String = "",
    val draftName: String = "",
    val area: String = "",
    val city: String = "",
    val country: String = "",
    val address: String = "",
    val addressLine1: String = "",
    val addressLine2: String = "",
    val postalCode: String = "",
    val instagramHandle: String = "",
    val description: String = "",
    val contactName: String = "",
    val contactPhone: String = "",
    val contactIsSelf: Boolean = false,
    val isPhysical: Boolean = true,
    val categories: List<String> = emptyList(),
    val logoUrl: String = "",
    val detailsComplete: Boolean = false,
    val addressComplete: Boolean = false,
    val photosComplete: Boolean = false,
    val lat: Double? = null,
    val lng: Double? = null
) {
    val displayName: String get() = draftName.ifBlank { venueName }
}

data class BrandSummary(
    val organizationId: String,
    val organizationName: String,
    val brandId: String,
    val brandName: String
)

data class OrganizationBrandCreated(
    val organizationId: String,
    val organizationName: String,
    val brandId: String,
    val brandName: String
)

data class Campaign(
    val id: String,
    val title: String,
    val status: String,
    val venueId: String? = null,
    val venueName: String,
    val dateLabel: String,
    val isDeleted: Boolean = false
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

data class ActivityEventItem(
    val id: String,
    val action: String,
    val subjectType: String,
    val subjectId: String?,
    val createdAtMillis: Long,
    val createdLabel: String,
    val actorLabel: String,
    val actorKind: String,
    val metadata: Map<String, String>
) {
    enum class Category { ALL, BOOKINGS, CAMPAIGNS, ADMIN, MESSAGES, SOCIAL, OTHER }

    val category: Category
        get() {
            val actionKey = action.lowercase()
            val subject = subjectType.lowercase()
            if (actionKey.startsWith("admin_") || (subject == "user" && actionKey.contains("admin"))) {
                return Category.ADMIN
            }
            if (subject == "offer" || actionKey.contains("campaign")) return Category.CAMPAIGNS
            if (subject == "booking" || actionKey.contains("booking") ||
                actionKey.contains("offer_requested") || actionKey.contains("offer_accepted")
            ) {
                return Category.BOOKINGS
            }
            if (subject == "conversation" || actionKey.contains("message")) return Category.MESSAGES
            if (subject == "creator" || subject == "collaboration_request" ||
                actionKey.contains("shortlist") || actionKey.contains("collaboration")
            ) {
                return Category.SOCIAL
            }
            return Category.OTHER
        }

    fun meta(key: String): String? = metadata[key]?.trim()?.takeIf { it.isNotEmpty() }
}
