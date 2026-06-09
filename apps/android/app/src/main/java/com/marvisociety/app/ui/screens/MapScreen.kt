package com.marvisociety.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.marvisociety.app.ui.viewmodel.AppViewModel

@Composable
fun MapScreen(viewModel: AppViewModel) {
    val instant = viewModel.instantOffers()

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text("Nearby", style = MaterialTheme.typography.headlineMedium)
        Text("Instant walk-in offers near you (map SDK in Phase 4b).")
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 12.dp)) {
            items(instant) { offer ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(offer.venue, style = MaterialTheme.typography.titleMedium)
                        Text("${offer.area} · ${offer.valueLabel}")
                        Text("Model: ${offer.model}")
                    }
                }
            }
        }
    }
}
