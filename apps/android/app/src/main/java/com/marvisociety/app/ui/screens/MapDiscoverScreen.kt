package com.marvisociety.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.marvisociety.app.data.CollaborationModel
import com.marvisociety.app.data.Offer
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.PrimaryActionButton
import com.marvisociety.app.ui.components.SecondaryActionButton
import com.marvisociety.app.ui.components.StatusPill
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.theme.MarviGradient
import com.marvisociety.app.ui.viewmodel.AppViewModel
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import java.io.File

private const val ISTANBUL_LAT = 41.0082
private const val ISTANBUL_LNG = 28.9784

@Composable
fun MapDiscoverScreen(
    viewModel: AppViewModel,
    onOpenOffer: (Offer) -> Unit
) {
    val context = LocalContext.current
    var selectedOffer by remember { mutableStateOf<Offer?>(null) }

    val mappableOffers = remember(viewModel.offers) {
        viewModel.offers.filter { it.latitude != null && it.longitude != null }
    }
    val nearbyOffers = mappableOffers.take(8)

    val mapView = remember {
        Configuration.getInstance().apply {
            userAgentValue = context.packageName
            osmdroidBasePath = File(context.cacheDir, "osmdroid")
            osmdroidTileCache = File(context.cacheDir, "osmdroid/tiles")
        }
        MapView(context).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(true)
            controller.setZoom(12.0)
            controller.setCenter(GeoPoint(ISTANBUL_LAT, ISTANBUL_LNG))
        }
    }

    DisposableEffect(Unit) {
        mapView.onResume()
        onDispose {
            mapView.onPause()
            mapView.onDetach()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        AndroidView(
            factory = { mapView },
            modifier = Modifier.fillMaxSize(),
            update = { map ->
                map.overlays.clear()
                mappableOffers.forEach { offer ->
                    val lat = offer.latitude ?: return@forEach
                    val lng = offer.longitude ?: return@forEach
                    val marker = Marker(map).apply {
                        position = GeoPoint(lat, lng)
                        title = offer.title
                        subDescription = "${offer.venue} · ${offer.area}"
                        setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                        setOnMarkerClickListener { _, _ ->
                            selectedOffer = offer
                            true
                        }
                    }
                    map.overlays.add(marker)
                }
                map.invalidate()
            }
        )

        MapDiscoverHeader(
            title = viewModel.t(MarviL10n.Key.NEAR_YOU),
            subtitle = "${mappableOffers.size} ${viewModel.t(MarviL10n.Key.EVENTS_SUFFIX)}",
            onLocate = {
                mapView.controller.animateTo(GeoPoint(ISTANBUL_LAT, ISTANBUL_LNG))
                mapView.controller.setZoom(13.0)
            },
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(horizontal = 16.dp, vertical = 10.dp)
        )

        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            val selected = selectedOffer
            if (selected != null) {
                MapOfferSheet(
                    offer = selected,
                    viewModel = viewModel,
                    onOpen = { onOpenOffer(selected) },
                    onAccept = {
                        when (selected.collaborationModel) {
                            CollaborationModel.EVENT, CollaborationModel.GIFT -> onOpenOffer(selected)
                            else -> viewModel.acceptOffer(selected.id)
                        }
                    }
                )
            } else if (nearbyOffers.isNotEmpty()) {
                NearbyOffersStrip(
                    offers = nearbyOffers,
                    viewModel = viewModel,
                    onSelect = { selectedOffer = it }
                )
            }
        }

        if (mappableOffers.isEmpty()) {
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color.White.copy(alpha = 0.92f))
                    .padding(16.dp)
            ) {
                Text(viewModel.t(MarviL10n.Key.NO_MAP_OFFERS), color = MarviColor.InkOnLight)
            }
        }
    }
}

@Composable
private fun MapDiscoverHeader(
    title: String,
    subtitle: String,
    onLocate: () -> Unit,
    modifier: Modifier = Modifier
) {
    val shape = RoundedCornerShape(24.dp)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .shadow(12.dp, shape, clip = false)
            .clip(shape)
            .background(Color.White.copy(alpha = 0.92f))
            .border(1.dp, Color.White.copy(alpha = 0.75f), shape)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title,
                color = MarviColor.InkOnLight,
                fontWeight = FontWeight.Bold,
                style = MaterialTheme.typography.titleMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                subtitle,
                color = MarviColor.Muted,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        Box(
            modifier = Modifier
                .size(40.dp)
                .shadow(8.dp, CircleShape, clip = false)
                .clip(CircleShape)
                .background(MarviGradient.Brand)
                .clickable(onClick = onLocate),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Filled.MyLocation, contentDescription = title, tint = Color.White, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
private fun NearbyOffersStrip(
    offers: List<Offer>,
    viewModel: AppViewModel,
    onSelect: (Offer) -> Unit
) {
    val shape = RoundedCornerShape(22.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Color.White.copy(alpha = 0.9f))
            .border(1.dp, Color.White.copy(alpha = 0.72f), shape)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            viewModel.t(MarviL10n.Key.NEAR_YOU).uppercase(),
            color = MarviColor.Muted,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold
        )
        LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            items(offers, key = { it.id }) { offer ->
                Column(
                    modifier = Modifier
                        .width(180.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(Color.White)
                        .clickable { onSelect(offer) }
                        .padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        viewModel.modelLabel(offer.collaborationModel),
                        color = MarviColor.Rose,
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        offer.title,
                        color = MarviColor.InkOnLight,
                        fontWeight = FontWeight.Bold,
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        "${offer.venue} · ${offer.area}",
                        color = MarviColor.Graphite,
                        style = MaterialTheme.typography.bodySmall,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    if (offer.collaborationModel == CollaborationModel.INSTANT) {
                        Text(
                            viewModel.t(MarviL10n.Key.NOW),
                            color = MarviColor.InkOnLight,
                            fontWeight = FontWeight.Bold,
                            style = MaterialTheme.typography.labelSmall,
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(MarviColor.Gold)
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun MapOfferSheet(
    offer: Offer,
    viewModel: AppViewModel,
    onOpen: () -> Unit,
    onAccept: () -> Unit
) {
    val accepted = offer.id in viewModel.acceptedOfferIds
    val shape = RoundedCornerShape(24.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Color.White.copy(alpha = 0.92f))
            .border(1.dp, Color.White.copy(alpha = 0.75f), shape)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            offer.title,
            color = MarviColor.InkOnLight,
            fontWeight = FontWeight.Bold,
            style = MaterialTheme.typography.titleMedium,
            maxLines = 2
        )
        Text(
            "${offer.venue} · ${offer.area}",
            color = MarviColor.Graphite,
            style = MaterialTheme.typography.bodyMedium
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            StatusPill(viewModel.modelLabel(offer.collaborationModel), MarviColor.Gold)
            if (offer.valueLabel.isNotBlank()) StatusPill(offer.valueLabel, MarviColor.Aubergine)
            if (offer.collaborationModel == CollaborationModel.INSTANT) {
                StatusPill(viewModel.t(MarviL10n.Key.NOW), MarviColor.Gold)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(modifier = Modifier.weight(1f)) {
                SecondaryActionButton(
                    title = viewModel.t(MarviL10n.Key.DETAILS),
                    onClick = onOpen
                )
            }
            if (!accepted) {
                Box(modifier = Modifier.weight(1f)) {
                    PrimaryActionButton(
                        title = if (offer.collaborationModel == CollaborationModel.INSTANT) {
                            viewModel.t(MarviL10n.Key.USE_NOW)
                        } else {
                            viewModel.t(MarviL10n.Key.ACCEPT_INVITATION)
                        },
                        onClick = onAccept,
                        enabled = viewModel.canAcceptOffers
                    )
                }
            }
        }
        if (!accepted) {
            viewModel.acceptBlockedReason?.takeIf { !viewModel.canAcceptOffers }?.let { reason ->
                Text(reason, color = MarviColor.Gold, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}
