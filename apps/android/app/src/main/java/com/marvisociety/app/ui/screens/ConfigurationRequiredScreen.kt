package com.marvisociety.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel

@Composable
fun ConfigurationRequiredScreen(viewModel: AppViewModel) {
    MarviScreen {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                "Marvi Society",
                style = MaterialTheme.typography.headlineMedium,
                color = MarviColor.Ink,
                fontWeight = FontWeight.Bold
            )
            MarviCard {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        viewModel.t(MarviL10n.Key.BACKEND_DEMO),
                        color = MarviColor.Gold,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        "Add MARVI_SUPABASE_URL and MARVI_SUPABASE_ANON_KEY to apps/android/local.properties (same as iOS Secrets.xcconfig), then rebuild.",
                        color = MarviColor.Graphite,
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        }
    }
}
