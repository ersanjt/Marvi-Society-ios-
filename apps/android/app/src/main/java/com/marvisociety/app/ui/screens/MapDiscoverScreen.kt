package com.marvisociety.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.marvisociety.app.data.Offer
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.PrimaryActionButton
import com.marvisociety.app.ui.components.SecondaryActionButton
import com.marvisociety.app.ui.components.StatusPill
import com.marvisociety.app.ui.theme.MarviColor
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

        Row(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(16.dp)
                .background(MarviColor.Panel.copy(alpha = 0.92f))
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            Column {
                Text(
                    viewModel.t(MarviL10n.Key.NEAR_YOU),
                    color = MarviColor.Ink,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    "${mappableOffers.size} ${viewModel.t(MarviL10n.Key.EVENTS_SUFFIX)}",
                    color = MarviColor.Rose,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }

        selectedOffer?.let { offer ->
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                MarviCard {
                    Text(offer.title, color = MarviColor.Ink, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                    Text("${offer.venue} · ${offer.area}", color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 4.dp)) {
                        StatusPill(viewModel.modelLabel(offer.collaborationModel), MarviColor.Gold)
                        if (offer.valueLabel.isNotBlank()) StatusPill(offer.valueLabel, MarviColor.Aubergine)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                        Box(modifier = Modifier.weight(1f)) {
                            PrimaryActionButton(
                                title = viewModel.t(MarviL10n.Key.DETAILS),
                                onClick = { onOpenOffer(offer) }
                            )
                        }
                        Box(modifier = Modifier.weight(1f)) {
                            SecondaryActionButton(
                                title = viewModel.t(MarviL10n.Key.CLOSE),
                                onClick = { selectedOffer = null }
                            )
                        }
                    }
                }
            }
        }

        if (mappableOffers.isEmpty()) {
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .background(MarviColor.Panel.copy(alpha = 0.92f))
                    .padding(16.dp)
            ) {
                Text(viewModel.t(MarviL10n.Key.NO_MAP_OFFERS), color = MarviColor.Muted)
            }
        }
    }
}
