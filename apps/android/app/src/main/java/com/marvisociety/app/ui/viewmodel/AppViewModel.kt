package com.marvisociety.app.ui.viewmodel

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.marvisociety.app.data.*
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.network.ImageUploadHelper
import com.marvisociety.app.network.MarviApiException
import com.marvisociety.app.network.MarviRepository
import kotlinx.coroutines.launch

class AppViewModel(
    application: Application,
    private val repository: MarviRepository = MarviRepository()
) : AndroidViewModel(application) {

    private val sessionStore = SessionStore(application)

    var hasCompletedOnboarding by mutableStateOf(false)
        private set
    var selectedRole by mutableStateOf(UserRole.CREATOR)
        private set
    var workspaceTabIndex by mutableIntStateOf(0)
        private set
    var preferredLanguage by mutableStateOf(AppLanguage.TURKISH)
        private set
    /** True only after the user explicitly picks a language in Profile. */
    private var languageManuallySet = false

    var isBootstrapping by mutableStateOf(false)
        private set
    var isSyncing by mutableStateOf(false)
        private set
    var isProfileMediaUploading by mutableStateOf(false)
        private set
    var isAuthenticated by mutableStateOf(false)
        private set
    var lastSyncError by mutableStateOf<String?>(null)
        private set
    var authError by mutableStateOf<String?>(null)
        private set

    var accountRole by mutableStateOf(UserRole.CREATOR)
        private set
    var allowedRoles by mutableStateOf(listOf(UserRole.CREATOR))
        private set
    var accountReferralCode by mutableStateOf<String?>(null)
        private set
    var accountPausedBySelf by mutableStateOf(false)
        private set

    var offers by mutableStateOf<List<Offer>>(emptyList())
        private set
    var savedOfferIds by mutableStateOf<Set<String>>(emptySet())
        private set
    var bookings by mutableStateOf<List<Booking>>(emptyList())
        private set
    var profile by mutableStateOf(CreatorProfile())
        private set
    var inboxMessages by mutableStateOf<List<InboxMessage>>(emptyList())
        private set
    var adminTasks by mutableStateOf<List<AdminTask>>(emptyList())
        private set
    var adminUsers by mutableStateOf<List<AdminUserSummary>>(emptyList())
        private set
    var adminInviteCodes by mutableStateOf<List<AdminInviteCodeItem>>(emptyList())
        private set
    var myVenues by mutableStateOf<List<VenueSummary>>(emptyList())
        private set
    var myBrands by mutableStateOf<List<BrandSummary>>(emptyList())
        private set
    var isEstablishmentBusy by mutableStateOf(false)
        private set
    var campaigns by mutableStateOf<List<Campaign>>(emptyList())
        private set
    var swipeCandidates by mutableStateOf<List<InfluencerCandidate>>(emptyList())
        private set
    var venueReviewQueue by mutableStateOf<List<VenueReviewItem>>(emptyList())
        private set
    var memberSearchResults by mutableStateOf<List<MemberSearchResult>>(emptyList())
        private set
    var followingActivity by mutableStateOf<List<MemberActivityItem>>(emptyList())
        private set
    var directThreads by mutableStateOf<List<DirectThread>>(emptyList())
        private set
    var conversations by mutableStateOf<List<ChatConversation>>(emptyList())
        private set
    var pendingCollaborationRequests by mutableStateOf<List<PendingCollaborationRequest>>(emptyList())
        private set
    var followCounts by mutableStateOf(FollowCounts.ZERO)
        private set
    var strikes by mutableStateOf<List<Strike>>(emptyList())
        private set
    var showcaseItems by mutableStateOf<List<ShowcaseItem>>(emptyList())
        private set
    var collaborationHistory by mutableStateOf<List<CollaborationEntry>>(emptyList())
        private set
    var socialVerification by mutableStateOf<SocialVerificationStatus?>(null)
        private set

    /** Deep-link / auth-callback invite code waiting to be redeemed. */
    var pendingInviteCode by mutableStateOf<String?>(null)
        private set

    /** Where a brand-new Google user should continue onboarding after the OAuth callback. */
    enum class PostAuthDestination { PROFILE, VENUE }

    var postGoogleAuthDestination by mutableStateOf<PostAuthDestination?>(null)
        private set

    fun consumePostGoogleAuthDestination() {
        postGoogleAuthDestination = null
    }

    val isRemoteMode: Boolean get() = repository.usesRemoteBackend
    val unreadInboxCount: Int get() = inboxMessages.count { !it.isRead }

    /** Invite codes are no longer required for membership. */
    val needsInviteRedemption: Boolean get() = false

    /** Only paused accounts are blocked; new members can use the app immediately. */
    val needsAdminApproval: Boolean
        get() = isRemoteMode && isAuthenticated && hasCompletedOnboarding &&
            accountRole != UserRole.ADMIN &&
            profile.status == MembershipStatus.PAUSED

    /** Social handles are optional profile enrichment. */
    val needsSocialHandlesEntry: Boolean
        get() = false

    /** Soft nudge only: DM verify recommended for trust, not a hard accept gate. */
    val needsSocialVerification: Boolean
        get() = isRemoteMode && isAuthenticated && hasCompletedOnboarding &&
            accountRole != UserRole.ADMIN &&
            !(allowedRoles.contains(UserRole.VENUE) && selectedRole == UserRole.VENUE) &&
            !(profile.handle.isBlank() && profile.tiktokHandle.isBlank()) &&
            socialVerification?.isVerified != true

    /** Profile completeness UI (handles missing OR verify pending). */
    val needsSocialProfileCompletion: Boolean
        get() = needsSocialHandlesEntry || needsSocialVerification

    /** Explains why Accept is disabled (matches iOS acceptBlockedReason). */
    val acceptBlockedReason: String?
        get() {
            if (!isAuthenticated || !hasCompletedOnboarding) return t(MarviL10n.Key.SIGN_IN_TO_ACCEPT)
            if (accountRole == UserRole.ADMIN) return null
            if (needsAdminApproval) {
                return when (profile.status) {
                    MembershipStatus.PAUSED -> t(MarviL10n.Key.MEMBERSHIP_PAUSED)
                    else -> t(MarviL10n.Key.AWAITING_APPROVAL)
                }
            }
            return when (profile.status) {
                MembershipStatus.UNDER_REVIEW -> null
                MembershipStatus.PAUSED -> t(MarviL10n.Key.MEMBERSHIP_PAUSED)
                MembershipStatus.APPROVED -> null
                else -> t(MarviL10n.Key.COMPLETE_PROFILE_TO_ACCEPT)
            }
        }

    val canAcceptOffers: Boolean
        get() {
            if (!isAuthenticated || !hasCompletedOnboarding) return false
            if (accountRole == UserRole.ADMIN) return true
            return !needsAdminApproval
        }

    val pendingInviteBookingsCount: Int
        get() = bookings.count { it.stage == BookingStage.INVITED }

    val eventsTabBadgeCount: Int
        get() = pendingInviteBookingsCount.coerceAtMost(99)

    val acceptedOfferIds: Set<String>
        get() = bookings.filter { it.stage != BookingStage.CANCELLED }.map { it.offer.id }.toSet()

    val interestOffers: List<Offer>
        get() = offers.filter { savedOfferIds.contains(it.id) && !acceptedOfferIds.contains(it.id) }

    init {
        repository.setSessionObserver { access, refresh ->
            sessionStore.saveTokens(access, refresh)
        }
        viewModelScope.launch {
            val snapshot = sessionStore.loadSnapshot()
            hasCompletedOnboarding = snapshot.hasCompletedOnboarding
            selectedRole = snapshot.selectedRole
            languageManuallySet = snapshot.languageManuallySet
            // Istanbul Turkish is the default; only honor a stored language when the
            // user explicitly picked one in Profile.
            preferredLanguage = if (snapshot.languageManuallySet) {
                snapshot.preferredLanguage
            } else {
                AppLanguage.TURKISH
            }

            if (repository.usesRemoteBackend) {
                val (access, refresh) = sessionStore.loadTokens()
                repository.restoreSession(access, refresh)
                isAuthenticated = repository.isAuthenticated
                if (isAuthenticated) bootstrapRemoteSession()
            } else {
                loadDemoData()
            }
        }
    }

    fun t(key: MarviL10n.Key): String = MarviL10n.t(key, preferredLanguage)

    fun categoryLabel(category: com.marvisociety.app.data.OfferCategory): String =
        MarviL10n.categoryLabel(category, preferredLanguage)

    fun modelLabel(model: com.marvisociety.app.data.CollaborationModel): String =
        MarviL10n.modelLabel(model, preferredLanguage)

    fun stageLabel(stage: com.marvisociety.app.data.BookingStage): String =
        MarviL10n.stageLabel(stage, preferredLanguage)

    fun roleLabel(role: UserRole): String =
        MarviL10n.roleLabel(role, preferredLanguage)

    fun taskTypeLabel(type: com.marvisociety.app.data.AdminTaskType): String =
        MarviL10n.taskTypeLabel(type, preferredLanguage)

    fun priorityLabel(priority: String): String =
        MarviL10n.priorityLabel(priority, preferredLanguage)

    fun localizeServerText(text: String): String =
        MarviL10n.localizeServerText(text, preferredLanguage)

    fun setWorkspaceTab(index: Int) {
        workspaceTabIndex = index
    }

    fun switchRole(role: UserRole) {
        selectedRole = role
        workspaceTabIndex = 0
        persistSnapshot()
    }

    fun switchLanguage(language: AppLanguage) {
        preferredLanguage = language
        languageManuallySet = true
        persistSnapshot()
    }

    fun dismissSyncError() {
        lastSyncError = null
    }

    private fun loadDemoData() {
        offers = SampleData.offers
        bookings = SampleData.bookings
        profile = SampleData.profile
        savedOfferIds = setOf("1", "3")
    }

    private suspend fun bootstrapRemoteSession() {
        isBootstrapping = true
        authError = null
        runCatching {
            runCatching {
                repository.refreshSession()
                sessionStore.saveTokens(repository.accessToken(), repository.refreshToken())
            }
            refreshFromServerInternal()
        }.onFailure { error ->
            if (error is MarviApiException && error.code == 401) {
                isAuthenticated = false
                sessionStore.saveTokens(null, null)
            } else {
                lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
            }
        }
        isBootstrapping = false
    }

    fun refreshFromServer() {
        viewModelScope.launch {
            isSyncing = true
            lastSyncError = null
            runCatching {
                refreshFromServerInternal()
            }.onFailure { error ->
                if (error is MarviApiException && error.code == 401) {
                    runCatching {
                        repository.refreshSession()
                        sessionStore.saveTokens(repository.accessToken(), repository.refreshToken())
                        refreshFromServerInternal()
                    }.onFailure {
                        isAuthenticated = false
                        sessionStore.saveTokens(null, null)
                        lastSyncError = it.message ?: t(MarviL10n.Key.SYNC_ERROR)
                    }
                } else {
                    lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
                }
            }
            isSyncing = false
        }
    }

    private suspend fun refreshFromServerInternal() {
                if (repository.usesRemoteBackend && repository.isAuthenticated) {
                    val context = repository.fetchAccountContext()
                    accountRole = context.role
                    allowedRoles = UserRole.allowedWorkspaces(context.role)
                    accountReferralCode = context.referralCode
                    accountPausedBySelf = context.pausedBySelf
                    if (!allowedRoles.contains(selectedRole)) {
                        selectedRole = allowedRoles.firstOrNull() ?: UserRole.CREATOR
                    }

                    profile = repository.fetchProfile().copy(
                        status = context.membershipStatus?.let {
                            when (it) {
                                MembershipStatus.APPROVED -> MembershipStatus.APPROVED
                                MembershipStatus.PAUSED -> MembershipStatus.PAUSED
                                MembershipStatus.UNDER_REVIEW -> MembershipStatus.UNDER_REVIEW
                            }
                        } ?: profile.status
                    )
                    offers = repository.fetchOffers(profile.city)
                    bookings = repository.fetchBookings().map { booking ->
                        if (selectedRole == UserRole.VENUE) booking
                        else booking.copy(checkInCode = "")
                    }
                    savedOfferIds = repository.fetchSavedOfferIds()
                    inboxMessages = repository.fetchNotifications()
                    followCounts = repository.fetchMyFollowCounts()
                    strikes = repository.fetchStrikes()
                    if (accountRole != UserRole.ADMIN) {
                        socialVerification = repository.ensureSocialVerificationCode()
                        showcaseItems = runCatching { repository.fetchMyShowcase() }.getOrDefault(showcaseItems)
                        collaborationHistory = runCatching { repository.fetchMyCollaborationHistory() }.getOrDefault(collaborationHistory)
                    }

                    when (selectedRole) {
                        UserRole.ADMIN -> {
                            adminTasks = repository.fetchAdminTasks()
                            adminUsers = repository.fetchAdminUsers(null, null)
                            adminInviteCodes = repository.fetchAdminInviteCodes()
                        }
                        UserRole.VENUE -> {
                            myVenues = repository.fetchMyVenues()
                            myBrands = runCatching { repository.fetchMyBrands() }.getOrDefault(myBrands)
                            campaigns = repository.fetchCampaigns()
                            swipeCandidates = runCatching { repository.fetchSwipeCandidates(null) }.getOrDefault(swipeCandidates)
                            venueReviewQueue = runCatching { repository.fetchVenueReviewQueue() }.getOrDefault(venueReviewQueue)
                        }
                        UserRole.CREATOR -> {
                            pendingCollaborationRequests = runCatching {
                                repository.fetchPendingCollaborationRequests()
                            }.getOrDefault(pendingCollaborationRequests)
                        }
                    }
                }
    }

    fun signIn(email: String, password: String, onSuccess: () -> Unit) {
        viewModelScope.launch {
            authError = null
            isBootstrapping = true
            runCatching {
                val session = repository.signInWithEmail(email, password)
                sessionStore.saveTokens(session.accessToken, session.refreshToken)
                isAuthenticated = true
                bootstrapRemoteSession()
                onSuccess()
            }.onFailure { error ->
                authError = error.message ?: t(MarviL10n.Key.ERR_SIGN_IN_REQUIRED)
            }
            isBootstrapping = false
        }
    }

    fun startGoogleSignIn(context: android.content.Context, role: UserRole = UserRole.CREATOR) {
        if (!com.marvisociety.app.network.GoogleOAuth.isEnabled()) {
            authError = t(MarviL10n.Key.ERR_SIGN_IN_REQUIRED)
            return
        }
        authError = null
        lastSyncError = null
        selectedRole = role
        persistSnapshot()
        runCatching {
            com.marvisociety.app.network.GoogleOAuth.start(context, role.name)
        }.onFailure { error ->
            authError = error.message ?: t(MarviL10n.Key.ERR_SIGN_IN_REQUIRED)
        }
    }

    fun completeGoogleSignIn(uri: android.net.Uri) {
        viewModelScope.launch {
            authError = null
            isBootstrapping = true
            runCatching {
                val completion = repository.completeGoogleOAuth(uri, getApplication())
                val session = completion.session
                completion.role?.let { roleName ->
                    runCatching { UserRole.valueOf(roleName) }
                        .getOrNull()
                        ?.let { selectedRole = it }
                }
                sessionStore.saveTokens(session.accessToken, session.refreshToken)
                isAuthenticated = true
                // Route exactly like the email sign-in path: existing members drop
                // straight into the app; new Google users continue onboarding at the
                // profile/venue step. Without this the app kept showing the WELCOME
                // page after a successful Google login.
                val existing = isExistingMemberOnServer()
                if (existing) {
                    val role = when {
                        allowedRoles.contains(UserRole.VENUE) && selectedRole == UserRole.VENUE -> UserRole.VENUE
                        else -> allowedRoles.firstOrNull() ?: UserRole.CREATOR
                    }
                    finishOnboarding(role)
                } else {
                    postGoogleAuthDestination = if (selectedRole == UserRole.VENUE) {
                        PostAuthDestination.VENUE
                    } else {
                        PostAuthDestination.PROFILE
                    }
                }
            }.onFailure { error ->
                authError = error.message ?: t(MarviL10n.Key.ERR_SIGN_IN_REQUIRED)
                lastSyncError = authError
            }
            isBootstrapping = false
        }
    }

    fun signUp(
        email: String,
        password: String,
        fullName: String,
        city: String,
        intent: String = "creator",
        inviteCode: String? = null,
        onSuccess: () -> Unit
    ) {
        viewModelScope.launch {
            authError = null
            isBootstrapping = true
            runCatching {
                val meta = mutableMapOf(
                    "full_name" to fullName,
                    "city" to city.lowercase(),
                    "signup_intent" to intent,
                    "locale" to if (preferredLanguage == AppLanguage.TURKISH) "tr" else "en"
                )
                val code = inviteCode?.trim()?.uppercase().orEmpty()
                if (code.isNotEmpty()) meta["invite_code"] = code
                val session = repository.signUpWithEmail(email, password, meta)
                sessionStore.saveTokens(session.accessToken, session.refreshToken)
                isAuthenticated = true
                bootstrapRemoteSession()
                onSuccess()
            }.onFailure { error ->
                authError = error.message
            }
            isBootstrapping = false
        }
    }

    fun applyPendingInviteCode(code: String?) {
        val normalized = code?.trim()?.uppercase()?.takeIf { it.isNotEmpty() }
        pendingInviteCode = normalized
    }

    fun routeAfterAuthentication(onResult: (existingMember: Boolean, role: UserRole) -> Unit) {
        viewModelScope.launch {
            runCatching {
                val existing = isExistingMemberOnServer()
                val role = when {
                    existing && allowedRoles.contains(UserRole.VENUE) && selectedRole == UserRole.VENUE -> UserRole.VENUE
                    existing -> allowedRoles.firstOrNull() ?: UserRole.CREATOR
                    else -> selectedRole
                }
                onResult(existing, role)
            }.onFailure {
                onResult(false, selectedRole)
            }
        }
    }

    private suspend fun isExistingMemberOnServer(): Boolean {
        if (!isRemoteMode || !isAuthenticated) return false
        val context = runCatching { repository.fetchAccountContext() }.getOrNull() ?: return false
        accountRole = context.role
        allowedRoles = UserRole.allowedWorkspaces(context.role)
        accountReferralCode = context.referralCode
        if (context.role == UserRole.ADMIN) return true
        if (context.hasVenueProfile) return true
        val current = runCatching { repository.fetchProfile() }.getOrNull() ?: profile
        profile = current
        return (current.handle.isNotBlank() || current.tiktokHandle.isNotBlank()) && current.city.isNotBlank()
    }

    fun resetPassword(email: String, onSent: () -> Unit) {
        viewModelScope.launch {
            runCatching {
                repository.resetPassword(email)
                onSent()
            }.onFailure { error ->
                authError = error.message
            }
        }
    }

    fun validateAndRedeemInvite(code: String, onResult: (Boolean) -> Unit) {
        viewModelScope.launch {
            val valid = runCatching { repository.validateReferralCode(code) }.getOrDefault(false)
            if (!valid) {
                onResult(false)
                return@launch
            }
            runCatching {
                repository.redeemReferralCode(code)
                accountReferralCode = code.trim().uppercase()
                refreshFromServer()
                onResult(true)
            }.onFailure {
                onResult(false)
            }
        }
    }

    fun completeProfileSetup(
        name: String,
        handle: String,
        tiktok: String,
        city: String,
        onDone: (Boolean) -> Unit
    ) {
        viewModelScope.launch {
            val updated = profile.copy(
                name = name.trim(),
                handle = handle.trim().removePrefix("@"),
                tiktokHandle = tiktok.trim().removePrefix("@"),
                city = city.trim()
            )
            runCatching {
                if (repository.usesRemoteBackend && isAuthenticated) {
                    repository.updateProfile(updated)
                }
                profile = updated
            }.onSuccess {
                onDone(true)
            }.onFailure { error ->
                lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
                onDone(false)
            }
        }
    }

    fun updateProfileHandle(handle: String) {
        profile = profile.copy(handle = handle.removePrefix("@"))
    }

    fun updateProfileTiktok(tiktok: String) {
        profile = profile.copy(tiktokHandle = tiktok.removePrefix("@"))
    }

    fun updateProfileCity(city: String) {
        profile = profile.copy(city = city.trim())
    }

    fun updateProfileBio(bio: String) {
        profile = profile.copy(bio = bio)
    }

    fun saveProfileFromEditor() {
        viewModelScope.launch {
            if (repository.usesRemoteBackend && isAuthenticated) {
                runCatching {
                    repository.updateProfile(profile)
                    socialVerification = repository.ensureSocialVerificationCode()
                }.onFailure { error ->
                    lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
                }
            }
        }
    }

    fun loadSocialVerification() {
        viewModelScope.launch {
            runCatching {
                socialVerification = repository.ensureSocialVerificationCode()
            }.onFailure { error ->
                lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
            }
        }
    }

    fun submitSocialVerificationSent(onResult: (Boolean) -> Unit) {
        viewModelScope.launch {
            runCatching {
                socialVerification = repository.submitSocialVerificationDm()
                onResult(true)
            }.onFailure {
                lastSyncError = it.message
                onResult(false)
            }
        }
    }

    fun finishOnboarding(role: UserRole = selectedRole) {
        selectedRole = role
        hasCompletedOnboarding = true
        persistSnapshot()
        refreshFromServer()
    }

    fun toggleSaved(offerId: String) {
        if (repository.usesRemoteBackend && isAuthenticated) {
            viewModelScope.launch {
                runCatching {
                    val saved = repository.toggleSavedOffer(offerId)
                    savedOfferIds = if (saved) savedOfferIds + offerId else savedOfferIds - offerId
                }.onFailure { error ->
                    lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
                }
            }
        } else {
            savedOfferIds = if (offerId in savedOfferIds) savedOfferIds - offerId else savedOfferIds + offerId
        }
    }

    fun acceptOffer(
        offerId: String,
        shippingAddress: String? = null,
        rsvpGuests: Int? = null,
        onResult: (Boolean) -> Unit = {}
    ) {
        if (needsAdminApproval || needsSocialHandlesEntry || profile.status != MembershipStatus.APPROVED) {
            lastSyncError = acceptBlockedReason ?: t(MarviL10n.Key.COMPLETE_PROFILE_TO_ACCEPT)
            onResult(false)
            return
        }
        viewModelScope.launch {
            runCatching {
                if (repository.usesRemoteBackend && isAuthenticated) {
                    val booking = repository.acceptOffer(
                        offerId,
                        AcceptOfferOptions(shippingAddress = shippingAddress, rsvpGuests = rsvpGuests)
                    )
                    bookings = listOf(booking) + bookings.filter { it.id != booking.id }
                }
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message
                onResult(false)
            }
        }
    }

    fun cancelBooking(bookingId: String, onResult: (Boolean) -> Unit = {}) {
        viewModelScope.launch {
            runCatching {
                repository.cancelBooking(bookingId)
                bookings = bookings.map {
                    if (it.id == bookingId) it.copy(stage = BookingStage.CANCELLED) else it
                }
                loadPendingCollaborationRequests()
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message
                onResult(false)
            }
        }
    }

    fun loadConversations() {
        if (!repository.usesRemoteBackend || !isAuthenticated) return
        viewModelScope.launch {
            runCatching {
                conversations = repository.fetchConversations()
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    suspend fun fetchConversationMessages(conversationId: String): List<ChatMessage> =
        repository.fetchConversationMessages(conversationId)

    suspend fun sendConversationMessage(conversationId: String, body: String): ChatMessage =
        repository.sendConversationMessage(conversationId, body)

    fun loadPendingCollaborationRequests() {
        if (!repository.usesRemoteBackend || !isAuthenticated) return
        viewModelScope.launch {
            runCatching {
                pendingCollaborationRequests = repository.fetchPendingCollaborationRequests()
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    fun creatorAcceptCollaboration(requestId: String, onResult: (Boolean) -> Unit = {}) {
        viewModelScope.launch {
            runCatching {
                val booking = repository.creatorAcceptCollaboration(requestId)
                bookings = listOf(booking) + bookings.filter { it.id != booking.id }
                pendingCollaborationRequests = pendingCollaborationRequests.filter { it.id != requestId }
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message
                onResult(false)
            }
        }
    }

    fun submitCreatorReview(
        bookingId: String,
        hospitality: Int,
        experience: Int,
        comment: String,
        onResult: (Boolean) -> Unit = {}
    ) {
        viewModelScope.launch {
            runCatching {
                repository.submitCreatorReview(bookingId, hospitality, experience, comment)
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message
                onResult(false)
            }
        }
    }

    fun checkIn(bookingId: String, code: String, onResult: (Boolean) -> Unit = {}) {
        viewModelScope.launch {
            runCatching {
                val booking = repository.checkIn(bookingId, code)
                bookings = bookings.map { if (it.id == booking.id) booking else it }
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message
                onResult(false)
            }
        }
    }

    fun submitProof(
        bookingId: String,
        links: List<String>,
        screenshotUri: android.net.Uri? = null,
        onResult: (Boolean) -> Unit = {}
    ) {
        viewModelScope.launch {
            runCatching {
                val allLinks = links.toMutableList()
                if (screenshotUri != null) {
                    val bytes = ImageUploadHelper.prepareJpeg(
                        getApplication(),
                        screenshotUri,
                        ImageUploadHelper.Profile.PROOF
                    )
                    val fileName = "proof-${bookingId.take(8)}.jpg"
                    val path = repository.uploadProofImage(bookingId, bytes, fileName)
                    allLinks.add(path)
                }
                if (allLinks.isEmpty()) {
                    throw MarviApiException("Add a proof link or screenshot")
                }
                val booking = repository.submitProof(bookingId, allLinks)
                bookings = bookings.map { if (it.id == booking.id) booking else it }
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message
                onResult(false)
            }
        }
    }

    fun uploadProfilePhoto(uri: android.net.Uri, kind: String = "avatar") {
        if (isProfileMediaUploading) return
        isProfileMediaUploading = true
        viewModelScope.launch {
            runCatching {
                val profileKind = when (kind) {
                    "cover" -> ImageUploadHelper.Profile.COVER
                    else -> ImageUploadHelper.Profile.AVATAR
                }
                val bytes = ImageUploadHelper.prepareJpeg(getApplication(), uri, profileKind)
                val fileName = "$kind.jpg"
                val url = repository.uploadProfileImage(bytes, fileName, kind)
                if (repository.usesRemoteBackend && isAuthenticated) {
                    repository.setMyProfileImage(kind, url)
                }
                profile = if (kind == "cover") {
                    profile.copy(coverUrl = url)
                } else {
                    profile.copy(avatarUrl = url)
                }
            }.onFailure { error -> lastSyncError = error.message }
            isProfileMediaUploading = false
        }
    }

    fun registerVenue(
        name: String,
        area: String,
        category: OfferCategory,
        contactName: String,
        categoryLabel: String = category.api,
        onResult: (Boolean) -> Unit
    ) {
        viewModelScope.launch {
            runCatching {
                repository.registerVenueLocation(name, area, categoryLabel, contactName)
                myVenues = repository.fetchMyVenues()
                val context = repository.fetchAccountContext()
                accountRole = context.role
                allowedRoles = UserRole.allowedWorkspaces(context.role)
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
                onResult(false)
            }
        }
    }

    fun loadMyBrands() {
        if (!repository.usesRemoteBackend || !isAuthenticated) return
        viewModelScope.launch {
            runCatching {
                myBrands = repository.fetchMyBrands()
            }.onFailure { error ->
                lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
            }
        }
    }

    fun createOrganizationWithBrand(
        organizationName: String,
        brandName: String,
        onResult: (BrandSummary?) -> Unit
    ) {
        viewModelScope.launch {
            isEstablishmentBusy = true
            runCatching {
                val created = repository.createOrganizationWithBrand(organizationName, brandName)
                val brand = BrandSummary(
                    organizationId = created.organizationId,
                    organizationName = created.organizationName,
                    brandId = created.brandId,
                    brandName = created.brandName
                )
                myBrands = myBrands.filterNot { it.brandId == brand.brandId } + brand
                brand
            }.onSuccess {
                onResult(it)
            }.onFailure { error ->
                lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
                onResult(null)
            }
            isEstablishmentBusy = false
        }
    }

    fun createEstablishmentDraft(
        brandId: String,
        establishmentName: String,
        onResult: (String?) -> Unit
    ) {
        viewModelScope.launch {
            isEstablishmentBusy = true
            runCatching {
                val venueId = repository.createEstablishmentDraft(brandId, establishmentName)
                myVenues = repository.fetchMyVenues()
                venueId
            }.onSuccess {
                onResult(it)
            }.onFailure { error ->
                lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
                onResult(null)
            }
            isEstablishmentBusy = false
        }
    }

    fun saveEstablishmentDetails(
        venueId: String,
        instagramHandle: String,
        description: String,
        categories: List<String>,
        contactName: String,
        contactPhone: String,
        contactIsSelf: Boolean,
        offerCategory: OfferCategory,
        onResult: (Boolean) -> Unit
    ) {
        viewModelScope.launch {
            isEstablishmentBusy = true
            runCatching {
                repository.upsertEstablishmentDetails(
                    venueId = venueId,
                    instagramHandle = instagramHandle,
                    description = description,
                    categories = categories,
                    contactName = contactName,
                    contactPhone = contactPhone,
                    contactIsSelf = contactIsSelf,
                    offerCategory = offerCategory.api
                )
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
                onResult(false)
            }
            isEstablishmentBusy = false
        }
    }

    fun saveEstablishmentAddress(
        venueId: String,
        isPhysical: Boolean,
        country: String,
        city: String,
        locationLabel: String,
        addressLine1: String,
        addressLine2: String,
        postalCode: String,
        lat: Double?,
        lng: Double?,
        onResult: (Boolean) -> Unit
    ) {
        viewModelScope.launch {
            isEstablishmentBusy = true
            runCatching {
                repository.upsertEstablishmentAddress(
                    venueId = venueId,
                    isPhysical = isPhysical,
                    country = country,
                    city = city,
                    locationLabel = locationLabel,
                    addressLine1 = addressLine1,
                    addressLine2 = addressLine2,
                    postalCode = postalCode,
                    lat = lat,
                    lng = lng
                )
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
                onResult(false)
            }
            isEstablishmentBusy = false
        }
    }

    fun saveEstablishmentPhotos(
        venueId: String,
        logoUri: android.net.Uri,
        galleryUris: List<android.net.Uri>,
        onResult: (Boolean) -> Unit
    ) {
        viewModelScope.launch {
            isEstablishmentBusy = true
            runCatching {
                if (galleryUris.size < 3) {
                    throw MarviApiException(t(MarviL10n.Key.EST_PHOTOS_MIN))
                }
                val logoBytes = ImageUploadHelper.prepareJpeg(
                    getApplication(),
                    logoUri,
                    ImageUploadHelper.Profile.AVATAR
                )
                val logoUrl = repository.uploadVenueLogo(venueId, logoBytes)
                val galleryUrls = galleryUris.mapIndexed { index, uri ->
                    val bytes = ImageUploadHelper.prepareJpeg(
                        getApplication(),
                        uri,
                        ImageUploadHelper.Profile.COVER
                    )
                    repository.uploadVenueGalleryImage(venueId, bytes, index)
                }
                repository.upsertEstablishmentPhotos(venueId, logoUrl, galleryUrls)
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
                onResult(false)
            }
            isEstablishmentBusy = false
        }
    }

    fun submitEstablishmentForReview(venueId: String, onResult: (Boolean) -> Unit) {
        viewModelScope.launch {
            isEstablishmentBusy = true
            runCatching {
                repository.submitEstablishmentForReview(venueId)
                myVenues = repository.fetchMyVenues()
                val context = repository.fetchAccountContext()
                accountRole = context.role
                allowedRoles = UserRole.allowedWorkspaces(context.role)
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
                onResult(false)
            }
            isEstablishmentBusy = false
        }
    }

    suspend fun createCampaign(
        title: String,
        model: CollaborationModel,
        dateLabel: String,
        valueLabel: String,
        slots: Int,
        deliverables: List<String>,
        imageUri: android.net.Uri? = null,
        description: String = "",
        timeLabel: String = "Flexible",
        requirements: List<String> = emptyList(),
        hostNote: String = ""
    ): Boolean {
        return runCatching {
            lastSyncError = null
            val venue = myVenues.firstOrNull { it.isActive } ?: myVenues.firstOrNull()
                ?: throw MarviApiException("No venue profile linked")
            var imageName = ""
            if (imageUri != null) {
                val bytes = ImageUploadHelper.prepareJpeg(
                    getApplication(),
                    imageUri,
                    ImageUploadHelper.Profile.COVER
                )
                imageName = repository.uploadVenueCampaignImage(venue.id, bytes, "campaign.jpg")
            }
            repository.createCampaign(
                title = title,
                category = venue.category.api,
                model = model.api,
                dateLabel = dateLabel,
                valueLabel = valueLabel.ifBlank { t(MarviL10n.Key.CAMPAIGN_DEFAULT_VALUE) },
                slots = slots,
                deliverables = deliverables,
                venueId = venue.id,
                imageName = imageName,
                description = description,
                timeLabel = timeLabel.ifBlank { t(MarviL10n.Key.VALUE_FLEXIBLE) },
                requirements = requirements,
                hostNote = hostNote
            )
            campaigns = repository.fetchCampaigns()
            true
        }.getOrElse { error ->
            lastSyncError = error.message
            false
        }
    }

    fun loadSwipeCandidates() {
        viewModelScope.launch {
            runCatching { swipeCandidates = repository.fetchSwipeCandidates(null) }
                .onFailure { error -> lastSyncError = error.message }
        }
    }

    fun shortlistCreator(creatorId: String) {
        viewModelScope.launch {
            runCatching {
                repository.shortlistCreator(creatorId, null)
                swipeCandidates = swipeCandidates.filterNot { it.id == creatorId }
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    fun passCreator(creatorId: String) {
        viewModelScope.launch {
            runCatching {
                repository.passCreator(creatorId, null)
                swipeCandidates = swipeCandidates.filterNot { it.id == creatorId }
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    fun loadVenueReviewQueue() {
        viewModelScope.launch {
            runCatching { venueReviewQueue = repository.fetchVenueReviewQueue() }
                .onFailure { error -> lastSyncError = error.message }
        }
    }

    fun submitVenueReview(
        bookingId: String,
        punctuality: Int,
        presentation: Int,
        comment: String,
        onResult: (Boolean) -> Unit
    ) {
        viewModelScope.launch {
            runCatching {
                repository.submitVenueReview(bookingId, punctuality, presentation, comment)
                venueReviewQueue = repository.fetchVenueReviewQueue()
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message
                onResult(false)
            }
        }
    }

    fun searchMembers(query: String?) {
        viewModelScope.launch {
            runCatching {
                memberSearchResults = repository.searchMembers(query)
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    fun loadFollowingActivity() {
        viewModelScope.launch {
            runCatching {
                followingActivity = repository.fetchFollowingActivity()
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    fun loadDirectThreads() {
        viewModelScope.launch {
            runCatching {
                directThreads = repository.fetchDirectThreads()
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    suspend fun fetchDirectMessages(threadId: String): List<ChatMessage> =
        repository.fetchDirectMessages(threadId)

    suspend fun sendDirectMessage(threadId: String, body: String): ChatMessage =
        repository.sendDirectMessage(threadId, body)

    suspend fun fetchCreatorPublicProfile(creatorId: String): PublicCreatorProfile? =
        repository.fetchCreatorPublicProfile(creatorId)

    suspend fun fetchVenuePublicProfile(venueId: String): PublicVenueProfile? =
        repository.fetchVenuePublicProfile(venueId)

    fun followUser(userId: String, onResult: (Boolean) -> Unit = {}) {
        viewModelScope.launch {
            runCatching { repository.followUser(userId) }
                .onSuccess { onResult(true) }
                .onFailure { error ->
                    lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
                    onResult(false)
                }
        }
    }

    fun unfollowUser(userId: String, onResult: (Boolean) -> Unit = {}) {
        viewModelScope.launch {
            runCatching { repository.unfollowUser(userId) }
                .onSuccess { onResult(true) }
                .onFailure { error ->
                    lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
                    onResult(false)
                }
        }
    }

    suspend fun openDirectThread(peerUserId: String): String =
        repository.ensureDirectThread(peerUserId)

    fun pauseAccount() {
        viewModelScope.launch {
            runCatching {
                repository.pauseOwnAccount()
                refreshFromServer()
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    fun reactivateAccount() {
        viewModelScope.launch {
            runCatching {
                repository.reactivateOwnAccount()
                refreshFromServer()
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    fun deleteAccountPermanently(onDone: (String?) -> Unit) {
        viewModelScope.launch {
            runCatching {
                repository.deleteOwnAccountPermanently()
                sessionStore.clearAll()
                isAuthenticated = false
                hasCompletedOnboarding = false
                accountReferralCode = null
                socialVerification = null
                loadDemoData()
                onDone(null)
            }.onFailure { error ->
                lastSyncError = error.message
                onDone(error.message)
            }
        }
    }

    fun loadShowcase() {
        viewModelScope.launch {
            runCatching { showcaseItems = repository.fetchMyShowcase() }
                .onFailure { error -> lastSyncError = error.message }
        }
    }

    fun deleteShowcaseItem(id: String) {
        viewModelScope.launch {
            runCatching {
                repository.deleteShowcaseItem(id)
                showcaseItems = showcaseItems.filterNot { it.id == id }
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    fun addShowcaseLink(externalUrl: String, caption: String, onDone: () -> Unit) {
        viewModelScope.launch {
            runCatching {
                repository.addShowcaseItem(ShowcaseMediaType.LINK, "", externalUrl.trim(), caption.trim())
                showcaseItems = repository.fetchMyShowcase()
                onDone()
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    suspend fun fetchProfileComments(targetUserId: String): List<ProfileComment> =
        repository.fetchProfileComments(targetUserId)

    fun addProfileComment(targetUserId: String, body: String, onDone: () -> Unit) {
        viewModelScope.launch {
            runCatching {
                repository.addProfileComment(targetUserId, body)
                onDone()
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    fun markInboxRead(id: String) {
        viewModelScope.launch {
            runCatching {
                repository.markNotificationRead(id)
                inboxMessages = inboxMessages.map { if (it.id == id) it.copy(isRead = true) else it }
            }.onFailure { error ->
                lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
            }
        }
    }

    fun adminCreateInvite(
        code: String?,
        ownerType: String,
        maxUses: Int,
        inviteEmail: String?,
        onResult: (Boolean) -> Unit
    ) {
        viewModelScope.launch {
            runCatching {
                repository.adminCreateInviteCode(code, ownerType, maxUses, inviteEmail)
                adminInviteCodes = repository.fetchAdminInviteCodes()
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message
                onResult(false)
            }
        }
    }

    fun approveTask(taskId: String, onResult: (Boolean) -> Unit = {}) {
        viewModelScope.launch {
            runCatching {
                repository.approveTask(taskId)
                adminTasks = repository.fetchAdminTasks()
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message
                onResult(false)
            }
        }
    }

    fun rejectTask(taskId: String, onResult: (Boolean) -> Unit = {}) {
        viewModelScope.launch {
            runCatching {
                repository.rejectTask(taskId)
                adminTasks = repository.fetchAdminTasks()
            }.onSuccess {
                onResult(true)
            }.onFailure { error ->
                lastSyncError = error.message
                onResult(false)
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            runCatching { repository.signOut() }
            sessionStore.clearAll()
            isAuthenticated = false
            hasCompletedOnboarding = false
            accountReferralCode = null
            socialVerification = null
            loadDemoData()
        }
    }

    private fun persistSnapshot() {
        viewModelScope.launch {
            sessionStore.saveSnapshot(
                AppSnapshot(
                    hasCompletedOnboarding = hasCompletedOnboarding,
                    selectedRole = selectedRole,
                    preferredLanguage = preferredLanguage,
                    languageManuallySet = languageManuallySet
                )
            )
        }
    }
}
