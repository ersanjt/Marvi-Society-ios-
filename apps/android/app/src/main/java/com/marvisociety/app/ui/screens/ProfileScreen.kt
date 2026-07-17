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
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.marvisociety.app.data.AppLanguage
import com.marvisociety.app.data.MembershipStatus
import com.marvisociety.app.data.SocialVerificationState
import com.marvisociety.app.data.UserRole
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.FilterChipPill
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.components.MarviTextField
import com.marvisociety.app.ui.components.PrimaryActionButton
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
            Box(modifier = Modifier.fillMaxWidth()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(120.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(MarviGradient.BrandVertical)
                        .clickable {
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
                    }
                }
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .offset(x = 8.dp, y = 28.dp)
                        .size(72.dp)
                        .clip(CircleShape)
                        .background(MarviGradient.BrandVertical)
                        .clickable {
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
                            style = MaterialTheme.typography.headlineSmall
                        )
                    }
                }
            }

            Column(modifier = Modifier.padding(top = 28.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    viewModel.profile.name.ifBlank { viewModel.t(MarviL10n.Key.ROLE_CREATOR) },
                    style = MaterialTheme.typography.displaySmall,
                    color = MarviColor.Ink
                )
                val profileSubtitle = listOfNotNull(
                    viewModel.profile.handle.takeIf { it.isNotBlank() }?.let { "@$it" },
                    viewModel.profile.city.takeIf { it.isNotBlank() }
                ).joinToString(" · ")
                if (profileSubtitle.isNotBlank()) {
                    Text(profileSubtitle, color = MarviColor.Muted)
                }
                StatusPill("${viewModel.t(MarviL10n.Key.SCORE_LABEL)} ${viewModel.profile.score}", MarviColor.Gold)
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(modifier = Modifier.weight(1f)) {
                    SecondaryActionButton(
                        title = viewModel.t(MarviL10n.Key.CHANGE_PHOTO),
                        onClick = {
                            avatarPicker.launch(
                                PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                            )
                        }
                    )
                }
                Box(modifier = Modifier.weight(1f)) {
                    SecondaryActionButton(
                        title = viewModel.t(MarviL10n.Key.CHANGE_COVER),
                        onClick = {
                            coverPicker.launch(
                                PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                            )
                        }
                    )
                }
            }

            if (showCompletion) {
                MarviCard {
                    SectionTitle(
                        text = viewModel.t(MarviL10n.Key.PROFILE_COMPLETION_TITLE)
                    )
                    Text(viewModel.t(MarviL10n.Key.PROFILE_COMPLETION_SUB), color = MarviColor.Muted)

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
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Text("${viewModel.followCounts.followers} ${viewModel.t(MarviL10n.Key.FOLLOWERS)}", color = MarviColor.Ink)
                        Text("${viewModel.followCounts.following} ${viewModel.t(MarviL10n.Key.FOLLOWING_LABEL)}", color = MarviColor.Ink)
                    }

                    if (viewModel.allowedRoles.size > 1) {
                        MarviCard {
                            SectionTitle(text = viewModel.t(MarviL10n.Key.WORKSPACE))
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                viewModel.allowedRoles.forEach { role ->
                                    FilterChip(
                                        selected = viewModel.selectedRole == role,
                                        onClick = { viewModel.switchRole(role) },
                                        label = { Text(roleLabel(role, viewModel)) },
                                        colors = FilterChipDefaults.filterChipColors(
                                            selectedContainerColor = MarviColor.Rose.copy(alpha = 0.2f),
                                            selectedLabelColor = MarviColor.Rose
                                        )
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
                    MarviCard {
                        SectionTitle(text = viewModel.t(MarviL10n.Key.PROFILE_SETUP_TITLE))
                        OutlinedTextField(
                            value = viewModel.profile.handle,
                            onValueChange = { viewModel.updateProfileHandle(it) },
                            label = { Text(viewModel.t(MarviL10n.Key.INSTAGRAM_PLACEHOLDER)) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = viewModel.profile.tiktokHandle,
                            onValueChange = { viewModel.updateProfileTiktok(it) },
                            label = { Text(viewModel.t(MarviL10n.Key.TIKTOK_PLACEHOLDER)) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = viewModel.profile.city,
                            onValueChange = { viewModel.updateProfileCity(it) },
                            label = { Text(viewModel.t(MarviL10n.Key.CITY_PLACEHOLDER)) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = viewModel.profile.bio,
                            onValueChange = { viewModel.updateProfileBio(it) },
                            label = { Text(viewModel.t(MarviL10n.Key.BIO_PLACEHOLDER)) },
                            modifier = Modifier.fillMaxWidth(),
                            minLines = 3
                        )
                        PrimaryActionButton(
                            title = viewModel.t(MarviL10n.Key.SAVE_PROFILE),
                            onClick = viewModel::saveProfileFromEditor
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
                                        Button(onClick = {
                                            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                            clipboard.setPrimaryClip(ClipData.newPlainText("Marvi verification", verification.dmMessage))
                                        }) { Text(viewModel.t(MarviL10n.Key.SOCIAL_VERIFY_COPY_CODE)) }
                                        Button(onClick = {
                                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://instagram.com/${verification.marviInstagramHandle}")))
                                        }) { Text(viewModel.t(MarviL10n.Key.SOCIAL_VERIFY_OPEN_INSTAGRAM)) }
                                    }
                                    if (verification.state == SocialVerificationState.PENDING) {
                                        Button(
                                            onClick = { viewModel.submitSocialVerificationSent { } },
                                            colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                                        ) { Text(viewModel.t(MarviL10n.Key.SOCIAL_VERIFY_SENT_BTN)) }
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
                                    FilterChip(
                                        selected = viewModel.selectedRole == role,
                                        onClick = { viewModel.switchRole(role) },
                                        label = { Text(roleLabel(role, viewModel)) }
                                    )
                                }
                            }
                        }
                    }

                    if (viewModel.selectedRole == UserRole.CREATOR && viewModel.accountRole != UserRole.ADMIN) {
                        if (viewModel.accountPausedBySelf) {
                            Button(
                                onClick = { viewModel.reactivateAccount() },
                                modifier = Modifier.fillMaxWidth(),
                                colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Emerald)
                            ) { Text(viewModel.t(MarviL10n.Key.REACTIVATE_ACCOUNT)) }
                        } else {
                            OutlinedButton(
                                onClick = { viewModel.pauseAccount() },
                                modifier = Modifier.fillMaxWidth()
                            ) { Text(viewModel.t(MarviL10n.Key.PAUSE_ACCOUNT), color = MarviColor.Gold) }
                        }
                    }

                    TextButton(onClick = { viewModel.signOut() }, modifier = Modifier.fillMaxWidth()) {
                        Text(viewModel.t(MarviL10n.Key.SIGN_OUT), color = MarviColor.Tomato)
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
            OutlinedTextField(
                value = link,
                onValueChange = { link = it },
                label = { Text(viewModel.t(MarviL10n.Key.SHOWCASE_LINK_PLACEHOLDER)) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )
            OutlinedTextField(
                value = caption,
                onValueChange = { caption = it },
                label = { Text(viewModel.t(MarviL10n.Key.SHOWCASE_CAPTION_PLACEHOLDER)) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )
            Button(
                onClick = {
                    if (link.isNotBlank()) {
                        viewModel.addShowcaseLink(link, caption) {
                            link = ""; caption = ""; adding = false
                        }
                    }
                },
                enabled = link.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
            ) { Text(viewModel.t(MarviL10n.Key.ADD)) }
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
