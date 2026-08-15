package com.marvisociety.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Business
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.Videocam
import androidx.compose.material.icons.outlined.Work
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.marvisociety.app.BuildConfig
import com.marvisociety.app.data.OfferCategory
import com.marvisociety.app.data.BusinessCategoryCatalog
import com.marvisociety.app.data.BusinessCategoryOption
import com.marvisociety.app.data.UserRole
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.BrandMark
import com.marvisociety.app.ui.components.FilterChipPill
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.components.MarviTextField
import com.marvisociety.app.ui.components.OnboardingProgressCapsules
import com.marvisociety.app.ui.components.PrimaryActionButton
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.theme.MarviGradient
import com.marvisociety.app.ui.theme.NewsreaderFamily
import com.marvisociety.app.ui.viewmodel.AppViewModel
import kotlinx.coroutines.delay

private enum class OnboardingStep {
    WELCOME, SIGN_IN, INVITE, PROFILE, VENUE, AGREEMENT
}

private enum class SignupIntent {
    CREATOR, BUSINESS;

    val usesVenuePath: Boolean
        get() = this == BUSINESS

    val serverValue: String
        get() = when (this) {
            CREATOR -> "creator"
            BUSINESS -> "business"
        }
}

@Composable
fun OnboardingScreen(viewModel: AppViewModel) {
    var step by remember { mutableStateOf(OnboardingStep.WELCOME) }
    var intent by remember { mutableStateOf(SignupIntent.CREATOR) }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var fullName by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("Istanbul") }
    var isCreatingAccount by remember { mutableStateOf(true) }
    var inviteCode by remember { mutableStateOf(viewModel.pendingInviteCode.orEmpty()) }
    var instagram by remember { mutableStateOf("") }
    var tiktok by remember { mutableStateOf("") }
    var venueName by remember { mutableStateOf("") }
    var venueArea by remember { mutableStateOf("Istanbul") }
    var venueCategory by remember { mutableStateOf(OfferCategory.WELLNESS) }
    var venueCategoryLabel by remember { mutableStateOf("Hotel") }
    var customBusinessCategory by remember { mutableStateOf("") }
    var ageConfirmed by remember { mutableStateOf(false) }
    var termsAccepted by remember { mutableStateOf(false) }
    var localError by remember { mutableStateOf("") }
    var inviteAccepted by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var showLaunchIntro by remember { mutableStateOf(true) }

    LaunchedEffect(viewModel.pendingInviteCode) {
        val pending = viewModel.pendingInviteCode
        if (!pending.isNullOrBlank() && inviteCode.isBlank()) {
            inviteCode = pending
        }
    }

    LaunchedEffect(viewModel.authError) {
        if (!viewModel.authError.isNullOrBlank()) {
            busy = false
            localError = viewModel.authError.orEmpty()
        }
    }

    // A brand-new Google user returns from the OAuth browser here; jump them to the
    // matching profile/venue step instead of leaving them on the WELCOME screen.
    LaunchedEffect(viewModel.postGoogleAuthDestination) {
        when (viewModel.postGoogleAuthDestination) {
            AppViewModel.PostAuthDestination.PROFILE -> {
                intent = SignupIntent.CREATOR
                isCreatingAccount = true
                busy = false
                localError = ""
                showLaunchIntro = false
                step = OnboardingStep.PROFILE
                viewModel.consumePostGoogleAuthDestination()
            }
            AppViewModel.PostAuthDestination.VENUE -> {
                intent = SignupIntent.BUSINESS
                isCreatingAccount = true
                busy = false
                localError = ""
                showLaunchIntro = false
                step = OnboardingStep.VENUE
                viewModel.consumePostGoogleAuthDestination()
            }
            null -> Unit
        }
    }

    fun routeAfterAuth() {
        busy = true
        localError = ""
        viewModel.routeAfterAuthentication { existing, role ->
            busy = false
            if (existing) {
                viewModel.finishOnboarding(role)
            } else {
                step = if (intent.usesVenuePath) {
                    OnboardingStep.VENUE
                } else {
                    OnboardingStep.PROFILE
                }
            }
        }
    }

    MarviScreen {
        Box(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .navigationBarsPadding()
                    .imePadding()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                if (step != OnboardingStep.WELCOME) {
                    OnboardingProgressCapsules(
                        filledCount = when (step) {
                            OnboardingStep.WELCOME -> 0
                            OnboardingStep.SIGN_IN -> 1
                            OnboardingStep.INVITE -> 2
                            OnboardingStep.PROFILE, OnboardingStep.VENUE -> 3
                            OnboardingStep.AGREEMENT -> 4
                        }
                    )
                }

                when (step) {
                    OnboardingStep.WELCOME -> WelcomeStep(
                        viewModel = viewModel,
                        onHome = { showLaunchIntro = true },
                        onSelectIntent = { selected ->
                            intent = selected
                            isCreatingAccount = true
                            step = OnboardingStep.SIGN_IN
                        },
                        onMember = {
                            isCreatingAccount = false
                            step = OnboardingStep.SIGN_IN
                        }
                    )

                    OnboardingStep.SIGN_IN -> SignInStep(
                        viewModel = viewModel,
                        email = email,
                        password = password,
                        fullName = fullName,
                    city = city,
                    isCreatingAccount = isCreatingAccount,
                    intent = intent,
                    localError = localError.ifEmpty { viewModel.authError.orEmpty() },
                    busy = busy || viewModel.isBootstrapping,
                    onEmail = { email = it },
                    onPassword = { password = it },
                    onFullName = { fullName = it },
                    onCity = { city = it },
                    onIntent = { intent = it },
                    onToggleMode = { isCreatingAccount = !isCreatingAccount },
                    onBack = { step = OnboardingStep.WELCOME },
                    onContinue = {
                        localError = ""
                        if (email.isBlank()) {
                            localError = viewModel.t(MarviL10n.Key.EMAIL_REQUIRED_ERROR)
                            return@SignInStep
                        }
                        if (password.length < 8) {
                            localError = viewModel.t(MarviL10n.Key.PASSWORD_MIN_ERROR)
                            return@SignInStep
                        }
                        if (isCreatingAccount && fullName.isBlank()) {
                            localError = viewModel.t(MarviL10n.Key.FULL_NAME_REQUIRED_ERROR)
                            return@SignInStep
                        }
                        if (!viewModel.isRemoteMode) {
                            viewModel.finishOnboarding(
                                if (intent.usesVenuePath) UserRole.VENUE else UserRole.CREATOR
                            )
                            return@SignInStep
                        }
                        busy = true
                        if (isCreatingAccount) {
                            viewModel.signUp(
                                email = email,
                                password = password,
                                fullName = fullName,
                                city = city,
                                intent = intent.serverValue,
                                inviteCode = null
                            ) {
                                busy = false
                                routeAfterAuth()
                            }
                        } else {
                            viewModel.signIn(email, password) {
                                busy = false
                                routeAfterAuth()
                            }
                        }
                    },
                    onForgot = {
                        if (email.isBlank()) {
                            localError = viewModel.t(MarviL10n.Key.ERR_SIGN_IN_REQUIRED)
                        } else {
                            viewModel.resetPassword(email) {
                                localError = viewModel.t(MarviL10n.Key.RESET_EMAIL_SENT)
                            }
                        }
                    }
                )

                OnboardingStep.INVITE -> {
                    // Invite codes removed — skip immediately to profile/venue.
                    LaunchedEffect(Unit) {
                        step = if (intent.usesVenuePath) {
                            OnboardingStep.VENUE
                        } else {
                            OnboardingStep.PROFILE
                        }
                    }
                }

                OnboardingStep.PROFILE -> ProfileStep(
                    viewModel = viewModel,
                    fullName = fullName,
                    instagram = instagram,
                    tiktok = tiktok,
                    city = city,
                    localError = localError,
                    onFullName = { fullName = it },
                    onInstagram = { instagram = it },
                    onTiktok = { tiktok = it },
                    onCity = { city = it },
                    onBack = { step = OnboardingStep.SIGN_IN },
                    onContinue = {
                        if (city.isBlank()) {
                            localError = viewModel.t(MarviL10n.Key.CITY_PLACEHOLDER)
                            return@ProfileStep
                        }
                        localError = ""
                        busy = true
                        viewModel.completeProfileSetup(
                            name = fullName.ifBlank { email.substringBefore("@") },
                            handle = instagram,
                            tiktok = tiktok,
                            city = city
                        ) { succeeded ->
                            busy = false
                            if (succeeded) {
                                step = OnboardingStep.AGREEMENT
                            } else {
                                localError = viewModel.lastSyncError
                                    ?: viewModel.t(MarviL10n.Key.SYNC_ERROR)
                            }
                        }
                    }
                )

                OnboardingStep.VENUE -> VenueStep(
                    viewModel = viewModel,
                    venueName = venueName,
                    venueArea = venueArea,
                    venueCategoryLabel = venueCategoryLabel,
                    customBusinessCategory = customBusinessCategory,
                    localError = localError,
                    onName = { venueName = it },
                    onArea = { venueArea = it },
                    onCategory = {
                        venueCategory = it.offerCategory
                        venueCategoryLabel = it.label(viewModel.preferredLanguage)
                    },
                    onCustomCategory = {
                        customBusinessCategory = it
                        if (it.trim().length >= 2) {
                            venueCategoryLabel = it.trim()
                            venueCategory = BusinessCategoryCatalog.offerCategoryFor(it)
                        }
                    },
                    onBack = { step = OnboardingStep.SIGN_IN },
                    onContinue = {
                        if (venueName.isBlank() || venueArea.isBlank()) {
                            localError = viewModel.t(MarviL10n.Key.ERR_SIGN_IN_REQUIRED)
                            return@VenueStep
                        }
                        localError = ""
                        step = OnboardingStep.AGREEMENT
                    }
                )

                OnboardingStep.AGREEMENT -> AgreementStep(
                    viewModel = viewModel,
                    ageConfirmed = ageConfirmed,
                    termsAccepted = termsAccepted,
                    busy = busy || viewModel.isBootstrapping,
                    onAge = { ageConfirmed = it },
                    onTerms = { termsAccepted = it },
                    onBack = {
                        step = if (intent.usesVenuePath) {
                            OnboardingStep.VENUE
                        } else {
                            OnboardingStep.PROFILE
                        }
                    },
                    onJoin = {
                        if (!ageConfirmed || !termsAccepted) {
                            localError = viewModel.t(MarviL10n.Key.AGREE_REQUIRED)
                            return@AgreementStep
                        }
                        localError = ""
                        if (intent.usesVenuePath) {
                            busy = true
                            viewModel.registerVenue(
                                name = venueName,
                                area = venueArea,
                                category = venueCategory,
                                categoryLabel = venueCategoryLabel,
                                contactName = fullName.ifBlank { email.substringBefore("@") }
                            ) { succeeded ->
                                busy = false
                                if (succeeded) {
                                    viewModel.finishOnboarding(UserRole.VENUE)
                                } else {
                                    localError = viewModel.lastSyncError
                                        ?: viewModel.t(MarviL10n.Key.SYNC_ERROR)
                                }
                            }
                        } else {
                            viewModel.finishOnboarding(UserRole.CREATOR)
                        }
                    }
                )
            }

            if (localError.isNotEmpty() && step == OnboardingStep.AGREEMENT) {
                Text(localError, color = MarviColor.Tomato)
            }
            }

            if (showLaunchIntro) {
                OnboardingLaunchIntro(
                    viewModel = viewModel,
                    onFinished = { showLaunchIntro = false }
                )
            }
        }
    }
}

@Composable
private fun OnboardingLaunchIntro(
    viewModel: AppViewModel,
    onFinished: () -> Unit
) {
    val accent = MarviColor.Rose
    val slides = listOf(
        IntroSlide(
            icon = Icons.Outlined.Videocam,
            title = viewModel.t(MarviL10n.Key.INTRO_SLIDE_CREATORS_TITLE),
            subtitle = viewModel.t(MarviL10n.Key.INTRO_SLIDE_CREATORS_SUB)
        ),
        IntroSlide(
            icon = Icons.Outlined.Work,
            title = viewModel.t(MarviL10n.Key.INTRO_SLIDE_BRAND_TITLE),
            subtitle = viewModel.t(MarviL10n.Key.INTRO_SLIDE_BRAND_SUB)
        ),
        IntroSlide(
            icon = Icons.Outlined.Shield,
            title = viewModel.t(MarviL10n.Key.INTRO_SLIDE_AFFILIATE_TITLE),
            subtitle = viewModel.t(MarviL10n.Key.INTRO_SLIDE_AFFILIATE_SUB)
        )
    )
    val pagerState = rememberPagerState(pageCount = { slides.size })

    LaunchedEffect(Unit) {
        while (true) {
            delay(3200)
            val next = (pagerState.currentPage + 1) % slides.size
            pagerState.animateScrollToPage(next)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MarviColor.Surface)
            .statusBarsPadding()
            .navigationBarsPadding()
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(320.dp)
                .align(Alignment.TopCenter)
                .background(
                    Brush.radialGradient(
                        colors = listOf(accent.copy(alpha = 0.34f), Color.Transparent)
                    )
                )
        )

        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    modifier = Modifier.clickable(onClick = onFinished),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = null,
                        tint = Color.White.copy(alpha = 0.88f),
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        viewModel.t(MarviL10n.Key.INTRO_HOME),
                        color = Color.White.copy(alpha = 0.88f),
                        fontWeight = FontWeight.Medium
                    )
                }
                Text(
                    viewModel.t(MarviL10n.Key.INTRO_SKIP),
                    color = Color.White.copy(alpha = 0.72f),
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.clickable(onClick = onFinished)
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            HorizontalPager(
                state = pagerState,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(320.dp)
            ) { page ->
                val slide = slides[page]
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 28.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Box(
                        modifier = Modifier
                            .size(108.dp)
                            .clip(RoundedCornerShape(28.dp))
                            .background(MarviColor.PanelElevated)
                            .border(1.dp, accent.copy(alpha = 0.22f), RoundedCornerShape(28.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = slide.icon,
                            contentDescription = null,
                            tint = accent,
                            modifier = Modifier.size(44.dp)
                        )
                    }
                    Spacer(modifier = Modifier.height(22.dp))
                    Text(
                        slide.title,
                        color = Color.White,
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        slide.subtitle,
                        color = Color.White.copy(alpha = 0.58f),
                        fontSize = 15.sp,
                        textAlign = TextAlign.Center,
                        lineHeight = 22.sp
                    )
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 28.dp),
                horizontalArrangement = Arrangement.Center
            ) {
                slides.indices.forEach { index ->
                    val active = pagerState.currentPage == index
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 4.dp)
                            .height(8.dp)
                            .width(if (active) 28.dp else 8.dp)
                            .clip(CircleShape)
                            .background(if (active) accent else Color.White.copy(alpha = 0.22f))
                    )
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            Text(
                text = "v${BuildConfig.VERSION_NAME}",
                color = Color.White.copy(alpha = 0.28f),
                fontSize = 11.sp,
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .padding(bottom = 18.dp)
            )
        }
    }
}

private data class IntroSlide(
    val icon: ImageVector,
    val title: String,
    val subtitle: String
)

@Composable
private fun WelcomeStep(
    viewModel: AppViewModel,
    onHome: () -> Unit,
    onSelectIntent: (SignupIntent) -> Unit,
    onMember: () -> Unit
) {
    var showPaths by remember { mutableStateOf(false) }
    val accentStart = MarviColor.Rose
    val accentEnd = MarviColor.Aubergine
    val landingBrush = MarviGradient.Brand

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(if (showPaths) 640.dp else 620.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(280.dp)
                .align(Alignment.TopCenter)
                .background(
                    Brush.radialGradient(
                        colors = listOf(accentStart.copy(alpha = if (showPaths) 0.18f else 0.32f), Color.Transparent)
                    )
                )
        )

        if (showPaths) {
            Column(modifier = Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier
                            .size(24.dp)
                            .clickable { showPaths = false }
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    Row {
                        Text("MARVI", color = Color.White, fontWeight = FontWeight.Black, fontSize = 16.sp)
                        Text(
                            " SOCIETY",
                            style = TextStyle(brush = landingBrush, fontWeight = FontWeight.Black, fontSize = 16.sp)
                        )
                    }
                    Spacer(modifier = Modifier.weight(1f))
                    Spacer(modifier = Modifier.size(24.dp))
                }

                Spacer(modifier = Modifier.weight(1f))

                Text(
                    viewModel.t(MarviL10n.Key.CHOOSE_PATH),
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 26.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    viewModel.t(MarviL10n.Key.CHOOSE_PATH_SUBTITLE),
                    color = Color.White.copy(alpha = 0.55f),
                    fontSize = 15.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(modifier = Modifier.height(28.dp))

                RolePathCard(
                    icon = Icons.Outlined.Person,
                    title = viewModel.t(MarviL10n.Key.JOIN_AS_CREATOR),
                    subtitle = viewModel.t(MarviL10n.Key.JOIN_AS_CREATOR_SUB),
                    onClick = { onSelectIntent(SignupIntent.CREATOR) }
                )
                Spacer(modifier = Modifier.height(12.dp))
                RolePathCard(
                    icon = Icons.Outlined.Business,
                    title = viewModel.t(MarviL10n.Key.JOIN_AS_BRAND),
                    subtitle = viewModel.t(MarviL10n.Key.JOIN_AS_BRAND_SUB),
                    onClick = { onSelectIntent(SignupIntent.BUSINESS) }
                )

                Spacer(modifier = Modifier.weight(1f))

                Text(
                    text = "v${BuildConfig.VERSION_NAME}",
                    color = Color.White.copy(alpha = 0.28f),
                    fontSize = 11.sp,
                    modifier = Modifier.align(Alignment.CenterHorizontally)
                )
            }
        } else {
            Column(modifier = Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onHome)
                        .padding(bottom = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = null,
                        tint = Color.White.copy(alpha = 0.88f),
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        viewModel.t(MarviL10n.Key.INTRO_HOME),
                        color = Color.White.copy(alpha = 0.88f),
                        fontWeight = FontWeight.Medium
                    )
                }

                Spacer(modifier = Modifier.weight(1f))

                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    BrandMark(size = 92.dp)
                    Spacer(modifier = Modifier.height(18.dp))
                    Row {
                        Text(
                            "MARVI",
                            color = Color.White,
                            fontSize = 34.sp,
                            fontWeight = FontWeight.Black,
                            letterSpacing = 1.2.sp
                        )
                        Text(
                            " SOCIETY",
                            style = TextStyle(
                                brush = landingBrush,
                                fontSize = 34.sp,
                                fontWeight = FontWeight.Black,
                                letterSpacing = 1.2.sp
                            )
                        )
                    }
                    Spacer(modifier = Modifier.height(14.dp))
                    Text(
                        viewModel.t(MarviL10n.Key.LANDING_TAGLINE),
                        color = Color.White.copy(alpha = 0.58f),
                        fontSize = 15.sp,
                        textAlign = TextAlign.Center,
                        lineHeight = 22.sp,
                        modifier = Modifier.padding(horizontal = 8.dp)
                    )
                }

                Spacer(modifier = Modifier.weight(1f))

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(landingBrush)
                        .clickable { showPaths = true }
                        .padding(vertical = 17.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "${viewModel.t(MarviL10n.Key.GET_STARTED)}  →",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 17.sp
                    )
                }
                Spacer(modifier = Modifier.height(12.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .border(1.2.dp, Color.White.copy(alpha = 0.28f), RoundedCornerShape(16.dp))
                        .clickable { onSelectIntent(SignupIntent.CREATOR) }
                        .padding(vertical = 16.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        viewModel.t(MarviL10n.Key.DISCOVER_CREATORS),
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 17.sp
                    )
                }
                TextButton(onClick = onMember, modifier = Modifier.fillMaxWidth()) {
                    Text(
                        viewModel.t(MarviL10n.Key.ALREADY_MEMBER),
                        color = Color.White.copy(alpha = 0.55f),
                        fontSize = 13.sp
                    )
                }

                Text(
                    text = "v${BuildConfig.VERSION_NAME}",
                    color = Color.White.copy(alpha = 0.28f),
                    fontSize = 11.sp,
                    modifier = Modifier
                        .align(Alignment.CenterHorizontally)
                        .padding(top = 8.dp, bottom = 4.dp)
                )
            }
        }
    }
}

@Composable
private fun RolePathCard(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(18.dp))
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(MarviColor.PanelElevated)
                .border(1.dp, MarviColor.Rose.copy(alpha = 0.25f), RoundedCornerShape(14.dp)),
            contentAlignment = Alignment.Center
        ) {
            Icon(imageVector = icon, contentDescription = null, tint = MarviColor.Rose, modifier = Modifier.size(22.dp))
        }
        Spacer(modifier = Modifier.width(16.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 17.sp)
            Spacer(modifier = Modifier.height(4.dp))
            Text(subtitle, color = Color.White.copy(alpha = 0.55f), fontSize = 13.sp)
        }
    }
}

@Composable
private fun IntentCard(
    title: String,
    subtitle: String,
    accent: androidx.compose.ui.graphics.Color,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(MarviColor.Panel)
            .border(1.dp, accent.copy(alpha = 0.35f), RoundedCornerShape(18.dp))
            .clickable(onClick = onClick)
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(Brush.horizontalGradient(listOf(accent, MarviColor.Aubergine)))
        )
        Text(title, color = MarviColor.Ink, fontWeight = FontWeight.Bold, fontSize = 20.sp)
        Text(subtitle, color = MarviColor.Muted)
    }
}

@Composable
private fun SignInStep(
    viewModel: AppViewModel,
    email: String,
    password: String,
    fullName: String,
    city: String,
    isCreatingAccount: Boolean,
    intent: SignupIntent,
    localError: String,
    busy: Boolean,
    onEmail: (String) -> Unit,
    onPassword: (String) -> Unit,
    onFullName: (String) -> Unit,
    onCity: (String) -> Unit,
    onIntent: (SignupIntent) -> Unit,
    onToggleMode: () -> Unit,
    onBack: () -> Unit,
    onContinue: () -> Unit,
    onForgot: () -> Unit
) {
    Text(
        if (isCreatingAccount) viewModel.t(MarviL10n.Key.CREATE_ACCOUNT)
        else viewModel.t(MarviL10n.Key.WELCOME_BACK),
        style = MaterialTheme.typography.headlineMedium,
        color = MarviColor.Ink,
        fontWeight = FontWeight.Bold
    )
    Text(
        viewModel.t(
            if (intent.usesVenuePath) {
                MarviL10n.Key.VENUE_SETUP_SUB
            } else {
                MarviL10n.Key.PROFILE_SETUP_SUB
            }
        ),
        color = MarviColor.Muted
    )

    if (isCreatingAccount) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            IntentChip(
                selected = intent == SignupIntent.CREATOR,
                label = viewModel.t(MarviL10n.Key.JOIN_AS_CREATOR),
                onClick = { onIntent(SignupIntent.CREATOR) }
            )
            IntentChip(
                selected = intent == SignupIntent.BUSINESS,
                label = viewModel.t(MarviL10n.Key.JOIN_AS_BRAND),
                onClick = { onIntent(SignupIntent.BUSINESS) }
            )
        }
    }

    val context = androidx.compose.ui.platform.LocalContext.current
    if (com.marvisociety.app.network.GoogleOAuth.isEnabled()) {
        PrimaryActionButton(
            title = if (busy) viewModel.t(MarviL10n.Key.SIGNING_IN)
            else viewModel.t(MarviL10n.Key.SIGN_IN_WITH_GOOGLE),
            enabled = !busy,
            onClick = {
                viewModel.startGoogleSignIn(
                    context,
                    if (intent.usesVenuePath) UserRole.VENUE else UserRole.CREATOR
                )
            }
        )
        Text(
            viewModel.t(MarviL10n.Key.OR_EMAIL),
            color = MarviColor.Muted,
            modifier = Modifier.fillMaxWidth(),
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
    }

    MarviTextField(email, onEmail, viewModel.t(MarviL10n.Key.EMAIL))
    MarviTextField(password, onPassword, viewModel.t(MarviL10n.Key.PASSWORD), isPassword = true)
    if (isCreatingAccount) {
        MarviTextField(fullName, onFullName, viewModel.t(MarviL10n.Key.FULL_NAME_PLACEHOLDER))
        MarviTextField(city, onCity, viewModel.t(MarviL10n.Key.CITY_PLACEHOLDER))
    }

    if (localError.isNotEmpty()) Text(localError, color = MarviColor.Tomato)
    if (busy) CircularProgressIndicator(color = MarviColor.Rose)

    PrimaryActionButton(
        title = when {
            busy -> viewModel.t(MarviL10n.Key.SIGNING_IN)
            isCreatingAccount -> viewModel.t(MarviL10n.Key.SIGN_UP)
            else -> viewModel.t(MarviL10n.Key.SIGN_IN)
        },
        enabled = !busy,
        onClick = onContinue
    )
    TextButton(onClick = onToggleMode) {
        Text(
            if (isCreatingAccount) viewModel.t(MarviL10n.Key.ALREADY_MEMBER)
            else viewModel.t(MarviL10n.Key.CREATE_ACCOUNT),
            color = MarviColor.Rose
        )
    }
    if (!isCreatingAccount) {
        TextButton(onClick = onForgot) {
            Text(viewModel.t(MarviL10n.Key.FORGOT_PASSWORD), color = MarviColor.Muted)
        }
    }
    TextButton(onClick = onBack) {
        Text(viewModel.t(MarviL10n.Key.BACK), color = MarviColor.Muted)
    }
}

@Composable
private fun InviteStep(
    viewModel: AppViewModel,
    code: String,
    accepted: Boolean,
    localError: String,
    busy: Boolean,
    onCode: (String) -> Unit,
    onBack: () -> Unit,
    onContinue: () -> Unit
) {
    Text(viewModel.t(MarviL10n.Key.INVITE_TITLE), style = MaterialTheme.typography.headlineMedium, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
    Text(viewModel.t(MarviL10n.Key.INVITE_SUBTITLE), color = MarviColor.Muted)
    MarviTextField(code, onCode, viewModel.t(MarviL10n.Key.INVITE_PLACEHOLDER))
    if (accepted) Text(viewModel.t(MarviL10n.Key.INVITE_ACCEPTED), color = MarviColor.Emerald)
    if (localError.isNotEmpty()) Text(localError, color = MarviColor.Tomato)
    if (busy) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            CircularProgressIndicator(color = MarviColor.Rose)
            Text(viewModel.t(MarviL10n.Key.VALIDATING_INVITE), color = MarviColor.Muted)
        }
    }
    PrimaryActionButton(
        title = viewModel.t(MarviL10n.Key.CONTINUE),
        enabled = !busy && code.isNotBlank(),
        onClick = onContinue
    )
    TextButton(onClick = onBack) { Text(viewModel.t(MarviL10n.Key.BACK), color = MarviColor.Muted) }
}

@Composable
private fun ProfileStep(
    viewModel: AppViewModel,
    fullName: String,
    instagram: String,
    tiktok: String,
    city: String,
    localError: String,
    onFullName: (String) -> Unit,
    onInstagram: (String) -> Unit,
    onTiktok: (String) -> Unit,
    onCity: (String) -> Unit,
    onBack: () -> Unit,
    onContinue: () -> Unit
) {
    Text(viewModel.t(MarviL10n.Key.PROFILE_SETUP_TITLE), style = MaterialTheme.typography.headlineMedium, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
    Text(viewModel.t(MarviL10n.Key.PROFILE_SETUP_SUB), color = MarviColor.Muted)
    MarviTextField(fullName, onFullName, viewModel.t(MarviL10n.Key.FULL_NAME_PLACEHOLDER))
    MarviTextField(instagram, onInstagram, viewModel.t(MarviL10n.Key.INSTAGRAM_PLACEHOLDER))
    MarviTextField(tiktok, onTiktok, viewModel.t(MarviL10n.Key.TIKTOK_PLACEHOLDER))
    MarviTextField(city, onCity, viewModel.t(MarviL10n.Key.CITY_PLACEHOLDER))
    Row(
        modifier = Modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        listOf("Istanbul", "Dubai", "London").forEach { option ->
            FilterChipPill(
                label = option,
                selected = city.equals(option, ignoreCase = true),
                onClick = { onCity(option) }
            )
        }
    }
    if (localError.isNotEmpty()) Text(localError, color = MarviColor.Tomato)
    PrimaryActionButton(title = viewModel.t(MarviL10n.Key.CONTINUE), onClick = onContinue)
    TextButton(onClick = onBack) { Text(viewModel.t(MarviL10n.Key.BACK), color = MarviColor.Muted) }
}

@Composable
private fun VenueStep(
    viewModel: AppViewModel,
    venueName: String,
    venueArea: String,
    venueCategoryLabel: String,
    customBusinessCategory: String,
    localError: String,
    onName: (String) -> Unit,
    onArea: (String) -> Unit,
    onCategory: (BusinessCategoryOption) -> Unit,
    onCustomCategory: (String) -> Unit,
    onBack: () -> Unit,
    onContinue: () -> Unit
) {
    Text(viewModel.t(MarviL10n.Key.VENUE_SETUP_TITLE), style = MaterialTheme.typography.headlineMedium, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
    Text(viewModel.t(MarviL10n.Key.VENUE_SETUP_SUB), color = MarviColor.Muted)
    MarviTextField(venueName, onName, viewModel.t(MarviL10n.Key.VENUE_NAME))
    MarviTextField(venueArea, onArea, viewModel.t(MarviL10n.Key.VENUE_AREA))
    Row(
        modifier = Modifier.horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        BusinessCategoryCatalog.all.forEach { category ->
            FilterChipPill(
                label = category.label(viewModel.preferredLanguage),
                selected = venueCategoryLabel.equals(category.label(viewModel.preferredLanguage), ignoreCase = true),
                onClick = { onCategory(category) }
            )
        }
    }
    MarviTextField(
        customBusinessCategory,
        onCustomCategory,
        if (viewModel.preferredLanguage == com.marvisociety.app.data.AppLanguage.TURKISH) {
            "Kategori yoksa buraya yazın"
        } else {
            "Can't find it? Add your category"
        }
    )
    if (customBusinessCategory.trim().length >= 2) {
        Text(
            if (viewModel.preferredLanguage == com.marvisociety.app.data.AppLanguage.TURKISH) {
                "Seçilen kategori: ${customBusinessCategory.trim()}"
            } else {
                "Selected category: ${customBusinessCategory.trim()}"
            },
            color = MarviColor.Rose,
            fontWeight = FontWeight.SemiBold
        )
    }
    if (localError.isNotEmpty()) Text(localError, color = MarviColor.Tomato)
    PrimaryActionButton(title = viewModel.t(MarviL10n.Key.CONTINUE), onClick = onContinue)
    TextButton(onClick = onBack) { Text(viewModel.t(MarviL10n.Key.BACK), color = MarviColor.Muted) }
}

@Composable
private fun AgreementStep(
    viewModel: AppViewModel,
    ageConfirmed: Boolean,
    termsAccepted: Boolean,
    busy: Boolean,
    onAge: (Boolean) -> Unit,
    onTerms: (Boolean) -> Unit,
    onBack: () -> Unit,
    onJoin: () -> Unit
) {
    Text(viewModel.t(MarviL10n.Key.AGREEMENT_TITLE), style = MaterialTheme.typography.headlineMedium, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
    Text(viewModel.t(MarviL10n.Key.AGREEMENT_SUB), color = MarviColor.Muted)
    CheckRow(ageConfirmed, viewModel.t(MarviL10n.Key.AGE_CONFIRM), onAge)
    CheckRow(termsAccepted, viewModel.t(MarviL10n.Key.TERMS_CONFIRM), onTerms)
    PrimaryActionButton(
        title = if (busy) viewModel.t(MarviL10n.Key.LOADING) else viewModel.t(MarviL10n.Key.JOIN_MARVI),
        enabled = !busy && ageConfirmed && termsAccepted,
        onClick = onJoin
    )
    TextButton(onClick = onBack) { Text(viewModel.t(MarviL10n.Key.BACK), color = MarviColor.Muted) }
}

@Composable
private fun CheckRow(checked: Boolean, label: String, onChecked: (Boolean) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MarviColor.Panel)
            .clickable { onChecked(!checked) }
            .padding(horizontal = 8.dp, vertical = 4.dp)
    ) {
        Checkbox(
            checked = checked,
            onCheckedChange = onChecked,
            colors = CheckboxDefaults.colors(checkedColor = MarviColor.Rose)
        )
        Text(label, color = MarviColor.Ink, modifier = Modifier.padding(end = 8.dp))
    }
}

@Composable
private fun IntentChip(selected: Boolean, label: String, onClick: () -> Unit) {
    Text(
        label,
        color = if (selected) MarviColor.Ink else MarviColor.Muted,
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(if (selected) MarviColor.Rose.copy(alpha = 0.2f) else MarviColor.Panel)
            .border(1.dp, if (selected) MarviColor.Rose else MarviColor.Border, RoundedCornerShape(999.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp)
    )
}

private fun normalizeInvite(raw: String): String =
    raw.trim()
        .replace('\u2013', '-')
        .replace('\u2014', '-')
        .replace('\u2212', '-')
        .uppercase()
