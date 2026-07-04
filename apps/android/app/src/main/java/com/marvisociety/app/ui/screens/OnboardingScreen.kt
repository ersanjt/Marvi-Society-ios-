package com.marvisociety.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel

@Composable
fun OnboardingScreen(viewModel: AppViewModel) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var fullName by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("Istanbul") }
    var isSignUp by remember { mutableStateOf(true) }
    var localError by remember { mutableStateOf("") }

    MarviScreen {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                viewModel.t(MarviL10n.Key.HERO_LINE1),
                style = MaterialTheme.typography.headlineLarge,
                color = MarviColor.Ink,
                fontWeight = FontWeight.Bold
            )
            Text(viewModel.t(MarviL10n.Key.HERO_LINE2), color = MarviColor.Graphite)
            Text(viewModel.t(MarviL10n.Key.HERO_SUBTITLE), color = MarviColor.Muted)

            if (!viewModel.isRemoteMode) {
                Text(viewModel.t(MarviL10n.Key.BACKEND_DEMO), color = MarviColor.Gold, modifier = Modifier.padding(vertical = 8.dp))
            }

            Text(
                if (isSignUp) viewModel.t(MarviL10n.Key.CREATE_ACCOUNT) else viewModel.t(MarviL10n.Key.WELCOME_BACK),
                fontWeight = FontWeight.SemiBold,
                color = MarviColor.Ink
            )
            Text(viewModel.t(MarviL10n.Key.PROFILE_COMPLETION_SUB), color = MarviColor.Muted)

            MarviField(email, { email = it }, viewModel.t(MarviL10n.Key.EMAIL))
            MarviField(password, { password = it }, viewModel.t(MarviL10n.Key.PASSWORD), isPassword = true)
            if (isSignUp) {
                MarviField(fullName, { fullName = it }, viewModel.t(MarviL10n.Key.FULL_NAME_PLACEHOLDER))
                MarviField(city, { city = it }, viewModel.t(MarviL10n.Key.CITY_PLACEHOLDER))
            }

            if (localError.isNotEmpty() || viewModel.authError != null) {
                Text(localError.ifEmpty { viewModel.authError.orEmpty() }, color = MarviColor.Tomato)
            }

            if (viewModel.isBootstrapping) {
                CircularProgressIndicator(color = MarviColor.Rose)
            }

            Button(
                onClick = {
                    localError = ""
                    if (email.isBlank() || password.length < 6) {
                        localError = viewModel.t(MarviL10n.Key.ERR_SIGN_IN_REQUIRED)
                        return@Button
                    }
                    if (viewModel.isRemoteMode) {
                        if (isSignUp) {
                            viewModel.signUp(email, password, fullName, city) {
                                viewModel.finishOnboarding()
                            }
                        } else {
                            viewModel.signIn(email, password) {
                                viewModel.finishOnboarding()
                            }
                        }
                    } else {
                        viewModel.finishOnboarding()
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose),
                enabled = !viewModel.isBootstrapping
            ) {
                Text(
                    if (viewModel.isBootstrapping) viewModel.t(MarviL10n.Key.SIGNING_IN)
                    else viewModel.t(MarviL10n.Key.GET_STARTED)
                )
            }

            TextButton(onClick = { isSignUp = !isSignUp }) {
                Text(
                    if (isSignUp) viewModel.t(MarviL10n.Key.WELCOME_BACK) else viewModel.t(MarviL10n.Key.CREATE_ACCOUNT),
                    color = MarviColor.Rose
                )
            }

            if (!isSignUp) {
                TextButton(onClick = { viewModel.resetPassword(email) { localError = "Reset email sent." } }) {
                    Text(viewModel.t(MarviL10n.Key.FORGOT_PASSWORD), color = MarviColor.Muted)
                }
            }

            if (!viewModel.isRemoteMode) {
                Button(onClick = { viewModel.finishOnboarding() }, modifier = Modifier.fillMaxWidth()) {
                    Text("Skip to demo")
                }
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
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
        singleLine = !isPassword,
        visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = MarviColor.Rose,
            unfocusedBorderColor = MarviColor.Border,
            focusedTextColor = MarviColor.Ink,
            unfocusedTextColor = MarviColor.Ink
        )
    )
}
