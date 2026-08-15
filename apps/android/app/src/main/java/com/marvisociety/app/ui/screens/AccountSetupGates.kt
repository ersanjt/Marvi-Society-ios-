package com.marvisociety.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.marvisociety.app.data.MembershipStatus
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.FilterChipPill
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.components.MarviTextField
import com.marvisociety.app.ui.components.PrimaryActionButton
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Row

/** Full-screen gate matching iOS InviteRequiredView. */
@Composable
fun InviteRequiredScreen(viewModel: AppViewModel) {
    var code by remember { mutableStateOf(viewModel.pendingInviteCode.orEmpty()) }
    var error by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }

    LaunchedEffect(viewModel.pendingInviteCode) {
        if (!viewModel.pendingInviteCode.isNullOrBlank() && code.isBlank()) {
            code = viewModel.pendingInviteCode.orEmpty()
        }
    }

    MarviScreen {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text(
                viewModel.t(MarviL10n.Key.NEEDS_INVITE),
                style = MaterialTheme.typography.headlineMedium,
                color = MarviColor.Ink,
                fontWeight = FontWeight.Bold
            )
            Text(viewModel.t(MarviL10n.Key.INVITE_SUBTITLE), color = MarviColor.Muted)
            MarviTextField(code, { code = it; error = "" }, viewModel.t(MarviL10n.Key.INVITE_PLACEHOLDER))
            if (error.isNotEmpty()) Text(error, color = MarviColor.Tomato)
            if (busy) CircularProgressIndicator(color = MarviColor.Rose)
            PrimaryActionButton(
                title = viewModel.t(MarviL10n.Key.CONTINUE),
                enabled = !busy && code.isNotBlank(),
                onClick = {
                    busy = true
                    error = ""
                    viewModel.validateAndRedeemInvite(code) { ok ->
                        busy = false
                        if (!ok) error = viewModel.t(MarviL10n.Key.ERR_INVITE_INVALID)
                    }
                }
            )
        }
    }
}

/** Full-screen gate matching iOS SocialProfileSetupView (handles only). */
@Composable
fun SocialHandlesRequiredScreen(viewModel: AppViewModel) {
    var name by remember { mutableStateOf(viewModel.profile.name) }
    var instagram by remember { mutableStateOf(viewModel.profile.handle) }
    var tiktok by remember { mutableStateOf(viewModel.profile.tiktokHandle) }
    var city by remember { mutableStateOf(viewModel.profile.city.ifBlank { "Istanbul" }) }
    var error by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }

    MarviScreen {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text(
                viewModel.t(MarviL10n.Key.NEEDS_SOCIAL),
                style = MaterialTheme.typography.headlineMedium,
                color = MarviColor.Ink,
                fontWeight = FontWeight.Bold
            )
            Text(viewModel.t(MarviL10n.Key.PROFILE_SETUP_SUB), color = MarviColor.Muted)
            MarviTextField(name, { name = it }, viewModel.t(MarviL10n.Key.FULL_NAME_PLACEHOLDER))
            MarviTextField(instagram, { instagram = it }, viewModel.t(MarviL10n.Key.INSTAGRAM_PLACEHOLDER))
            MarviTextField(tiktok, { tiktok = it }, viewModel.t(MarviL10n.Key.TIKTOK_PLACEHOLDER))
            MarviTextField(city, { city = it }, viewModel.t(MarviL10n.Key.CITY_PLACEHOLDER))
            Row(
                modifier = Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                listOf("Istanbul", "Dubai", "London").forEach { option ->
                    FilterChipPill(
                        label = option,
                        selected = city.equals(option, ignoreCase = true),
                        onClick = { city = option }
                    )
                }
            }
            if (error.isNotEmpty()) Text(error, color = MarviColor.Tomato)
            if (busy) CircularProgressIndicator(color = MarviColor.Rose)
            PrimaryActionButton(
                title = viewModel.t(MarviL10n.Key.CONTINUE),
                enabled = !busy,
                onClick = {
                    if ((instagram.isBlank() && tiktok.isBlank()) || city.isBlank()) {
                        error = viewModel.t(MarviL10n.Key.NEEDS_SOCIAL)
                        return@PrimaryActionButton
                    }
                    busy = true
                    viewModel.completeProfileSetup(name, instagram, tiktok, city) { succeeded ->
                        busy = false
                        if (succeeded) {
                            viewModel.refreshFromServer()
                        } else {
                            error = viewModel.lastSyncError
                                ?: viewModel.t(MarviL10n.Key.SYNC_ERROR)
                        }
                    }
                }
            )
        }
    }
}

/** Full-screen gate until admin approves membership (matches iOS ApprovalPendingView). */
@Composable
fun ApprovalPendingScreen(viewModel: AppViewModel) {
    val paused = viewModel.profile.status == MembershipStatus.PAUSED

    LaunchedEffect(viewModel.needsAdminApproval) {
        while (viewModel.needsAdminApproval) {
            kotlinx.coroutines.delay(20_000)
            viewModel.refreshFromServer()
        }
    }

    MarviScreen {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text(
                if (paused) {
                    viewModel.t(MarviL10n.Key.MEMBERSHIP_PAUSED)
                } else {
                    viewModel.t(MarviL10n.Key.UNDER_REVIEW_BANNER)
                },
                style = MaterialTheme.typography.headlineMedium,
                color = MarviColor.Ink,
                fontWeight = FontWeight.Bold
            )
            Text(
                if (paused) {
                    viewModel.t(MarviL10n.Key.AWAITING_APPROVAL)
                } else {
                    viewModel.t(MarviL10n.Key.UNDER_REVIEW_BANNER_SUB)
                },
                color = MarviColor.Muted
            )
            if (viewModel.isSyncing) CircularProgressIndicator(color = MarviColor.Rose)
            PrimaryActionButton(
                title = viewModel.t(MarviL10n.Key.SYNC_FROM_SERVER),
                enabled = !viewModel.isSyncing,
                onClick = viewModel::refreshFromServer
            )
        }
    }
}
