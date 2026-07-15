package com.marvisociety.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.marvisociety.app.data.Offer
import com.marvisociety.app.data.OfferCategory
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.OfferImagery
import com.marvisociety.app.ui.components.EmptyStateView
import com.marvisociety.app.ui.components.FilterChipPill
import com.marvisociety.app.ui.components.HomeHeader
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.components.OfferImageView
import com.marvisociety.app.ui.components.StatusPill
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.theme.MarviGradient
import com.marvisociety.app.ui.viewmodel.AppViewModel

@Composable
fun DiscoverScreen(viewModel: AppViewModel, onOfferClick: (Offer) -> Unit) {
    var filter by remember { mutableStateOf(DiscoverFilter.ALL) }
    var categoryFilter by remember { mutableStateOf<OfferCategory?>(null) }

    val base = when (filter) {
        DiscoverFilter.ALL -> viewModel.offers
        DiscoverFilter.SAVED -> viewModel.interestOffers
    }
    val displayed = if (categoryFilter == null) base else base.filter { it.category == categoryFilter }
    val featured = viewModel.offers.take(5)
    val city = viewModel.profile.city.ifBlank { "Istanbul" }

    MarviScreen {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp)
        ) {
            item {
                Spacer(Modifier.height(8.dp))
                HomeHeader(
                    greeting = viewModel.t(MarviL10n.Key.FIND_EXPLORE),
                    subtitle = viewModel.t(MarviL10n.Key.PRIVATE_ACCESS),
                    avatarUrl = viewModel.profile.avatarUrl.takeIf { it.isNotBlank() },
                    avatarLetter = viewModel.profile.name.ifBlank { "M" }
                )
            }

            item {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        viewModel.t(MarviL10n.Key.PRIVATE_ACCESS).uppercase(),
                        style = MaterialTheme.typography.labelSmall,
                        color = MarviColor.Rose,
                        fontWeight = FontWeight.Bold
                    )
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(
                            "Up next in ",
                            style = MaterialTheme.typography.displaySmall,
                            color = MarviColor.Ink
                        )
                        Text(
                            city,
                            style = MaterialTheme.typography.displaySmall.merge(
                                TextStyle(brush = MarviGradient.Brand)
                            )
                        )
                    }
                    Text(
                        "${displayed.size} events",
                        style = MaterialTheme.typography.bodySmall,
                        color = MarviColor.Rose,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            if (featured.isNotEmpty()) {
                item {
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        items(featured, key = { "feat-${it.id}" }) { offer ->
                            FeaturedOfferCard(offer) { onOfferClick(offer) }
                        }
                    }
                }
            }

            item {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChipPill(
                        label = viewModel.t(MarviL10n.Key.FILTER_ALL),
                        selected = filter == DiscoverFilter.ALL,
                        onClick = { filter = DiscoverFilter.ALL }
                    )
                    FilterChipPill(
                        label = viewModel.t(MarviL10n.Key.FILTER_SAVED),
                        selected = filter == DiscoverFilter.SAVED,
                        onClick = { filter = DiscoverFilter.SAVED }
                    )
                }
            }

            item {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    item {
                        FilterChipPill(
                            label = "All",
                            selected = categoryFilter == null,
                            onClick = { categoryFilter = null }
                        )
                    }
                    items(OfferCategory.entries) { cat ->
                        FilterChipPill(
                            label = cat.name.lowercase().replaceFirstChar { it.uppercase() },
                            selected = categoryFilter == cat,
                            onClick = { categoryFilter = cat }
                        )
                    }
                }
            }

            if (displayed.isEmpty()) {
                item {
                    EmptyStateView(
                        title = viewModel.t(MarviL10n.Key.NO_EVENTS_TITLE),
                        subtitle = viewModel.t(MarviL10n.Key.NO_EVENTS_SUB)
                    )
                }
            } else {
                items(displayed, key = { it.id }) { offer ->
                    EventListCard(
                        offer = offer,
                        saved = offer.id in viewModel.savedOfferIds,
                        accepted = offer.id in viewModel.acceptedOfferIds,
                        onClick = { onOfferClick(offer) },
                        onToggleSaved = { viewModel.toggleSaved(offer.id) }
                    )
                }
            }

            item { Spacer(Modifier.height(24.dp)) }
        }
    }
}

@Composable
private fun FeaturedOfferCard(offer: Offer, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .width(200.dp)
            .clip(RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
    ) {
        OfferImageView(
            url = OfferImagery.imageUrl(offer),
            contentDescription = offer.title,
            modifier = Modifier.fillMaxWidth(),
            height = 120.dp,
            cornerRadius = 0.dp
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(MarviColor.Panel)
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                offer.venue.uppercase(),
                style = MaterialTheme.typography.labelSmall,
                color = MarviColor.Rose,
                fontWeight = FontWeight.Bold,
                maxLines = 1
            )
            Text(
                offer.title,
                style = MaterialTheme.typography.titleMedium,
                color = MarviColor.Ink,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun EventListCard(
    offer: Offer,
    saved: Boolean,
    accepted: Boolean,
    onClick: () -> Unit,
    onToggleSaved: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MarviColor.Panel)
            .border(1.dp, MarviColor.Border, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        OfferImageView(
            url = OfferImagery.imageUrl(offer),
            contentDescription = offer.title,
            modifier = Modifier.size(72.dp, 80.dp),
            height = 80.dp,
            cornerRadius = 14.dp
        )
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                offer.venue.uppercase(),
                style = MaterialTheme.typography.labelSmall,
                color = MarviColor.Rose,
                fontWeight = FontWeight.Bold,
                maxLines = 1
            )
            Text(
                offer.title,
                style = MaterialTheme.typography.titleMedium,
                color = MarviColor.Ink,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                "${offer.area} · ${offer.dateLabel}",
                style = MaterialTheme.typography.bodySmall,
                color = MarviColor.Muted,
                maxLines = 1
            )
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                StatusPill(offer.modelLabel, MarviColor.Aubergine)
                if (accepted) StatusPill("Accepted", MarviColor.Emerald)
            }
        }
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(MarviColor.PanelElevated)
                .clickable(onClick = onToggleSaved),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                if (saved) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                contentDescription = null,
                tint = if (saved) MarviColor.Rose else MarviColor.Muted,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

private enum class DiscoverFilter { ALL, SAVED }
