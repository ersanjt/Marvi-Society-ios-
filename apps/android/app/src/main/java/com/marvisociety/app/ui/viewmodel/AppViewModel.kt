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
    var preferredLanguage by mutableStateOf(AppLanguage.ENGLISH)
        private set

    var isBootstrapping by mutableStateOf(false)
        private set
    var isSyncing by mutableStateOf(false)
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
    var campaigns by mutableStateOf<List<Campaign>>(emptyList())
        private set
    var memberSearchResults by mutableStateOf<List<MemberSearchResult>>(emptyList())
        private set
    var followingActivity by mutableStateOf<List<MemberActivityItem>>(emptyList())
        private set
    var directThreads by mutableStateOf<List<DirectThread>>(emptyList())
        private set
    var followCounts by mutableStateOf(FollowCounts.ZERO)
        private set
    var strikes by mutableStateOf<List<Strike>>(emptyList())
        private set
    var socialVerification by mutableStateOf<SocialVerificationStatus?>(null)
        private set

    /** Deep-link / auth-callback invite code waiting to be redeemed. */
    var pendingInviteCode by mutableStateOf<String?>(null)
        private set

    val isRemoteMode: Boolean get() = repository.usesRemoteBackend
    val unreadInboxCount: Int get() = inboxMessages.count { !it.isRead }

    val needsInviteRedemption: Boolean
        get() = isRemoteMode && isAuthenticated && hasCompletedOnboarding &&
            accountRole != UserRole.ADMIN && accountReferralCode.isNullOrBlank()

    /** Hard gate: Instagram or TikTok handle (matches iOS needsSocialHandlesEntry). */
    val needsSocialHandlesEntry: Boolean
        get() = isRemoteMode && isAuthenticated && hasCompletedOnboarding &&
            !needsInviteRedemption && accountRole != UserRole.ADMIN &&
            !(allowedRoles.contains(UserRole.VENUE) && selectedRole == UserRole.VENUE) &&
            profile.handle.isBlank() && profile.tiktokHandle.isBlank()

    /** Soft gate for accept: at least one handle + DM verification (matches iOS). */
    val needsSocialProfileCompletion: Boolean
        get() = isRemoteMode && isAuthenticated && hasCompletedOnboarding &&
            !needsInviteRedemption && accountRole != UserRole.ADMIN &&
            !(allowedRoles.contains(UserRole.VENUE) && selectedRole == UserRole.VENUE) &&
            ((profile.handle.isBlank() && profile.tiktokHandle.isBlank()) ||
                socialVerification?.isVerified != true)

    /** Explains why Accept is disabled (matches iOS acceptBlockedReason). */
    val acceptBlockedReason: String?
        get() {
            if (!isAuthenticated || !hasCompletedOnboarding) return t(MarviL10n.Key.SIGN_IN_TO_ACCEPT)
            if (accountRole == UserRole.ADMIN) return null
            if (needsInviteRedemption) return t(MarviL10n.Key.ACCEPT_NEEDS_INVITE)
            if (needsSocialHandlesEntry) return t(MarviL10n.Key.NEEDS_SOCIAL)
            if (needsSocialProfileCompletion) {
                return if (socialVerification?.isVerified != true) {
                    t(MarviL10n.Key.ACCEPT_NEEDS_SOCIAL_VERIFY)
                } else {
                    t(MarviL10n.Key.NEEDS_SOCIAL)
                }
            }
            return when (profile.status) {
                MembershipStatus.UNDER_REVIEW -> t(MarviL10n.Key.AWAITING_APPROVAL)
                MembershipStatus.PAUSED -> t(MarviL10n.Key.MEMBERSHIP_PAUSED)
                MembershipStatus.APPROVED -> null
                else -> t(MarviL10n.Key.COMPLETE_PROFILE_TO_ACCEPT)
            }
        }

    val canAcceptOffers: Boolean
        get() {
            if (!isAuthenticated || !hasCompletedOnboarding) return false
            if (accountRole == UserRole.ADMIN) return true
            return !needsInviteRedemption && !needsSocialProfileCompletion &&
                profile.status == MembershipStatus.APPROVED
        }

    val acceptedOfferIds: Set<String>
        get() = bookings.filter { it.stage != BookingStage.CANCELLED }.map { it.offer.id }.toSet()

    val interestOffers: List<Offer>
        get() = offers.filter { savedOfferIds.contains(it.id) && !acceptedOfferIds.contains(it.id) }

    init {
        viewModelScope.launch {
            val snapshot = sessionStore.loadSnapshot()
            hasCompletedOnboarding = snapshot.hasCompletedOnboarding
            selectedRole = snapshot.selectedRole
            preferredLanguage = snapshot.preferredLanguage

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
            refreshFromServer()
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
                    bookings = repository.fetchBookings()
                    savedOfferIds = repository.fetchSavedOfferIds()
                    inboxMessages = repository.fetchNotifications()
                    followCounts = repository.fetchMyFollowCounts()
                    strikes = repository.fetchStrikes()
                    if (accountRole != UserRole.ADMIN) {
                        socialVerification = repository.ensureSocialVerificationCode()
                    }

                    when (selectedRole) {
                        UserRole.ADMIN -> {
                            adminTasks = repository.fetchAdminTasks()
                            adminUsers = repository.fetchAdminUsers(null, null)
                            adminInviteCodes = repository.fetchAdminInviteCodes()
                        }
                        UserRole.VENUE -> {
                            myVenues = repository.fetchMyVenues()
                            campaigns = repository.fetchCampaigns()
                        }
                        UserRole.CREATOR -> Unit
                    }
                }
            }.onFailure { error ->
                lastSyncError = error.message ?: t(MarviL10n.Key.SYNC_ERROR)
            }
            isSyncing = false
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
        if (context.referralCode.isNullOrBlank()) return false
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

    fun completeProfileSetup(name: String, handle: String, tiktok: String, city: String, onDone: () -> Unit) {
        viewModelScope.launch {
            val updated = profile.copy(
                name = name.trim(),
                handle = handle.trim().removePrefix("@"),
                tiktokHandle = tiktok.trim().removePrefix("@"),
                city = city.trim()
            )
            profile = updated
            if (repository.usesRemoteBackend && isAuthenticated) {
                runCatching { repository.updateProfile(updated) }
            }
            onDone()
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

    fun saveProfileFromEditor() {
        viewModelScope.launch {
            if (repository.usesRemoteBackend && isAuthenticated) {
                runCatching {
                    repository.updateProfile(profile)
                    socialVerification = repository.ensureSocialVerificationCode()
                }
            }
        }
    }

    fun loadSocialVerification() {
        viewModelScope.launch {
            runCatching {
                socialVerification = repository.ensureSocialVerificationCode()
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
                }
            }
        } else {
            savedOfferIds = if (offerId in savedOfferIds) savedOfferIds - offerId else savedOfferIds + offerId
        }
    }

    fun acceptOffer(offerId: String) {
        if (needsInviteRedemption || needsSocialProfileCompletion || profile.status != MembershipStatus.APPROVED) {
            lastSyncError = acceptBlockedReason ?: t(MarviL10n.Key.COMPLETE_PROFILE_TO_ACCEPT)
            return
        }
        viewModelScope.launch {
            runCatching {
                if (repository.usesRemoteBackend && isAuthenticated) {
                    val booking = repository.acceptOffer(offerId)
                    bookings = listOf(booking) + bookings.filter { it.id != booking.id }
                }
            }.onFailure { error ->
                lastSyncError = error.message
            }
        }
    }

    fun checkIn(bookingId: String, code: String) {
        viewModelScope.launch {
            runCatching {
                val booking = repository.checkIn(bookingId, code)
                bookings = bookings.map { if (it.id == booking.id) booking else it }
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    fun submitProof(bookingId: String, links: List<String>) {
        viewModelScope.launch {
            runCatching {
                val booking = repository.submitProof(bookingId, links)
                bookings = bookings.map { if (it.id == booking.id) booking else it }
            }.onFailure { error -> lastSyncError = error.message }
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

    fun followUser(userId: String) {
        viewModelScope.launch { runCatching { repository.followUser(userId) } }
    }

    fun unfollowUser(userId: String) {
        viewModelScope.launch { runCatching { repository.unfollowUser(userId) } }
    }

    suspend fun openDirectThread(peerUserId: String): String =
        repository.ensureDirectThread(peerUserId)

    fun approveTask(taskId: String) {
        viewModelScope.launch {
            runCatching {
                repository.approveTask(taskId)
                adminTasks = repository.fetchAdminTasks()
            }.onFailure { error -> lastSyncError = error.message }
        }
    }

    fun rejectTask(taskId: String) {
        viewModelScope.launch {
            runCatching {
                repository.rejectTask(taskId)
                adminTasks = repository.fetchAdminTasks()
            }.onFailure { error -> lastSyncError = error.message }
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
                    preferredLanguage = preferredLanguage
                )
            )
        }
    }
}
