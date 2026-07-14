package com.marvisociety.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
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
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.marvisociety.app.data.UserRole
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel

private enum class OnboardingStep {
    WELCOME, SIGN_IN, INVITE, PROFILE, VENUE, AGREEMENT
}

private enum class SignupIntent { CREATOR, BUSINESS }

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
    var ageConfirmed by remember { mutableStateOf(false) }
    var termsAccepted by remember { mutableStateOf(false) }
    var localError by remember { mutableStateOf("") }
    var inviteAccepted by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }

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

    val progress = when (step) {
        OnboardingStep.WELCOME -> 0.15f
        OnboardingStep.SIGN_IN -> 0.35f
        OnboardingStep.INVITE -> 0.55f
        OnboardingStep.PROFILE, OnboardingStep.VENUE -> 0.75f
        OnboardingStep.AGREEMENT -> 1f
    }

    fun routeAfterAuth() {
        busy = true
        localError = ""
        viewModel.routeAfterAuthentication { existing, role ->
            busy = false
            if (existing) {
                viewModel.finishOnboarding(role)
            } else {
                step = OnboardingStep.INVITE
            }
        }
    }

    MarviScreen {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            if (step != OnboardingStep.WELCOME) {
                LinearProgressIndicator(
                    progress = { progress },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp)),
                    color = MarviColor.Rose,
                    trackColor = MarviColor.Border
                )
            }

            when (step) {
                OnboardingStep.WELCOME -> WelcomeStep(
                    viewModel = viewModel,
                    onCreator = {
                        intent = SignupIntent.CREATOR
                        isCreatingAccount = true
                        step = OnboardingStep.SIGN_IN
                    },
                    onBusiness = {
                        intent = SignupIntent.BUSINESS
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
                        if (email.isBlank() || password.length < 8) {
                            localError = viewModel.t(MarviL10n.Key.ERR_SIGN_IN_REQUIRED)
                            return@SignInStep
                        }
                        if (!viewModel.isRemoteMode) {
                            viewModel.finishOnboarding(
                                if (intent == SignupIntent.BUSINESS) UserRole.VENUE else UserRole.CREATOR
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
                                intent = if (intent == SignupIntent.BUSINESS) "business" else "creator",
                                inviteCode = viewModel.pendingInviteCode
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

                OnboardingStep.INVITE -> InviteStep(
                    viewModel = viewModel,
                    code = inviteCode,
                    accepted = inviteAccepted,
                    localError = localError,
                    busy = busy,
                    onCode = {
                        inviteCode = it
                        inviteAccepted = false
                        localError = ""
                    },
                    onBack = { step = OnboardingStep.SIGN_IN },
                    onContinue = {
                        localError = ""
                        val normalized = normalizeInvite(inviteCode)
                        if (normalized.isBlank()) {
                            localError = viewModel.t(MarviL10n.Key.ERR_INVITE_INVALID)
                            return@InviteStep
                        }
                        if (!viewModel.isAuthenticated) {
                            localError = viewModel.t(MarviL10n.Key.ERR_SIGN_IN_REQUIRED)
                            step = OnboardingStep.SIGN_IN
                            return@InviteStep
                        }
                        busy = true
                        viewModel.validateAndRedeemInvite(normalized) { ok ->
                            busy = false
                            if (ok) {
                                inviteAccepted = true
                                step = if (intent == SignupIntent.BUSINESS) {
                                    OnboardingStep.VENUE
                                } else {
                                    OnboardingStep.PROFILE
                                }
                            } else {
                                localError = viewModel.t(MarviL10n.Key.ERR_INVITE_INVALID)
                            }
                        }
                    }
                )

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
                    onBack = { step = OnboardingStep.INVITE },
                    onContinue = {
                        if (instagram.isBlank() || tiktok.isBlank() || city.isBlank()) {
                            localError = viewModel.t(MarviL10n.Key.NEEDS_SOCIAL)
                            return@ProfileStep
                        }
                        localError = ""
                        busy = true
                        viewModel.completeProfileSetup(
                            name = fullName.ifBlank { email.substringBefore("@") },
                            handle = instagram,
                            tiktok = tiktok,
                            city = city
                        ) {
                            busy = false
                            step = OnboardingStep.AGREEMENT
                        }
                    }
                )

                OnboardingStep.VENUE -> VenueStep(
                    viewModel = viewModel,
                    venueName = venueName,
                    venueArea = venueArea,
                    localError = localError,
                    onName = { venueName = it },
                    onArea = { venueArea = it },
                    onBack = { step = OnboardingStep.INVITE },
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
                        step = if (intent == SignupIntent.BUSINESS) {
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
                        val role = if (intent == SignupIntent.BUSINESS) UserRole.VENUE else UserRole.CREATOR
                        viewModel.finishOnboarding(role)
                    }
                )
            }

            if (localError.isNotEmpty() && step == OnboardingStep.AGREEMENT) {
                Text(localError, color = MarviColor.Tomato)
            }
        }
    }
}

@Composable
private fun WelcomeStep(
    viewModel: AppViewModel,
    onCreator: () -> Unit,
    onBusiness: () -> Unit,
    onMember: () -> Unit
) {
    Spacer(modifier = Modifier.height(28.dp))
    Text(
        "MARVI SOCIETY",
        color = MarviColor.Rose,
        fontSize = 12.sp,
        fontWeight = FontWeight.Bold,
        letterSpacing = 2.sp
    )
    Text(
        viewModel.t(MarviL10n.Key.HERO_LINE1),
        color = MarviColor.Ink,
        fontSize = 34.sp,
        fontWeight = FontWeight.Bold,
        fontFamily = FontFamily.Serif
    )
    Text(viewModel.t(MarviL10n.Key.HERO_SUBTITLE), color = MarviColor.Muted)
    Spacer(modifier = Modifier.height(8.dp))
    Text(viewModel.t(MarviL10n.Key.CHOOSE_PATH), color = MarviColor.Graphite, fontWeight = FontWeight.SemiBold)

    IntentCard(
        title = viewModel.t(MarviL10n.Key.JOIN_AS_CREATOR),
        subtitle = viewModel.t(MarviL10n.Key.JOIN_AS_CREATOR_SUB),
        accent = MarviColor.Rose,
        onClick = onCreator
    )
    IntentCard(
        title = viewModel.t(MarviL10n.Key.JOIN_AS_BUSINESS),
        subtitle = viewModel.t(MarviL10n.Key.JOIN_AS_BUSINESS_SUB),
        accent = MarviColor.Gold,
        onClick = onBusiness
    )

    TextButton(onClick = onMember, modifier = Modifier.fillMaxWidth()) {
        Text(viewModel.t(MarviL10n.Key.ALREADY_MEMBER), color = MarviColor.Rose)
    }

    if (!viewModel.isRemoteMode) {
        Text(viewModel.t(MarviL10n.Key.BACKEND_DEMO), color = MarviColor.Gold)
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
    Text(viewModel.t(MarviL10n.Key.PROFILE_SETUP_SUB), color = MarviColor.Muted)

    if (isCreatingAccount) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            IntentChip(
                selected = intent == SignupIntent.CREATOR,
                label = viewModel.t(MarviL10n.Key.ROLE_CREATOR),
                onClick = { onIntent(SignupIntent.CREATOR) }
            )
            IntentChip(
                selected = intent == SignupIntent.BUSINESS,
                label = viewModel.t(MarviL10n.Key.ROLE_VENUE),
                onClick = { onIntent(SignupIntent.BUSINESS) }
            )
        }
    }

    MarviField(email, onEmail, viewModel.t(MarviL10n.Key.EMAIL))
    MarviField(password, onPassword, viewModel.t(MarviL10n.Key.PASSWORD), isPassword = true)
    if (isCreatingAccount) {
        MarviField(fullName, onFullName, viewModel.t(MarviL10n.Key.FULL_NAME_PLACEHOLDER))
        MarviField(city, onCity, viewModel.t(MarviL10n.Key.CITY_PLACEHOLDER))
    }

    if (localError.isNotEmpty()) Text(localError, color = MarviColor.Tomato)
    if (busy) CircularProgressIndicator(color = MarviColor.Rose)

    PrimaryButton(
        title = if (busy) viewModel.t(MarviL10n.Key.SIGNING_IN) else viewModel.t(MarviL10n.Key.GET_STARTED),
        enabled = !busy,
        onClick = onContinue
    )
    TextButton(onClick = onToggleMode) {
        Text(
            if (isCreatingAccount) viewModel.t(MarviL10n.Key.WELCOME_BACK)
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
    MarviField(code, onCode, viewModel.t(MarviL10n.Key.INVITE_PLACEHOLDER))
    if (accepted) Text(viewModel.t(MarviL10n.Key.INVITE_ACCEPTED), color = MarviColor.Emerald)
    if (localError.isNotEmpty()) Text(localError, color = MarviColor.Tomato)
    if (busy) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            CircularProgressIndicator(color = MarviColor.Rose)
            Text(viewModel.t(MarviL10n.Key.VALIDATING_INVITE), color = MarviColor.Muted)
        }
    }
    PrimaryButton(
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
    MarviField(fullName, onFullName, viewModel.t(MarviL10n.Key.FULL_NAME_PLACEHOLDER))
    MarviField(instagram, onInstagram, viewModel.t(MarviL10n.Key.INSTAGRAM_PLACEHOLDER))
    MarviField(tiktok, onTiktok, viewModel.t(MarviL10n.Key.TIKTOK_PLACEHOLDER))
    MarviField(city, onCity, viewModel.t(MarviL10n.Key.CITY_PLACEHOLDER))
    if (localError.isNotEmpty()) Text(localError, color = MarviColor.Tomato)
    PrimaryButton(title = viewModel.t(MarviL10n.Key.CONTINUE), onClick = onContinue)
    TextButton(onClick = onBack) { Text(viewModel.t(MarviL10n.Key.BACK), color = MarviColor.Muted) }
}

@Composable
private fun VenueStep(
    viewModel: AppViewModel,
    venueName: String,
    venueArea: String,
    localError: String,
    onName: (String) -> Unit,
    onArea: (String) -> Unit,
    onBack: () -> Unit,
    onContinue: () -> Unit
) {
    Text(viewModel.t(MarviL10n.Key.VENUE_SETUP_TITLE), style = MaterialTheme.typography.headlineMedium, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
    Text(viewModel.t(MarviL10n.Key.VENUE_SETUP_SUB), color = MarviColor.Muted)
    MarviField(venueName, onName, viewModel.t(MarviL10n.Key.VENUE_NAME))
    MarviField(venueArea, onArea, viewModel.t(MarviL10n.Key.VENUE_AREA))
    if (localError.isNotEmpty()) Text(localError, color = MarviColor.Tomato)
    PrimaryButton(title = viewModel.t(MarviL10n.Key.CONTINUE), onClick = onContinue)
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
    PrimaryButton(
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

@Composable
private fun PrimaryButton(title: String, enabled: Boolean = true, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.buttonColors(
            containerColor = MarviColor.Rose,
            disabledContainerColor = MarviColor.Muted.copy(alpha = 0.3f)
        ),
        shape = RoundedCornerShape(14.dp)
    ) {
        Text(title, fontWeight = FontWeight.Bold, modifier = Modifier.padding(vertical = 6.dp))
    }
}

@Composable
private fun MarviField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    isPassword: Boolean = false
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = MarviColor.Rose,
            unfocusedBorderColor = MarviColor.Border,
            focusedTextColor = MarviColor.Ink,
            unfocusedTextColor = MarviColor.Ink,
            focusedLabelColor = MarviColor.Muted,
            unfocusedLabelColor = MarviColor.Muted,
            cursorColor = MarviColor.Rose
        )
    )
}

private fun normalizeInvite(raw: String): String =
    raw.trim()
        .replace('\u2013', '-')
        .replace('\u2014', '-')
        .replace('\u2212', '-')
        .uppercase()
