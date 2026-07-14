package com.marvisociety.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
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
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel

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
            OutlinedTextField(
                value = code,
                onValueChange = { code = it; error = "" },
                label = { Text(viewModel.t(MarviL10n.Key.INVITE_PLACEHOLDER)) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                colors = fieldColors()
            )
            if (error.isNotEmpty()) Text(error, color = MarviColor.Tomato)
            if (busy) CircularProgressIndicator(color = MarviColor.Rose)
            Button(
                onClick = {
                    busy = true
                    error = ""
                    viewModel.validateAndRedeemInvite(code) { ok ->
                        busy = false
                        if (!ok) error = viewModel.t(MarviL10n.Key.ERR_INVITE_INVALID)
                    }
                },
                enabled = !busy && code.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
            ) {
                Text(viewModel.t(MarviL10n.Key.CONTINUE), fontWeight = FontWeight.Bold)
            }
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
            OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text(viewModel.t(MarviL10n.Key.FULL_NAME_PLACEHOLDER)) }, modifier = Modifier.fillMaxWidth(), singleLine = true, colors = fieldColors())
            OutlinedTextField(value = instagram, onValueChange = { instagram = it }, label = { Text(viewModel.t(MarviL10n.Key.INSTAGRAM_PLACEHOLDER)) }, modifier = Modifier.fillMaxWidth(), singleLine = true, colors = fieldColors())
            OutlinedTextField(value = tiktok, onValueChange = { tiktok = it }, label = { Text(viewModel.t(MarviL10n.Key.TIKTOK_PLACEHOLDER)) }, modifier = Modifier.fillMaxWidth(), singleLine = true, colors = fieldColors())
            OutlinedTextField(value = city, onValueChange = { city = it }, label = { Text(viewModel.t(MarviL10n.Key.CITY_PLACEHOLDER)) }, modifier = Modifier.fillMaxWidth(), singleLine = true, colors = fieldColors())
            if (error.isNotEmpty()) Text(error, color = MarviColor.Tomato)
            if (busy) CircularProgressIndicator(color = MarviColor.Rose)
            Button(
                onClick = {
                    if ((instagram.isBlank() && tiktok.isBlank()) || city.isBlank()) {
                        error = viewModel.t(MarviL10n.Key.NEEDS_SOCIAL)
                        return@Button
                    }
                    busy = true
                    viewModel.completeProfileSetup(name, instagram, tiktok, city) {
                        busy = false
                        viewModel.refreshFromServer()
                    }
                },
                enabled = !busy,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
            ) {
                Text(viewModel.t(MarviL10n.Key.CONTINUE), fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun fieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = MarviColor.Rose,
    unfocusedBorderColor = MarviColor.Border,
    focusedTextColor = MarviColor.Ink,
    unfocusedTextColor = MarviColor.Ink,
    focusedLabelColor = MarviColor.Muted,
    unfocusedLabelColor = MarviColor.Muted,
    cursorColor = MarviColor.Rose
)
