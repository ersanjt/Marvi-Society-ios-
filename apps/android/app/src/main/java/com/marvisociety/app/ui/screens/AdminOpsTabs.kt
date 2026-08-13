package com.marvisociety.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.marvisociety.app.data.ActivityEventItem
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.EmptyStateView
import com.marvisociety.app.ui.components.FilterChipPill
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviTextField
import com.marvisociety.app.ui.components.PrimaryActionButton
import com.marvisociety.app.ui.components.SectionTitle
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

private const val ISTANBUL_LAT = 41.015
private const val ISTANBUL_LNG = 28.979

@Composable
fun AdminMapPanel(viewModel: AppViewModel) {
    val context = LocalContext.current
    val liveUsers = viewModel.adminUsers.filter { it.hasLiveLocation }
    val liveOffers = viewModel.offers.filter { it.latitude != null && it.longitude != null }

    val mapView = remember {
        Configuration.getInstance().apply {
            userAgentValue = context.packageName
            osmdroidBasePath = File(context.cacheDir, "osmdroid")
            osmdroidTileCache = File(context.cacheDir, "osmdroid/tiles")
        }
        MapView(context).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(true)
            controller.setZoom(11.5)
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

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        MarviCard {
            Text(viewModel.t(MarviL10n.Key.LIVE_MAP), color = MarviColor.Ink, fontWeight = FontWeight.Bold)
            Text(
                viewModel.t(MarviL10n.Key.LIVE_MAP_LEGEND),
                color = MarviColor.Muted,
                style = MaterialTheme.typography.bodySmall
            )
            Text(
                viewModel.tf(MarviL10n.Key.LIVE_MAP_STATS, liveUsers.size, liveOffers.size),
                color = MarviColor.Emerald,
                fontWeight = FontWeight.SemiBold,
                style = MaterialTheme.typography.bodySmall
            )
        }
        AndroidView(
            factory = { mapView },
            modifier = Modifier
                .fillMaxWidth()
                .height(420.dp)
                .clip(RoundedCornerShape(16.dp)),
            update = { map ->
                map.overlays.clear()
                liveUsers.forEach { user ->
                    val lat = user.lastLat ?: return@forEach
                    val lng = user.lastLng ?: return@forEach
                    map.overlays.add(
                        Marker(map).apply {
                            position = GeoPoint(lat, lng)
                            title = user.displayName
                            setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                        }
                    )
                }
                liveOffers.forEach { offer ->
                    val lat = offer.latitude ?: return@forEach
                    val lng = offer.longitude ?: return@forEach
                    map.overlays.add(
                        Marker(map).apply {
                            position = GeoPoint(lat, lng)
                            title = offer.venue
                            snippet = offer.title
                            setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                        }
                    )
                }
                map.invalidate()
            }
        )
    }
}

@Composable
fun AdminBroadcastPanel(viewModel: AppViewModel) {
    var title by remember { mutableStateOf("") }
    var body by remember { mutableStateOf("") }
    var radiusKm by remember { mutableFloatStateOf(3f) }
    var feedback by remember { mutableStateOf("") }
    var sending by remember { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionTitle(
            text = viewModel.t(MarviL10n.Key.GEO_BROADCAST),
            subtitle = viewModel.t(MarviL10n.Key.GEO_BROADCAST_SUB)
        )
        MarviCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    viewModel.t(MarviL10n.Key.RADIUS_LABEL),
                    color = MarviColor.Muted,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.labelMedium
                )
                androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))
                Text("${radiusKm.toInt()} km", color = MarviColor.Ink, fontWeight = FontWeight.Bold)
            }
            Slider(
                value = radiusKm,
                onValueChange = { radiusKm = it },
                valueRange = 1f..25f,
                steps = 23,
                colors = SliderDefaults.colors(
                    thumbColor = MarviColor.Rose,
                    activeTrackColor = MarviColor.Rose
                )
            )
            Text(
                viewModel.t(MarviL10n.Key.BROADCAST_CENTER_DEFAULT),
                color = MarviColor.Muted,
                style = MaterialTheme.typography.bodySmall
            )
            MarviTextField(title, { title = it }, viewModel.t(MarviL10n.Key.NOTIFICATION_TITLE_PH))
            MarviTextField(body, { body = it }, viewModel.t(MarviL10n.Key.NOTIFICATION_BODY_PH), singleLine = false)
            PrimaryActionButton(
                title = viewModel.t(MarviL10n.Key.SEND_TO_AREA),
                enabled = title.isNotBlank() && body.isNotBlank() && !sending,
                onClick = {
                    sending = true
                    viewModel.adminBroadcastInRadius(
                        ISTANBUL_LAT,
                        ISTANBUL_LNG,
                        radiusKm.toDouble(),
                        title.trim(),
                        body.trim()
                    ) {
                        feedback = it
                        sending = false
                    }
                }
            )
            if (feedback.isNotBlank()) {
                Text(feedback, color = MarviColor.Emerald, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

private enum class ActivityFilter {
    ALL, BOOKINGS, CAMPAIGNS, ADMIN, MESSAGES, SOCIAL;

    fun category(): ActivityEventItem.Category? = when (this) {
        ALL -> null
        BOOKINGS -> ActivityEventItem.Category.BOOKINGS
        CAMPAIGNS -> ActivityEventItem.Category.CAMPAIGNS
        ADMIN -> ActivityEventItem.Category.ADMIN
        MESSAGES -> ActivityEventItem.Category.MESSAGES
        SOCIAL -> ActivityEventItem.Category.SOCIAL
    }

    fun labelKey(): MarviL10n.Key = when (this) {
        ALL -> MarviL10n.Key.ACTIVITY_FILTER_ALL
        BOOKINGS -> MarviL10n.Key.ACTIVITY_FILTER_BOOKINGS
        CAMPAIGNS -> MarviL10n.Key.ACTIVITY_FILTER_CAMPAIGNS
        ADMIN -> MarviL10n.Key.ACTIVITY_FILTER_ADMIN
        MESSAGES -> MarviL10n.Key.ACTIVITY_FILTER_MESSAGES
        SOCIAL -> MarviL10n.Key.ACTIVITY_FILTER_SOCIAL
    }
}

@Composable
fun AdminActivityPanel(viewModel: AppViewModel) {
    var filter by remember { mutableStateOf(ActivityFilter.ALL) }
    var search by remember { mutableStateOf("") }

    LaunchedEffect(Unit) { viewModel.loadAdminActivity() }

    val query = search.trim().lowercase()
    val filtered = viewModel.adminActivity.filter { event ->
        val cat = filter.category()
        if (cat != null && event.category != cat) return@filter false
        if (query.isEmpty()) return@filter true
        val haystack = listOf(
            event.action,
            event.actorLabel,
            event.subjectType,
            event.meta("title").orEmpty(),
            event.meta("reason").orEmpty(),
            event.meta("from").orEmpty(),
            event.meta("to").orEmpty()
        ).joinToString(" ").lowercase()
        haystack.contains(query)
    }

    fun countFor(item: ActivityFilter): Int {
        val cat = item.category()
        return if (cat == null) viewModel.adminActivity.size
        else viewModel.adminActivity.count { it.category == cat }
    }

    val grouped = remember(filtered) {
        val cal = Calendar.getInstance()
        filtered.groupBy { event ->
            cal.timeInMillis = event.createdAtMillis
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            cal.timeInMillis
        }.toSortedMap(compareByDescending { it })
    }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionTitle(
            text = viewModel.t(MarviL10n.Key.ADMIN_TAB_ACTIVITY),
            subtitle = viewModel.t(MarviL10n.Key.ADMIN_ACTIVITY_SUB)
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            Box(Modifier.weight(1f)) {
                ActivityMetric(viewModel.t(MarviL10n.Key.ACTIVITY_FILTER_BOOKINGS), countFor(ActivityFilter.BOOKINGS), MarviColor.Emerald)
            }
            Box(Modifier.weight(1f)) {
                ActivityMetric(viewModel.t(MarviL10n.Key.ACTIVITY_FILTER_CAMPAIGNS), countFor(ActivityFilter.CAMPAIGNS), MarviColor.Aubergine)
            }
            Box(Modifier.weight(1f)) {
                ActivityMetric(viewModel.t(MarviL10n.Key.ACTIVITY_FILTER_ADMIN), countFor(ActivityFilter.ADMIN), MarviColor.Tomato)
            }
        }
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(ActivityFilter.entries) { item ->
                FilterChipPill(
                    label = "${viewModel.t(item.labelKey())} (${countFor(item)})",
                    selected = filter == item,
                    onClick = { filter = item }
                )
            }
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(MarviColor.Panel)
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(Icons.Filled.Search, null, tint = MarviColor.Muted, modifier = Modifier.size(18.dp))
            Box(modifier = Modifier.weight(1f)) {
                MarviTextField(search, { search = it }, viewModel.t(MarviL10n.Key.ADMIN_ACTIVITY_SEARCH))
            }
        }

        when {
            viewModel.isLoadingAdminActivity && viewModel.adminActivity.isEmpty() -> {
                Text(viewModel.t(MarviL10n.Key.LOADING), color = MarviColor.Muted)
            }
            viewModel.adminActivityError != null && viewModel.adminActivity.isEmpty() -> {
                EmptyStateView(
                    title = viewModel.t(MarviL10n.Key.ADMIN_ACTIVITY_EMPTY),
                    subtitle = viewModel.adminActivityError.orEmpty(),
                    actionTitle = viewModel.t(MarviL10n.Key.RETRY),
                    onAction = viewModel::loadAdminActivity
                )
            }
            filtered.isEmpty() -> {
                EmptyStateView(
                    title = viewModel.t(MarviL10n.Key.ADMIN_ACTIVITY_EMPTY),
                    subtitle = if (search.isBlank()) {
                        viewModel.t(MarviL10n.Key.ADMIN_ACTIVITY_EMPTY_SUB)
                    } else {
                        viewModel.t(MarviL10n.Key.ADMIN_ACTIVITY_NO_RESULTS)
                    },
                    actionTitle = viewModel.t(MarviL10n.Key.REFRESH),
                    onAction = viewModel::loadAdminActivity
                )
            }
            else -> {
                grouped.forEach { (day, events) ->
                    Text(
                        dayLabel(day),
                        color = MarviColor.Muted,
                        fontWeight = FontWeight.Bold,
                        style = MaterialTheme.typography.labelMedium
                    )
                    events.forEach { event ->
                        ActivityRow(event, viewModel)
                    }
                }
            }
        }
    }
}

@Composable
private fun ActivityMetric(title: String, value: Int, tint: Color) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(tint.copy(alpha = 0.12f))
            .padding(vertical = 10.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("$value", color = tint, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleLarge)
        Text(title, color = MarviColor.Muted, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun ActivityRow(event: ActivityEventItem, viewModel: AppViewModel) {
    val tint = when (event.category) {
        ActivityEventItem.Category.BOOKINGS -> MarviColor.Emerald
        ActivityEventItem.Category.CAMPAIGNS -> MarviColor.Aubergine
        ActivityEventItem.Category.ADMIN -> MarviColor.Tomato
        ActivityEventItem.Category.MESSAGES -> MarviColor.Rose
        ActivityEventItem.Category.SOCIAL -> MarviColor.Gold
        else -> MarviColor.Muted
    }
    val title = event.meta("title") ?: event.action.replace('_', ' ')
    val subtitle = listOfNotNull(
        event.actorLabel.takeIf { it.isNotBlank() },
        event.meta("reason"),
        event.subjectType.takeIf { it.isNotBlank() }
    ).joinToString(" · ")
    MarviCard {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(tint.copy(alpha = 0.14f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    if (event.category == ActivityEventItem.Category.SOCIAL) Icons.Filled.Person else Icons.Outlined.AutoAwesome,
                    contentDescription = null,
                    tint = tint,
                    modifier = Modifier.size(18.dp)
                )
            }
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row {
                    Text(
                        title,
                        color = MarviColor.Ink,
                        fontWeight = FontWeight.Bold,
                        style = MaterialTheme.typography.titleSmall,
                        modifier = Modifier.weight(1f)
                    )
                    Text(event.createdLabel, color = MarviColor.Graphite, style = MaterialTheme.typography.labelSmall)
                }
                if (subtitle.isNotBlank()) {
                    Text(subtitle, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                }
                Text(
                    viewModel.t(event.category.labelKey()),
                    color = tint,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(tint.copy(alpha = 0.12f))
                        .padding(horizontal = 8.dp, vertical = 3.dp)
                )
            }
        }
    }
}

private fun ActivityEventItem.Category.labelKey(): MarviL10n.Key = when (this) {
    ActivityEventItem.Category.BOOKINGS -> MarviL10n.Key.ACTIVITY_FILTER_BOOKINGS
    ActivityEventItem.Category.CAMPAIGNS -> MarviL10n.Key.ACTIVITY_FILTER_CAMPAIGNS
    ActivityEventItem.Category.ADMIN -> MarviL10n.Key.ACTIVITY_FILTER_ADMIN
    ActivityEventItem.Category.MESSAGES -> MarviL10n.Key.ACTIVITY_FILTER_MESSAGES
    ActivityEventItem.Category.SOCIAL -> MarviL10n.Key.ACTIVITY_FILTER_SOCIAL
    else -> MarviL10n.Key.ACTIVITY_FILTER_ALL
}

private fun dayLabel(millis: Long): String {
    val fmt = SimpleDateFormat("EEE d MMM", Locale.getDefault())
    return fmt.format(Date(millis)).uppercase(Locale.getDefault())
}
