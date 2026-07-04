package com.marvisociety.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.marvisociety.app.data.Offer
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel

@Composable
fun DiscoverScreen(viewModel: AppViewModel, onOfferClick: (Offer) -> Unit) {
    var filter by remember { mutableStateOf(DiscoverFilter.ALL) }
    val displayed = when (filter) {
        DiscoverFilter.ALL -> viewModel.offers
        DiscoverFilter.SAVED -> viewModel.interestOffers
    }

    MarviScreen {
        Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
            Text(viewModel.t(MarviL10n.Key.PRIVATE_ACCESS), color = MarviColor.Rose, fontWeight = FontWeight.Bold)
            Text(viewModel.t(MarviL10n.Key.FIND_EXPLORE), style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink)
            Text("${viewModel.profile.city} · ${displayed.size} events", color = MarviColor.Muted)

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(vertical = 12.dp)) {
                FilterChip(
                    selected = filter == DiscoverFilter.ALL,
                    onClick = { filter = DiscoverFilter.ALL },
                    label = { Text(viewModel.t(MarviL10n.Key.FILTER_ALL)) },
                    colors = chipColors()
                )
                FilterChip(
                    selected = filter == DiscoverFilter.SAVED,
                    onClick = { filter = DiscoverFilter.SAVED },
                    label = { Text(viewModel.t(MarviL10n.Key.FILTER_SAVED)) },
                    colors = chipColors()
                )
            }

            if (displayed.isEmpty()) {
                MarviCard {
                    Text(viewModel.t(MarviL10n.Key.NO_EVENTS_TITLE), fontWeight = FontWeight.SemiBold, color = MarviColor.Ink)
                    Text(viewModel.t(MarviL10n.Key.NO_EVENTS_SUB), color = MarviColor.Muted)
                }
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(displayed, key = { it.id }) { offer ->
                        OfferCard(
                            offer = offer,
                            saved = offer.id in viewModel.savedOfferIds,
                            accepted = offer.id in viewModel.acceptedOfferIds,
                            viewModel = viewModel,
                            onClick = { onOfferClick(offer) },
                            onToggleSaved = { viewModel.toggleSaved(offer.id) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun OfferCard(
    offer: Offer,
    saved: Boolean,
    accepted: Boolean,
    viewModel: AppViewModel,
    onClick: () -> Unit,
    onToggleSaved: () -> Unit
) {
    MarviCard(modifier = Modifier.clickable(onClick = onClick)) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.Top) {
            Column(modifier = Modifier.weight(1f)) {
                Text(offer.title, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                Text("${offer.venue} · ${offer.area}", color = MarviColor.Muted)
                Text("${offer.dateLabel} ${offer.timeLabel}".trim(), color = MarviColor.Graphite)
                Text(offer.valueLabel, color = MarviColor.Rose, fontWeight = FontWeight.SemiBold)
                Text("${offer.remaining}/${offer.capacity} slots · ${offer.modelLabel}", color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                if (accepted) Text("Accepted", color = MarviColor.Emerald, fontWeight = FontWeight.SemiBold)
            }
            IconButton(onClick = onToggleSaved) {
                Icon(
                    if (saved) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder,
                    contentDescription = null,
                    tint = if (saved) MarviColor.Rose else MarviColor.Muted
                )
            }
        }
    }
}

private enum class DiscoverFilter { ALL, SAVED }

@Composable
private fun chipColors() = FilterChipDefaults.filterChipColors(
    selectedContainerColor = MarviColor.Rose.copy(alpha = 0.2f),
    selectedLabelColor = MarviColor.Rose,
    labelColor = MarviColor.Graphite
)
