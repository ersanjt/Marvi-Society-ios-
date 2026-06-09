package com.marvisociety.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.marvisociety.app.ui.viewmodel.AppViewModel

@Composable
fun DiscoverScreen(viewModel: AppViewModel) {
    val models = listOf("all", "invitation", "event", "gift", "instant")
    var filter by remember { mutableStateOf("all") }
    val offers = viewModel.offers.filter { filter == "all" || it.model == filter }

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text("Discover", style = MaterialTheme.typography.headlineMedium)
        androidx.compose.foundation.layout.Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            models.forEach { model ->
                FilterChip(
                    selected = filter == model,
                    onClick = { filter = model },
                    label = { Text(model.replaceFirstChar { it.uppercase() }) }
                )
            }
        }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 12.dp)) {
            items(offers) { offer ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(offer.title, style = MaterialTheme.typography.titleMedium)
                        Text("${offer.venue} · ${offer.area}")
                        Text("${offer.valueLabel} · ${offer.remaining}/${offer.capacity} slots")
                    }
                }
            }
        }
    }
}
