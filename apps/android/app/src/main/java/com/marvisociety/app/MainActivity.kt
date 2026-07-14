package com.marvisociety.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import com.marvisociety.app.ui.MarviApp
import com.marvisociety.app.ui.viewmodel.AppViewModel
import com.marvisociety.app.ui.viewmodel.AppViewModelFactory

class MainActivity : ComponentActivity() {
    private val viewModel: AppViewModel by viewModels { AppViewModelFactory(application) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleDeepLink(intent)
        setContent {
            MarviApp(viewModel = viewModel)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeepLink(intent)
    }

    private fun handleDeepLink(intent: Intent?) {
        val data: Uri = intent?.data ?: return
        when {
            com.marvisociety.app.network.GoogleOAuth.isAuthCallback(data) -> {
                viewModel.completeGoogleSignIn(data)
            }
            data.scheme.equals("marvisociety", ignoreCase = true) &&
                data.host.equals("invite", ignoreCase = true) -> {
                viewModel.applyPendingInviteCode(data.getQueryParameter("code"))
            }
            data.scheme.equals("https", ignoreCase = true) &&
                data.host?.contains("marvisociety.com") == true -> {
                viewModel.applyPendingInviteCode(
                    data.getQueryParameter("invite_code") ?: data.getQueryParameter("code")
                )
            }
        }
    }
}
