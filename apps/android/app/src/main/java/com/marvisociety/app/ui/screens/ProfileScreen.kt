package com.marvisociety.app.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Collections
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Groups
import androidx.compose.material.icons.outlined.PhotoCamera
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.marvisociety.app.data.AppLanguage
import com.marvisociety.app.data.MembershipStatus
import com.marvisociety.app.data.SocialVerificationState
import com.marvisociety.app.data.UserRole
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.ProfileHealthRing
import com.marvisociety.app.ui.components.SegmentedTabs
import com.marvisociety.app.ui.components.FilterChipPill
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.components.MarviTextField
import com.marvisociety.app.ui.components.PrimaryActionButton
import com.marvisociety.app.ui.components.ProgressBar
import com.marvisociety.app.ui.components.SecondaryActionButton
import com.marvisociety.app.ui.components.SectionTitle
import com.marvisociety.app.ui.components.StatusPill
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.theme.MarviGradient
import com.marvisociety.app.ui.viewmodel.AppViewModel

private enum class ProfileMainTab {
    OVERVIEW, EDIT, ACCOUNT, SETTINGS
}

@Composable
fun ProfileScreen(viewModel: AppViewModel) {
    var selectedTab by remember { mutableStateOf(ProfileMainTab.OVERVIEW) }
    val showCompletion = viewModel.isAuthenticated &&
        viewModel.selectedRole == UserRole.CREATOR &&
        (viewModel.needsSocialProfileCompletion ||
            viewModel.profile.status != MembershipStatus.APPROVED)

    val avatarPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri -> uri?.let { viewModel.uploadProfilePhoto(it, "avatar") } }

    val coverPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri -> uri?.let { viewModel.uploadProfilePhoto(it, "cover") } }

    MarviScreen {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(MarviColor.Panel)
                    .border(1.dp, MarviColor.Border, RoundedCornerShape(20.dp))
            ) {
                Column {
                    Box(modifier = Modifier.fillMaxWidth()) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(148.dp)
                                .background(MarviGradient.BrandVertical)
                                .clickable(enabled = !viewModel.isProfileMediaUploading) {
                                    coverPicker.launch(
                                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                                    )
                                }
                        ) {
                            if (viewModel.profile.coverUrl.isNotBlank()) {
                                AsyncImage(
                                    model = viewModel.profile.coverUrl,
                                    contentDescription = viewModel.t(MarviL10n.Key.CHANGE_COVER),
                                    modifier = Modifier.fillMaxSize(),
                                    contentScale = ContentScale.Crop
                                )
                            } else {
                                Text(
                                    viewModel.t(MarviL10n.Key.NO_COVER_IMAGE),
                                    color = Color.White.copy(alpha = 0.72f),
                                    fontWeight = FontWeight.Medium,
                                    style = MaterialTheme.typography.bodyMedium,
                                    modifier = Modifier.align(Alignment.Center)
                                )
                            }
                            Box(
                                modifier = Modifier
                                    .align(Alignment.BottomEnd)
                                    .padding(12.dp)
                                    .size(28.dp)
                                    .clip(CircleShape)
                                    .background(MarviColor.Panel.copy(alpha = 0.85f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    Icons.Outlined.PhotoCamera,
                                    contentDescription = viewModel.t(MarviL10n.Key.CHANGE_COVER),
                                    tint = MarviColor.Ink,
                                    modifier = Modifier.size(14.dp)
                                )
                            }
                        }
                        Box(
                            modifier = Modifier
                                .align(Alignment.BottomStart)
                                .offset(x = 16.dp, y = 44.dp)
                                .size(88.dp)
                                .clip(CircleShape)
                                .background(MarviGradient.Brand)
                                .clickable(enabled = !viewModel.isProfileMediaUploading) {
                                    avatarPicker.launch(
                                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                                    )
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            if (viewModel.profile.avatarUrl.isNotBlank()) {
                                AsyncImage(
                                    model = viewModel.profile.avatarUrl,
                                    contentDescription = viewModel.t(MarviL10n.Key.CHANGE_PHOTO),
                                    modifier = Modifier.fillMaxSize(),
                                    contentScale = ContentScale.Crop
                                )
                            } else {
                                Text(
                                    viewModel.profile.name.take(1).ifBlank { "?" }.uppercase(),
                                    color = Color.White,
                                    fontWeight = FontWeight.Bold,
                                    style = MaterialTheme.typography.headlineMedium
                                )
                            }
                        }
                    }
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(start = 16.dp, end = 16.dp, top = 58.dp, bottom = 16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Text(
                                viewModel.profile.name.ifBlank { viewModel.t(MarviL10n.Key.MEMBER_LABEL) },
                                modifier = Modifier.weight(1f),
                                style = MaterialTheme.typography.titleLarge,
                                color = MarviColor.Ink,
                                fontWeight = FontWeight.Bold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            StatusPill(
                                when (viewModel.profile.status) {
                                    MembershipStatus.APPROVED -> viewModel.t(MarviL10n.Key.STATUS_APPROVED)
                                    MembershipStatus.PAUSED -> viewModel.t(MarviL10n.Key.STATUS_PAUSED)
                                    MembershipStatus.UNDER_REVIEW -> viewModel.t(MarviL10n.Key.STATUS_UNDER_REVIEW)
                                    null -> viewModel.t(MarviL10n.Key.STATUS_UNDER_REVIEW)
                                },
                                when (viewModel.profile.status) {
                                    MembershipStatus.APPROVED -> MarviColor.Emerald
                                    MembershipStatus.PAUSED -> MarviColor.Tomato
                                    else -> MarviColor.Gold
                                }
                            )
                        }
                        val niche = viewModel.profile.niches.firstOrNull()?.takeIf { it.isNotBlank() }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(
                                viewModel.roleLabel(viewModel.selectedRole),
                                color = MarviColor.Rose,
                                fontWeight = FontWeight.SemiBold,
                                style = MaterialTheme.typography.bodyMedium
                            )
                            if (niche != null) {
                                Text("·", color = MarviColor.Muted)
                                Text(niche, color = MarviColor.Muted, fontWeight = FontWeight.Medium, style = MaterialTheme.typography.bodyMedium, maxLines = 1)
                            }
                        }
                        val handle = viewModel.profile.handle.takeIf { it.isNotBlank() }?.let { "@${it.removePrefix("@")}" }
                        Text(
                            handle ?: viewModel.t(MarviL10n.Key.HANDLE_EMPTY),
                            color = MarviColor.Muted,
                            style = MaterialTheme.typography.bodySmall
                        )
                        ProfileSheetRow(
                            icon = Icons.Outlined.Groups,
                            title = viewModel.t(MarviL10n.Key.SOCIAL_ACCOUNTS),
                            onClick = { selectedTab = ProfileMainTab.EDIT }
                        )
                        ProfileSheetRow(
                            icon = Icons.Outlined.Collections,
                            title = viewModel.t(MarviL10n.Key.SHOWCASE_TITLE),
                            onClick = { selectedTab = ProfileMainTab.OVERVIEW }
                        )
                        PrimaryActionButton(
                            title = viewModel.t(MarviL10n.Key.EDIT_PROFILE),
                            onClick = { selectedTab = ProfileMainTab.EDIT },
                            icon = Icons.Outlined.Edit
                        )
                    }
                }
                if (viewModel.isProfileMediaUploading) {
                    Box(
                        modifier = Modifier
                            .matchParentSize()
                            .background(Color.Black.copy(alpha = 0.35f)),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = Color.White)
                    }
                }
            }

            if (showCompletion) {
                MarviCard {
                    SectionTitle(
                        text = viewModel.t(MarviL10n.Key.PROFILE_COMPLETION_TITLE)
                    )
                    Text(viewModel.t(MarviL10n.Key.PROFILE_COMPLETION_SUB), color = MarviColor.Muted)
                    val pct = profileCompletionPercent(viewModel)
                    Text(
                        viewModel.tf(MarviL10n.Key.PROFILE_COMPLETION_PCT, pct),
                        color = MarviColor.Graphite,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    ProgressBar(pct / 100f)

                    if (viewModel.profile.status != MembershipStatus.APPROVED) {
                        Text(
                            when (viewModel.profile.status) {
                                MembershipStatus.APPROVED -> viewModel.t(MarviL10n.Key.STATUS_APPROVED)
                                MembershipStatus.PAUSED -> viewModel.t(MarviL10n.Key.STATUS_PAUSED)
                                MembershipStatus.UNDER_REVIEW -> viewModel.t(MarviL10n.Key.STATUS_UNDER_REVIEW)
                            },
                            color = MarviColor.Gold,
                            fontWeight = FontWeight.SemiBold
                        )
                    }

                    if (viewModel.needsSocialProfileCompletion) {
                        Text(viewModel.t(MarviL10n.Key.NEEDS_SOCIAL), color = MarviColor.Gold)
                    }

                    Text(viewModel.t(MarviL10n.Key.COMPLETE_PROFILE_TO_ACCEPT), color = MarviColor.Graphite, style = MaterialTheme.typography.bodySmall)
                }
            }

            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                val tabs = listOf(
                    ProfileMainTab.OVERVIEW to MarviL10n.Key.PROFILE_TAB_OVERVIEW,
                    ProfileMainTab.EDIT to MarviL10n.Key.PROFILE_TAB_EDIT,
                    ProfileMainTab.ACCOUNT to MarviL10n.Key.PROFILE_TAB_ACCOUNT,
                    ProfileMainTab.SETTINGS to MarviL10n.Key.PROFILE_TAB_SETTINGS
                )
                items(tabs.size) { index ->
                    val (tab, key) = tabs[index]
                    FilterChipPill(
                        label = viewModel.t(key),
                        selected = selectedTab == tab,
                        onClick = { selectedTab = tab }
                    )
                }
            }

            when (selectedTab) {
                ProfileMainTab.OVERVIEW -> {
                    var insightTab by remember { mutableStateOf(0) }
                    MarviCard {
                        SegmentedTabs(
                            tabs = listOf(
                                viewModel.t(MarviL10n.Key.PROFILE_ENGAGEMENT),
                                viewModel.t(MarviL10n.Key.PROFILE_HEALTH)
                            ),
                            selectedIndex = insightTab,
                            onSelect = { insightTab = it },
                            uppercase = false
                        )
                        if (insightTab == 0) {
                            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                Text("${viewModel.followCounts.followers} ${viewModel.t(MarviL10n.Key.FOLLOWERS)}", color = MarviColor.Ink, fontWeight = FontWeight.Bold)
                                Text("${viewModel.followCounts.following} ${viewModel.t(MarviL10n.Key.FOLLOWING_LABEL)}", color = MarviColor.Ink, fontWeight = FontWeight.Bold)
                            }
                            Text(viewModel.t(MarviL10n.Key.CONTENT_FIT_LABEL), color = MarviColor.Muted, style = MaterialTheme.typography.labelMedium)
                            Text(viewModel.profile.niches.joinToString(" · ").ifBlank { "—" }, color = MarviColor.Ink)
                            Text(viewModel.t(MarviL10n.Key.LANGUAGES_LABEL), color = MarviColor.Muted, style = MaterialTheme.typography.labelMedium)
                            Text(viewModel.profile.languages.joinToString(" · ").ifBlank { "—" }, color = MarviColor.Ink)
                            Text(viewModel.t(MarviL10n.Key.DELIVERY_LABEL), color = MarviColor.Muted, style = MaterialTheme.typography.labelMedium)
                            Text(viewModel.profile.proofRate, color = MarviColor.Emerald, fontWeight = FontWeight.Bold)
                        } else {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                    Text("${viewModel.profile.score}", color = MarviColor.Ink, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.displaySmall)
                                    Text(viewModel.t(MarviL10n.Key.SCORE_LABEL), color = MarviColor.Muted, style = MaterialTheme.typography.labelMedium)
                                    Text(viewModel.profile.proofRate, color = MarviColor.Ink, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.headlineMedium)
                                    Text(viewModel.t(MarviL10n.Key.DELIVERY_LABEL), color = MarviColor.Muted, style = MaterialTheme.typography.labelMedium)
                                }
                                ProfileHealthRing(viewModel.profile.score, viewModel.t(MarviL10n.Key.PROFILE_HEALTH))
                            }
                        }
                    }

                    if (viewModel.allowedRoles.size > 1) {
                        MarviCard {
                            SectionTitle(text = viewModel.t(MarviL10n.Key.WORKSPACE))
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                viewModel.allowedRoles.forEach { role ->
                                    FilterChipPill(
                                        label = roleLabel(role, viewModel),
                                        selected = viewModel.selectedRole == role,
                                        onClick = { viewModel.switchRole(role) }
                                    )
                                }
                            }
                        }
                    }

                    if (viewModel.profile.bio.isNotBlank()) {
                        MarviCard {
                            Text(viewModel.profile.bio, color = MarviColor.Ink)
                        }
                    }

                    ShowcaseSection(viewModel)
                    CollaborationHistorySection(viewModel)

                    if (viewModel.strikes.isNotEmpty()) {
                        MarviCard {
                            SectionTitle(text = viewModel.t(MarviL10n.Key.STRIKES_TITLE))
                            viewModel.strikes.forEach { strike ->
                                Column(modifier = Modifier.padding(vertical = 4.dp)) {
                                    Text(strike.reason, color = MarviColor.Tomato, fontWeight = FontWeight.SemiBold)
                                    Text(
                                        viewModel.localizeServerText(strike.dateLabel),
                                        color = MarviColor.Muted,
                                        style = MaterialTheme.typography.bodySmall
                                    )
                                }
                            }
                        }
                    }
                }

                ProfileMainTab.EDIT -> {
                    var nichesText by remember {
                        mutableStateOf(viewModel.profile.niches.joinToString(", "))
                    }
                    var languagesText by remember {
                        mutableStateOf(viewModel.profile.languages.joinToString(", "))
                    }
                    var saveMessage by remember { mutableStateOf<String?>(null) }
                    var saveFailed by remember { mutableStateOf(false) }

                    LaunchedEffect(viewModel.profile.niches, viewModel.profile.languages) {
                        nichesText = viewModel.profile.niches.joinToString(", ")
                        languagesText = viewModel.profile.languages.joinToString(", ")
                    }

                    MarviCard {
                        SectionTitle(text = viewModel.t(MarviL10n.Key.PROFILE_BASICS_TITLE))
                        Text(viewModel.t(MarviL10n.Key.PROFILE_BASICS_SUB), color = MarviColor.Muted)
                        MarviTextField(
                            value = viewModel.profile.name,
                            onValueChange = { viewModel.updateProfileName(it) },
                            placeholder = viewModel.t(MarviL10n.Key.DISPLAY_NAME)
                        )
                        MarviTextField(
                            value = viewModel.profile.bio,
                            onValueChange = { viewModel.updateProfileBio(it) },
                            placeholder = viewModel.t(MarviL10n.Key.BIO_PLACEHOLDER),
                            singleLine = false
                        )
                        MarviTextField(
                            value = viewModel.profile.city,
                            onValueChange = { viewModel.updateProfileCity(it) },
                            placeholder = viewModel.t(MarviL10n.Key.CITY_PLACEHOLDER)
                        )
                        MarviTextField(
                            value = nichesText,
                            onValueChange = { nichesText = it },
                            placeholder = viewModel.t(MarviL10n.Key.NICHES_COMMA)
                        )
                        MarviTextField(
                            value = languagesText,
                            onValueChange = { languagesText = it },
                            placeholder = viewModel.t(MarviL10n.Key.LANGUAGES_COMMA)
                        )
                    }

                    MarviCard {
                        SectionTitle(text = viewModel.t(MarviL10n.Key.SOCIAL_ACCOUNTS))
                        Text(viewModel.t(MarviL10n.Key.SOCIAL_ACCOUNTS_SUB), color = MarviColor.Muted)
                        MarviTextField(
                            value = viewModel.profile.handle,
                            onValueChange = { viewModel.updateProfileHandle(it) },
                            placeholder = viewModel.t(MarviL10n.Key.INSTAGRAM_PLACEHOLDER)
                        )
                        MarviTextField(
                            value = viewModel.profile.tiktokHandle,
                            onValueChange = { viewModel.updateProfileTiktok(it) },
                            placeholder = viewModel.t(MarviL10n.Key.TIKTOK_PLACEHOLDER)
                        )
                    }

                    MarviCard {
                        SectionTitle(text = viewModel.t(MarviL10n.Key.PROFILE_PHOTOS_TITLE))
                        Text(viewModel.t(MarviL10n.Key.PROFILE_PHOTOS_SUB), color = MarviColor.Muted)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Box(modifier = Modifier.weight(1f)) {
                                SecondaryActionButton(
                                    title = viewModel.t(MarviL10n.Key.CHANGE_PHOTO),
                                    onClick = {
                                        avatarPicker.launch(
                                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                                        )
                                    },
                                    enabled = !viewModel.isProfileMediaUploading
                                )
                            }
                            Box(modifier = Modifier.weight(1f)) {
                                SecondaryActionButton(
                                    title = viewModel.t(MarviL10n.Key.CHANGE_COVER),
                                    onClick = {
                                        coverPicker.launch(
                                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                                        )
                                    },
                                    enabled = !viewModel.isProfileMediaUploading
                                )
                            }
                        }
                        if (viewModel.isProfileMediaUploading) {
                            CircularProgressIndicator(color = MarviColor.Rose, modifier = Modifier.size(24.dp))
                        }
                        saveMessage?.let { message ->
                            Text(
                                message,
                                color = if (saveFailed) MarviColor.Tomato else MarviColor.Emerald,
                                fontWeight = FontWeight.SemiBold,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                        PrimaryActionButton(
                            title = viewModel.t(MarviL10n.Key.SAVE_PROFILE),
                            onClick = {
                                viewModel.updateProfileNichesFromText(nichesText)
                                viewModel.updateProfileLanguagesFromText(languagesText)
                                viewModel.saveProfileFromEditor { ok ->
                                    saveFailed = !ok
                                    saveMessage = if (ok) {
                                        viewModel.t(MarviL10n.Key.PROFILE_SAVED_SUCCESS)
                                    } else {
                                        viewModel.lastSyncError ?: viewModel.t(MarviL10n.Key.PROFILE_SAVE_FAILED)
                                    }
                                }
                            }
                        )
                    }

                    val verification = viewModel.socialVerification
                    if (verification != null && viewModel.selectedRole == UserRole.CREATOR) {
                        val context = LocalContext.current
                        LaunchedEffect(Unit) { viewModel.loadSocialVerification() }
                        MarviCard {
                            SectionTitle(text = viewModel.t(MarviL10n.Key.SOCIAL_VERIFY_TITLE))
                            Text(viewModel.t(MarviL10n.Key.SOCIAL_VERIFY_SUB), color = MarviColor.Muted)
                            verification.code?.let { code ->
                                if (!verification.isVerified) {
                                    Text(code, color = MarviColor.Rose, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.headlineSmall)
                                    Text(verification.dmMessage, color = MarviColor.Graphite, style = MaterialTheme.typography.bodySmall)
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Box(modifier = Modifier.weight(1f)) {
                                            SecondaryActionButton(
                                                title = viewModel.t(MarviL10n.Key.SOCIAL_VERIFY_COPY_CODE),
                                                onClick = {
                                                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                                    clipboard.setPrimaryClip(ClipData.newPlainText("Marvi verification", verification.dmMessage))
                                                }
                                            )
                                        }
                                        Box(modifier = Modifier.weight(1f)) {
                                            SecondaryActionButton(
                                                title = viewModel.t(MarviL10n.Key.SOCIAL_VERIFY_OPEN_INSTAGRAM),
                                                onClick = {
                                                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://instagram.com/${verification.marviInstagramHandle}")))
                                                }
                                            )
                                        }
                                    }
                                    if (verification.state == SocialVerificationState.PENDING) {
                                        PrimaryActionButton(
                                            title = viewModel.t(MarviL10n.Key.SOCIAL_VERIFY_SENT_BTN),
                                            onClick = { viewModel.submitSocialVerificationSent { } }
                                        )
                                    }
                                }
                            }
                            Text(
                                when (verification.state) {
                                    SocialVerificationState.VERIFIED -> viewModel.t(MarviL10n.Key.SOCIAL_VERIFY_VERIFIED)
                                    SocialVerificationState.SUBMITTED -> viewModel.t(MarviL10n.Key.SOCIAL_VERIFY_SUBMITTED)
                                    SocialVerificationState.PENDING -> viewModel.t(MarviL10n.Key.SOCIAL_VERIFY_PENDING)
                                    SocialVerificationState.NEEDS_HANDLES -> viewModel.t(MarviL10n.Key.NEEDS_SOCIAL)
                                },
                                color = if (verification.isVerified) MarviColor.Emerald else MarviColor.Gold,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }
                }

                ProfileMainTab.ACCOUNT -> {
                    val context = LocalContext.current
                    viewModel.accountReferralCode?.takeIf { it.isNotBlank() }?.let { code ->
                        MarviCard {
                            SectionTitle(text = viewModel.t(MarviL10n.Key.REFERRAL_CODE_TITLE))
                            Text(code, color = MarviColor.Rose, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.headlineSmall)
                            SecondaryActionButton(
                                title = viewModel.t(MarviL10n.Key.COPY_CODE),
                                onClick = {
                                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                    clipboard.setPrimaryClip(ClipData.newPlainText("Marvi invite", code))
                                }
                            )
                        }
                    }

                    if (viewModel.accountRole == UserRole.ADMIN || viewModel.allowedRoles.contains(UserRole.ADMIN)) {
                        MarviCard {
                            SectionTitle(text = viewModel.t(MarviL10n.Key.WORKSPACE))
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                viewModel.allowedRoles.forEach { role ->
                                    FilterChipPill(
                                        label = roleLabel(role, viewModel),
                                        selected = viewModel.selectedRole == role,
                                        onClick = { viewModel.switchRole(role) }
                                    )
                                }
                            }
                        }
                    }

                    if (viewModel.selectedRole == UserRole.CREATOR && viewModel.accountRole != UserRole.ADMIN) {
                        if (viewModel.accountPausedBySelf) {
                            PrimaryActionButton(
                                title = viewModel.t(MarviL10n.Key.REACTIVATE_ACCOUNT),
                                onClick = { viewModel.reactivateAccount() }
                            )
                        } else {
                            SecondaryActionButton(
                                title = viewModel.t(MarviL10n.Key.PAUSE_ACCOUNT),
                                onClick = { viewModel.pauseAccount() }
                            )
                        }
                    }

                    TextButton(onClick = { viewModel.signOut() }, modifier = Modifier.fillMaxWidth()) {
                        Text(viewModel.t(MarviL10n.Key.SIGN_OUT), color = MarviColor.Tomato)
                    }

                    var showDeleteConfirm by remember { mutableStateOf(false) }
                    var deleteConfirmText by remember { mutableStateOf("") }
                    TextButton(
                        onClick = { showDeleteConfirm = true },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(viewModel.t(MarviL10n.Key.DELETE_ACCOUNT), color = MarviColor.Tomato)
                    }
                    if (showDeleteConfirm) {
                        MarviCard {
                            Text(viewModel.t(MarviL10n.Key.DELETE_ACCOUNT_SUB), color = MarviColor.Muted)
                            MarviTextField(
                                value = deleteConfirmText,
                                onValueChange = { deleteConfirmText = it },
                                placeholder = viewModel.t(MarviL10n.Key.DELETE_ACCOUNT_CONFIRM)
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                TextButton(onClick = { showDeleteConfirm = false }) {
                                    Text(viewModel.t(MarviL10n.Key.CANCEL))
                                }
                                TextButton(
                                    enabled = deleteConfirmText.trim().equals("DELETE", ignoreCase = true),
                                    onClick = {
                                        viewModel.deleteAccountPermanently {
                                            showDeleteConfirm = false
                                            deleteConfirmText = ""
                                        }
                                    }
                                ) {
                                    Text(viewModel.t(MarviL10n.Key.DELETE_ACCOUNT), color = MarviColor.Tomato)
                                }
                            }
                        }
                    }
                }

                ProfileMainTab.SETTINGS -> {
                    MarviCard {
                        SectionTitle(
                            text = viewModel.t(MarviL10n.Key.LANGUAGE_LABEL),
                            subtitle = viewModel.t(MarviL10n.Key.LANGUAGE_SUBTITLE)
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            FilterChipPill(
                                label = "Türkçe",
                                selected = viewModel.preferredLanguage == AppLanguage.TURKISH,
                                onClick = { viewModel.switchLanguage(AppLanguage.TURKISH) }
                            )
                            FilterChipPill(
                                label = "English",
                                selected = viewModel.preferredLanguage == AppLanguage.ENGLISH,
                                onClick = { viewModel.switchLanguage(AppLanguage.ENGLISH) }
                            )
                        }
                    }
                }
            }
        }
    }
}

private fun roleLabel(role: UserRole, viewModel: AppViewModel): String = when (role) {
    UserRole.CREATOR -> viewModel.t(MarviL10n.Key.ROLE_CREATOR)
    UserRole.VENUE -> viewModel.t(MarviL10n.Key.ROLE_VENUE)
    UserRole.ADMIN -> viewModel.t(MarviL10n.Key.ROLE_ADMIN)
}

@Composable
private fun ShowcaseSection(viewModel: AppViewModel) {
    val context = LocalContext.current
    var adding by remember { mutableStateOf(false) }
    var link by remember { mutableStateOf("") }
    var caption by remember { mutableStateOf("") }

    MarviCard {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            SectionTitle(text = viewModel.t(MarviL10n.Key.SHOWCASE_TITLE))
            TextButton(onClick = { adding = !adding }) {
                Text(if (adding) viewModel.t(MarviL10n.Key.CLOSE) else viewModel.t(MarviL10n.Key.SHOWCASE_ADD_LINK))
            }
        }

        if (adding) {
            MarviTextField(
                value = link,
                onValueChange = { link = it },
                placeholder = viewModel.t(MarviL10n.Key.SHOWCASE_LINK_PLACEHOLDER)
            )
            MarviTextField(
                value = caption,
                onValueChange = { caption = it },
                placeholder = viewModel.t(MarviL10n.Key.SHOWCASE_CAPTION_PLACEHOLDER)
            )
            PrimaryActionButton(
                title = viewModel.t(MarviL10n.Key.ADD),
                enabled = link.isNotBlank(),
                onClick = {
                    if (link.isNotBlank()) {
                        viewModel.addShowcaseLink(link, caption) {
                            link = ""; caption = ""; adding = false
                        }
                    }
                }
            )
        }

        if (viewModel.showcaseItems.isEmpty()) {
            Text(viewModel.t(MarviL10n.Key.SHOWCASE_EMPTY), color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
        } else {
            viewModel.showcaseItems.forEach { item ->
                Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            item.caption.ifBlank { item.externalUrl.ifBlank { item.mediaUrl } },
                            color = MarviColor.Ink,
                            maxLines = 1
                        )
                        val url = item.externalUrl.ifBlank { item.mediaUrl }
                        if (url.isNotBlank()) {
                            Text(url, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall, maxLines = 1)
                        }
                    }
                    val openUrl = item.externalUrl.ifBlank { item.mediaUrl }
                    if (openUrl.isNotBlank()) {
                        TextButton(onClick = {
                            runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(openUrl))) }
                        }) { Text(viewModel.t(MarviL10n.Key.OPEN_LINK)) }
                    }
                    TextButton(onClick = { viewModel.deleteShowcaseItem(item.id) }) {
                        Text(viewModel.t(MarviL10n.Key.DELETE), color = MarviColor.Tomato)
                    }
                }
            }
        }
    }
}

@Composable
private fun CollaborationHistorySection(viewModel: AppViewModel) {
    MarviCard {
        SectionTitle(text = viewModel.t(MarviL10n.Key.COLLAB_HISTORY_TITLE))
        if (viewModel.collaborationHistory.isEmpty()) {
            Text(viewModel.t(MarviL10n.Key.NO_COLLABORATIONS), color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
        } else {
            viewModel.collaborationHistory.forEach { entry ->
                Column(modifier = Modifier.padding(vertical = 4.dp)) {
                    Text(entry.title.ifBlank { entry.venueName }, color = MarviColor.Ink, fontWeight = FontWeight.SemiBold)
                    Text(
                        listOf(
                            entry.venueName,
                            entry.area,
                            viewModel.localizeServerText(entry.dateLabel)
                        ).filter { it.isNotBlank() }.joinToString(" · "),
                        color = MarviColor.Muted,
                        style = MaterialTheme.typography.bodySmall
                    )
                    entry.venueRating?.let { rating ->
                        Text(
                            "${viewModel.t(MarviL10n.Key.RATING_LABEL)}: ${String.format(java.util.Locale.US, "%.1f", rating)}",
                            color = MarviColor.Gold,
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ProfileSheetRow(
    icon: ImageVector,
    title: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(MarviColor.PanelElevated)
            .border(1.dp, MarviColor.Border, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(icon, contentDescription = title, tint = MarviColor.Rose, modifier = Modifier.size(20.dp))
        Text(
            title,
            color = MarviColor.Ink,
            fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.bodyMedium
        )
    }
}

private fun profileCompletionPercent(viewModel: AppViewModel): Int {
    val profile = viewModel.profile
    var score = 0
    if (profile.name.isNotBlank()) score += 20
    if (profile.handle.isNotBlank() || profile.tiktokHandle.isNotBlank()) score += 20
    if (profile.bio.isNotBlank()) score += 15
    if (profile.city.isNotBlank()) score += 10
    if (profile.avatarUrl.isNotBlank()) score += 15
    if (profile.coverUrl.isNotBlank()) score += 10
    if (profile.status == MembershipStatus.APPROVED) score += 10
    return score.coerceIn(5, 100)
}
