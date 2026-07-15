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
                Text("@${viewModel.profile.handle} · ${viewModel.profile.city}", color = MarviColor.Muted)
                StatusPill("Score ${viewModel.profile.score}", MarviColor.Gold)
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

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                listOf(
                    ProfileMainTab.OVERVIEW to MarviL10n.Key.PROFILE_TAB_OVERVIEW,
                    ProfileMainTab.EDIT to MarviL10n.Key.PROFILE_TAB_EDIT,
                    ProfileMainTab.ACCOUNT to MarviL10n.Key.PROFILE_TAB_ACCOUNT,
                    ProfileMainTab.SETTINGS to MarviL10n.Key.PROFILE_TAB_SETTINGS
                ).forEach { (tab, key) ->
                    FilterChip(
                        selected = selectedTab == tab,
                        onClick = { selectedTab = tab },
                        label = { Text(viewModel.t(key)) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = MarviColor.Rose.copy(alpha = 0.25f),
                            selectedLabelColor = MarviColor.Rose
                        )
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
                        Button(
                            onClick = { viewModel.saveProfileFromEditor() },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Emerald)
                        ) {
                            Text(viewModel.t(MarviL10n.Key.SAVE_PROFILE))
                        }
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
                    TextButton(onClick = { viewModel.signOut() }, modifier = Modifier.fillMaxWidth()) {
                        Text(viewModel.t(MarviL10n.Key.SIGN_OUT), color = MarviColor.Tomato)
                    }
                }

                ProfileMainTab.SETTINGS -> {
                    Text(viewModel.t(MarviL10n.Key.LANGUAGE_LABEL), fontWeight = FontWeight.SemiBold, color = MarviColor.Ink)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilterChip(
                            selected = viewModel.preferredLanguage == AppLanguage.ENGLISH,
                            onClick = { viewModel.switchLanguage(AppLanguage.ENGLISH) },
                            label = { Text("English") }
                        )
                        FilterChip(
                            selected = viewModel.preferredLanguage == AppLanguage.TURKISH,
                            onClick = { viewModel.switchLanguage(AppLanguage.TURKISH) },
                            label = { Text("Türkçe") }
                        )
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
