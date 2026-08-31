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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Category
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Place
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Search
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.marvisociety.app.data.BookingStage
import com.marvisociety.app.data.CollaborationModel
import com.marvisociety.app.data.MembershipStatus
import com.marvisociety.app.data.Offer
import com.marvisociety.app.data.OfferCategory
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.OfferImagery
import com.marvisociety.app.ui.components.CalendarDayUi
import com.marvisociety.app.ui.components.CircleIconButton
import com.marvisociety.app.ui.components.EmptyStateView
import com.marvisociety.app.ui.components.HomeHeader
import com.marvisociety.app.ui.components.MarviActionSheet
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.components.MarviTextField
import com.marvisociety.app.ui.components.MetricTile
import com.marvisociety.app.ui.components.OfferImageView
import com.marvisociety.app.ui.components.PrimaryActionButton
import com.marvisociety.app.ui.components.ProgressBar
import com.marvisociety.app.ui.components.SegmentedTabs
import com.marvisociety.app.ui.components.StatusPill
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.theme.MarviGradient
import com.marvisociety.app.ui.viewmodel.AppViewModel
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

@Composable
fun DiscoverScreen(
    viewModel: AppViewModel,
    onOfferClick: (Offer) -> Unit,
    onOpenProfile: () -> Unit = {},
    onOpenInbox: () -> Unit = {}
) {
    var filter by remember { mutableStateOf(DiscoverFilter.ALL) }
    var categoryFilter by remember { mutableStateOf<OfferCategory?>(null) }
    var modelFilter by remember { mutableStateOf<CollaborationModel?>(null) }
    var mapMode by remember { mutableStateOf(false) }
    var selectedWhen by remember { mutableStateOf<String?>(null) }
    var selectedWhere by remember { mutableStateOf<String?>(null) }
    var selectedEventType by remember { mutableStateOf<String?>(null) }
    var selectedCalendarDay by remember { mutableStateOf<Int?>(null) }
    var searchText by remember { mutableStateOf("") }
    var sortMode by remember { mutableStateOf(DiscoverSort.NEWEST) }
    var showSort by remember { mutableStateOf(false) }

    var showSearch by remember { mutableStateOf(false) }

    val city = viewModel.profile.city.ifBlank { viewModel.t(MarviL10n.Key.YOUR_CITY) }
    val locale = if (viewModel.preferredLanguage.name == "TURKISH") Locale("tr", "TR") else Locale.US
    val calendarDays = remember(locale) { buildCalendarDays(locale) }
    val whenOptions = listOf(
        viewModel.t(MarviL10n.Key.TONIGHT),
        viewModel.t(MarviL10n.Key.THIS_WEEK),
        viewModel.t(MarviL10n.Key.WEEKEND)
    )
    val whereOptions = remember(viewModel.offers) {
        val areas = viewModel.offers.map { it.area }.filter { it.isNotBlank() }.distinct().sorted()
        areas.ifEmpty { listOf("Karaköy", "Nişantaşı", "Kadıköy") }
    }
    val eventTypes = OfferCategory.entries.map { viewModel.categoryLabel(it) }

    fun matchesWhen(offer: Offer, selection: String?): Boolean {
        if (selection == null) return true
        val label = offer.dateLabel.lowercase()
        return when (selection) {
            viewModel.t(MarviL10n.Key.TONIGHT) ->
                listOf("tonight", "today", "bu gece", "bugün").any { label.contains(it) }
            viewModel.t(MarviL10n.Key.THIS_WEEK) -> true
            viewModel.t(MarviL10n.Key.WEEKEND) ->
                listOf("sat", "sun", "weekend", "cum", "paz").any { label.contains(it) }
            else -> true
        }
    }

    fun matchesDay(offer: Offer, dayIndex: Int?): Boolean {
        if (dayIndex == null) return true
        val day = calendarDays.getOrNull(dayIndex) ?: return true
        val label = offer.dateLabel.lowercase()
        return label.contains(day.label.lowercase()) || label.contains(day.weekday.lowercase())
    }

    val filtered = viewModel.offers.filter { offer ->
        val matchesCategory = categoryFilter == null || offer.category == categoryFilter
        val matchesModel = modelFilter == null || offer.collaborationModel == modelFilter
        val matchesSearch = searchText.isBlank() ||
            offer.title.contains(searchText, true) ||
            offer.venue.contains(searchText, true) ||
            offer.area.contains(searchText, true)
        val matchesWhere = selectedWhere == null || offer.area.contains(selectedWhere!!, true)
        val matchesType = selectedEventType == null ||
            viewModel.categoryLabel(offer.category).equals(selectedEventType, ignoreCase = true)
        val matchesFilter = when (filter) {
            DiscoverFilter.ALL -> true
            DiscoverFilter.SAVED -> offer.id in viewModel.savedOfferIds
            DiscoverFilter.URGENT -> offer.remaining <= 4
        }
        matchesCategory && matchesModel && matchesSearch && matchesWhere && matchesType &&
            matchesWhen(offer, selectedWhen) && matchesDay(offer, selectedCalendarDay) && matchesFilter
    }.let { list ->
        when (sortMode) {
            DiscoverSort.NEWEST -> list
            DiscoverSort.SLOTS -> list.sortedBy { it.remaining }
            DiscoverSort.MATCH -> list.sortedByDescending { it.remaining }
        }
    }

    val hasActiveFilters = categoryFilter != null || modelFilter != null || filter != DiscoverFilter.ALL ||
        selectedWhen != null || selectedWhere != null || selectedEventType != null ||
        selectedCalendarDay != null || searchText.isNotBlank()

    fun clearFilters() {
        categoryFilter = null
        modelFilter = null
        filter = DiscoverFilter.ALL
        selectedWhen = null
        selectedWhere = null
        selectedEventType = null
        selectedCalendarDay = null
        searchText = ""
    }

    val featured = filtered.filter { it.isFeaturedNow() }
    val listOffers = filtered.filter { !it.isFeaturedNow() }

    if (mapMode) {
        MarviScreen {
            Box(modifier = Modifier.fillMaxSize()) {
                MapDiscoverScreen(viewModel, onOfferClick)
                Box(modifier = Modifier.align(Alignment.TopCenter).padding(16.dp).fillMaxWidth()) {
                    SegmentedTabs(
                        tabs = listOf(viewModel.t(MarviL10n.Key.LIST_VIEW), viewModel.t(MarviL10n.Key.MAP_VIEW)),
                        selectedIndex = 1,
                        onSelect = { if (it == 0) mapMode = false }
                    )
                }
            }
        }
        return
    }

    MarviScreen {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp)
        ) {
            item {
                Spacer(Modifier.height(8.dp))
                MarviWordmark()
                Spacer(Modifier.height(14.dp))
                HomeHeader(
                    greeting = viewModel.profile.name.split(" ").firstOrNull()?.ifBlank { null }
                        ?: viewModel.t(MarviL10n.Key.MEMBER_LABEL),
                    subtitle = viewModel.t(MarviL10n.Key.GREETING_SUB),
                    avatarUrl = viewModel.profile.avatarUrl.takeIf { it.isNotBlank() },
                    avatarLetter = viewModel.profile.name.ifBlank { "M" },
                    hiPrefix = greetingPrefix(viewModel),
                    unreadCount = viewModel.unreadInboxCount,
                    onProfile = onOpenProfile,
                    onNotifications = onOpenInbox
                )
            }

            if (viewModel.profile.status != MembershipStatus.APPROVED || viewModel.needsSocialProfileCompletion) {
                item {
                    ProfileCompletionPromo(viewModel, onOpenProfile)
                }
            }

            item {
                HomeStatsGrid(viewModel)
            }

            item {
                RecentRequestsCard(viewModel)
            }

            item {
                Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            viewModel.t(MarviL10n.Key.BROWSE_CAMPAIGNS),
                            color = MarviColor.Ink,
                            fontWeight = FontWeight.Bold,
                            style = MaterialTheme.typography.headlineSmall
                        )
                        Text(
                            viewModel.t(MarviL10n.Key.BROWSE_CAMPAIGNS_SUB),
                            color = MarviColor.Muted,
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                    CircleIconButton(
                        Icons.Outlined.Search,
                        onClick = { showSearch = true },
                        tint = MarviColor.Rose,
                        containerColor = MarviColor.Rose.copy(alpha = 0.16f)
                    )
                }
            }

            item {
                CategoryGrid(
                    viewModel = viewModel,
                    selected = categoryFilter,
                    onSelect = { categoryFilter = it }
                )
            }

            item {
                SegmentedTabs(
                    tabs = listOf(viewModel.t(MarviL10n.Key.LIST_VIEW), viewModel.t(MarviL10n.Key.MAP_VIEW)),
                    selectedIndex = if (mapMode) 1 else 0,
                    onSelect = { mapMode = it == 1 }
                )
            }

            if (featured.isNotEmpty()) {
                item {
                    Text(
                        viewModel.t(MarviL10n.Key.FEATURED_EVENTS),
                        color = MarviColor.Ink,
                        fontWeight = FontWeight.Bold,
                        style = MaterialTheme.typography.titleMedium
                    )
                }
                items(featured, key = { "featured-${it.id}" }) { offer ->
                    CampaignOfferCard(
                        offer = offer,
                        viewModel = viewModel,
                        saved = offer.id in viewModel.savedOfferIds,
                        accepted = offer.id in viewModel.acceptedOfferIds,
                        onOpen = { onOfferClick(offer) },
                        onToggleSaved = { viewModel.toggleSaved(offer.id) }
                    )
                }
            }

            if (listOffers.isEmpty() && featured.isEmpty()) {
                item {
                    MarviCard {
                        EmptyStateView(
                            title = if (hasActiveFilters && viewModel.offers.isNotEmpty()) {
                                viewModel.t(MarviL10n.Key.FILTERS_HID_RESULTS)
                            } else {
                                viewModel.t(MarviL10n.Key.NO_EVENTS_TITLE)
                            },
                            subtitle = if (hasActiveFilters && viewModel.offers.isNotEmpty()) {
                                viewModel.t(MarviL10n.Key.CLEAR_FILTERS)
                            } else {
                                viewModel.t(MarviL10n.Key.NO_EVENTS_SUB)
                            },
                            actionTitle = if (hasActiveFilters && viewModel.offers.isNotEmpty()) {
                                viewModel.t(MarviL10n.Key.CLEAR_FILTERS)
                            } else {
                                viewModel.t(MarviL10n.Key.REFRESH)
                            },
                            onAction = {
                                if (hasActiveFilters && viewModel.offers.isNotEmpty()) clearFilters()
                                else viewModel.refreshFromServer()
                            }
                        )
                    }
                }
            } else {
                items(listOffers, key = { it.id }) { offer ->
                    val overlay = offer.collaborationModel == CollaborationModel.GIFT ||
                        offer.collaborationModel == CollaborationModel.INSTANT
                    if (overlay) {
                        OverlayOfferCard(
                            offer = offer,
                            viewModel = viewModel,
                            accepted = offer.id in viewModel.acceptedOfferIds,
                            onOpen = { onOfferClick(offer) }
                        )
                    } else {
                        CampaignOfferCard(
                            offer = offer,
                            viewModel = viewModel,
                            saved = offer.id in viewModel.savedOfferIds,
                            accepted = offer.id in viewModel.acceptedOfferIds,
                            onOpen = { onOfferClick(offer) },
                            onToggleSaved = { viewModel.toggleSaved(offer.id) }
                        )
                    }
                }
            }

            item { Spacer(Modifier.height(24.dp)) }
        }
    }

    if (showSort) {
        MarviActionSheet(
            title = viewModel.t(MarviL10n.Key.SORT_EVENTS),
            onDismiss = { showSort = false },
            dismissTitle = viewModel.t(MarviL10n.Key.CLOSE)
        ) {
            listOf(
                DiscoverSort.NEWEST to MarviL10n.Key.SORT_NEWEST,
                DiscoverSort.SLOTS to MarviL10n.Key.SORT_FEW_SLOTS,
                DiscoverSort.MATCH to MarviL10n.Key.SORT_BEST_MATCH
            ).forEach { (mode, key) ->
                PrimaryActionButton(
                    title = viewModel.t(key),
                    onClick = { sortMode = mode; showSort = false }
                )
            }
        }
    }

    if (showSearch) {
        MarviActionSheet(
            title = viewModel.t(MarviL10n.Key.SEARCH_OFFERS),
            onDismiss = { showSearch = false },
            confirmTitle = viewModel.t(MarviL10n.Key.OK),
            onConfirm = { showSearch = false },
            dismissTitle = viewModel.t(MarviL10n.Key.CLOSE)
        ) {
            MarviTextField(
                value = searchText,
                onValueChange = { searchText = it },
                placeholder = viewModel.t(MarviL10n.Key.SEARCH_VENUE_PROMPT)
            )
            PrimaryActionButton(
                title = viewModel.t(MarviL10n.Key.SORT_BY),
                onClick = { showSort = true; showSearch = false }
            )
        }
    }
}

@Composable
private fun CampaignOfferCard(
    offer: Offer,
    viewModel: AppViewModel,
    saved: Boolean,
    accepted: Boolean,
    onOpen: () -> Unit,
    onToggleSaved: () -> Unit
) {
    val shape = RoundedCornerShape(20.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(MarviColor.Panel)
            .border(1.dp, MarviColor.Border, shape)
            .clickable(onClick = onOpen)
    ) {
        Box {
            OfferImageView(
                url = OfferImagery.imageUrl(offer),
                contentDescription = offer.title,
                modifier = Modifier.fillMaxWidth(),
                height = 176.dp,
                cornerRadius = 0.dp
            )
            Text(
                viewModel.categoryLabel(offer.category).uppercase(),
                color = Color.White,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(12.dp)
                    .clip(RoundedCornerShape(50))
                    .background(Color.Black.copy(alpha = 0.45f))
                    .padding(horizontal = 10.dp, vertical = 5.dp)
            )
            Box(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(12.dp)
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(MarviColor.Panel.copy(alpha = 0.88f))
                    .clickable(onClick = onToggleSaved),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    if (saved) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                    contentDescription = null,
                    tint = if (saved) MarviColor.Rose else MarviColor.Ink,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(MarviGradient.Brand),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        offer.venue.take(1).uppercase(),
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                }
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        offer.title,
                        color = MarviColor.Ink,
                        fontWeight = FontWeight.Bold,
                        style = MaterialTheme.typography.titleMedium,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        "${offer.venue} · ${offer.area}",
                        color = MarviColor.Muted,
                        style = MaterialTheme.typography.bodySmall,
                        maxLines = 1
                    )
                }
                if (offer.valueLabel.isNotBlank()) {
                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            offer.valueLabel,
                            fontWeight = FontWeight.Bold,
                            style = MaterialTheme.typography.titleMedium.copy(brush = MarviGradient.Brand)
                        )
                        Text(
                            viewModel.t(MarviL10n.Key.VALUE_CAPTION),
                            color = MarviColor.Muted,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                StatusPill(viewModel.modelLabel(offer.collaborationModel), MarviColor.Aubergine)
                offer.deliverables.take(2).forEach { deliverable ->
                    StatusPill(deliverable, MarviColor.Aubergine)
                }
                if (accepted) StatusPill(viewModel.t(MarviL10n.Key.CONFIRMED_STATUS), MarviColor.Emerald)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MetaChip(Icons.Outlined.Person, viewModel.tf(MarviL10n.Key.SLOTS_COUNT, offer.remaining))
                MetaChip(Icons.Outlined.Category, viewModel.categoryLabel(offer.category))
                MetaChip(Icons.Outlined.CalendarMonth, viewModel.localizeServerText(offer.dateLabel))
            }
            PrimaryActionButton(
                title = if (accepted) {
                    viewModel.t(MarviL10n.Key.VIEW_EVENT)
                } else {
                    viewModel.t(MarviL10n.Key.APPLY_NOW)
                },
                onClick = onOpen,
                icon = Icons.AutoMirrored.Filled.Send
            )
        }
    }
}

@Composable
private fun ProfileCompletionPromo(viewModel: AppViewModel, onOpenProfile: () -> Unit) {
    val pct = profileCompletionPercent(viewModel)
    val shape = RoundedCornerShape(18.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(MarviColor.Aubergine.copy(alpha = 0.12f))
            .border(1.dp, MarviColor.Aubergine.copy(alpha = 0.35f), shape)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(MarviColor.Rose.copy(alpha = 0.18f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Outlined.Description, contentDescription = null, tint = MarviColor.Rose, modifier = Modifier.size(18.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    viewModel.t(MarviL10n.Key.PROFILE_COMPLETION_TITLE),
                    color = MarviColor.Rose,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.titleMedium
                )
                Text(viewModel.t(MarviL10n.Key.GET_LISTED_SUB), color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
            }
        }
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(
                viewModel.t(MarviL10n.Key.PROFILE_COMPLETION_LABEL),
                color = MarviColor.Graphite,
                style = MaterialTheme.typography.labelMedium
            )
            Text(
                "$pct%",
                color = MarviColor.Rose,
                fontWeight = FontWeight.Bold,
                style = MaterialTheme.typography.labelMedium
            )
        }
        ProgressBar(pct / 100f)
        PrimaryActionButton(
            title = viewModel.t(MarviL10n.Key.COMPLETE_PROFILE_CTA),
            onClick = onOpenProfile,
            icon = Icons.AutoMirrored.Filled.ArrowForward
        )
    }
}

@Composable
private fun MarviWordmark() {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center
    ) {
        Text(
            "Marvi",
            color = MarviColor.Ink,
            fontWeight = FontWeight.Bold,
            style = MaterialTheme.typography.titleLarge
        )
        Text(
            " Society",
            fontWeight = FontWeight.Bold,
            style = MaterialTheme.typography.titleLarge.copy(
                brush = MarviGradient.Brand
            )
        )
    }
}

private fun greetingPrefix(viewModel: AppViewModel): String {
    val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
    val key = when {
        hour < 12 -> MarviL10n.Key.GOOD_MORNING
        hour < 18 -> MarviL10n.Key.GOOD_AFTERNOON
        else -> MarviL10n.Key.GOOD_EVENING
    }
    return viewModel.t(key)
}

private fun profileCompletionPercent(viewModel: AppViewModel): Int {
    val profile = viewModel.profile
    var score = 0
    if (profile.name.isNotBlank()) score += 20
    if (profile.handle.isNotBlank() || profile.tiktokHandle.isNotBlank()) score += 20
    if (profile.bio.isNotBlank()) score += 15
    if (profile.city.isNotBlank()) score += 10
    if (profile.avatarUrl.isNotBlank()) score += 15
    if (profile.coverUrl.isNotBlank()) score += 10
    if (profile.status == MembershipStatus.APPROVED) score += 10
    return score.coerceIn(5, 100)
}

@Composable
private fun OverlayOfferCard(
    offer: Offer,
    viewModel: AppViewModel,
    accepted: Boolean,
    onOpen: () -> Unit
) {
    val shape = RoundedCornerShape(20.dp)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(280.dp)
            .clip(shape)
            .clickable(onClick = onOpen)
    ) {
        OfferImageView(
            url = OfferImagery.imageUrl(offer),
            contentDescription = offer.title,
            modifier = Modifier.fillMaxSize(),
            height = 280.dp,
            cornerRadius = 0.dp
        )
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MarviGradient.HeroOverlay)
        )
        Text(
            viewModel.categoryLabel(offer.category).uppercase(),
            color = Color.White,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(12.dp)
                .clip(RoundedCornerShape(50))
                .background(Color.Black.copy(alpha = 0.45f))
                .padding(horizontal = 10.dp, vertical = 5.dp)
        )
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                offer.title,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                style = MaterialTheme.typography.titleLarge,
                maxLines = 2
            )
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(
                    modifier = Modifier
                        .size(22.dp)
                        .clip(CircleShape)
                        .background(MarviGradient.Brand),
                    contentAlignment = Alignment.Center
                ) {
                    Text(offer.venue.take(1).uppercase(), color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                }
                Text(offer.venue, color = Color.White.copy(alpha = 0.9f), style = MaterialTheme.typography.bodySmall)
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Icon(Icons.Outlined.Place, contentDescription = null, tint = Color.White.copy(alpha = 0.8f), modifier = Modifier.size(14.dp))
                Text(
                    listOf(offer.area, "Turkey").filter { it.isNotBlank() }.joinToString(", "),
                    color = Color.White.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier.weight(1f),
                    maxLines = 1
                )
                PrimaryActionButton(
                    title = if (accepted) viewModel.t(MarviL10n.Key.VIEW_EVENT) else viewModel.t(MarviL10n.Key.APPLY_NOW),
                    onClick = onOpen,
                    fillMaxWidth = false
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Outlined.CalendarMonth, contentDescription = null, tint = Color.White.copy(alpha = 0.8f), modifier = Modifier.size(14.dp))
                Text(
                    viewModel.localizeServerText(offer.dateLabel),
                    color = Color.White.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.labelMedium
                )
            }
        }
    }
}

@Composable
private fun HomeStatsGrid(viewModel: AppViewModel) {
    val pending = viewModel.pendingCollaborationRequests.count { it.isPendingCreator } +
        viewModel.bookings.count { it.stage == BookingStage.INVITED }
    val tiles = listOf(
        Triple(viewModel.bookings.size.toString(), viewModel.t(MarviL10n.Key.STAT_EVENTS), MarviColor.Blue to Icons.Outlined.CalendarMonth),
        Triple(viewModel.profile.proofRate.ifBlank { "—" }, viewModel.t(MarviL10n.Key.STAT_DELIVERY), MarviColor.Aubergine to Icons.Outlined.ChatBubbleOutline),
        Triple(pending.toString(), viewModel.t(MarviL10n.Key.STAT_PENDING), MarviColor.Gold to Icons.Outlined.Schedule),
        Triple(viewModel.savedOfferIds.size.toString(), viewModel.t(MarviL10n.Key.STAT_SAVED), MarviColor.Tomato to Icons.Outlined.FavoriteBorder),
        Triple(viewModel.unreadInboxCount.toString(), viewModel.t(MarviL10n.Key.STAT_INBOX), MarviColor.Aubergine to Icons.Outlined.Notifications),
        Triple(viewModel.profile.score.toString(), viewModel.t(MarviL10n.Key.STAT_SCORE), MarviColor.Emerald to Icons.Outlined.Person)
    )
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        tiles.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                row.forEach { (value, label, style) ->
                    Box(modifier = Modifier.weight(1f)) {
                        MetricTile(value = value, label = label, tint = style.first, icon = style.second)
                    }
                }
            }
        }
    }
}

@Composable
private fun RecentRequestsCard(viewModel: AppViewModel) {
    val pending = viewModel.pendingCollaborationRequests.filter { it.isPendingCreator }
    MarviCard {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Text(
                viewModel.t(MarviL10n.Key.RECENT_REQUESTS),
                color = MarviColor.Ink,
                fontWeight = FontWeight.Bold,
                style = MaterialTheme.typography.titleMedium
            )
            Text(
                pending.size.toString(),
                color = MarviColor.Muted,
                style = MaterialTheme.typography.labelMedium
            )
        }
        if (pending.isEmpty()) {
            EmptyStateView(
                title = viewModel.t(MarviL10n.Key.NO_PENDING_REQUESTS),
                subtitle = viewModel.t(MarviL10n.Key.NO_BOOKINGS_SUB),
                icon = Icons.Outlined.CalendarMonth
            )
        } else {
            pending.take(3).forEach { request ->
                Text(request.offerTitle.ifBlank { request.venueName }, color = MarviColor.Ink, fontWeight = FontWeight.SemiBold, maxLines = 1)
                Text(request.venueName, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall, maxLines = 1)
            }
        }
    }
}

@Composable
private fun CategoryGrid(
    viewModel: AppViewModel,
    selected: OfferCategory?,
    onSelect: (OfferCategory?) -> Unit
) {
    val entries = listOf<OfferCategory?>(null) + OfferCategory.entries
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        entries.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                row.forEach { category ->
                    val active = selected == category
                    val label = if (category == null) {
                        viewModel.t(MarviL10n.Key.FILTER_ALL)
                    } else {
                        viewModel.categoryLabel(category)
                    }
                    Text(
                        label,
                        color = if (active) MarviColor.Rose else MarviColor.Ink,
                        fontWeight = FontWeight.SemiBold,
                        style = MaterialTheme.typography.labelMedium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(14.dp))
                            .then(
                                if (active) Modifier
                                    .background(MarviColor.Rose.copy(alpha = 0.16f))
                                    .border(1.dp, MarviColor.Rose.copy(alpha = 0.45f), RoundedCornerShape(14.dp))
                                else Modifier
                                    .background(MarviColor.Panel)
                                    .border(1.dp, MarviColor.Border, RoundedCornerShape(14.dp))
                            )
                            .clickable { onSelect(if (active && category != null) null else category) }
                            .padding(horizontal = 10.dp, vertical = 12.dp)
                    )
                }
                repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun MetaChip(icon: ImageVector, text: String) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .border(1.dp, MarviColor.Border, RoundedCornerShape(50))
            .padding(horizontal = 8.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(icon, contentDescription = null, tint = MarviColor.Muted, modifier = Modifier.size(12.dp))
        Text(
            text,
            color = MarviColor.Graphite,
            style = MaterialTheme.typography.labelSmall,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

private enum class DiscoverFilter { ALL, SAVED, URGENT }
private enum class DiscoverSort { NEWEST, SLOTS, MATCH }

private fun buildCalendarDays(locale: Locale): List<CalendarDayUi> {
    val calendar = Calendar.getInstance()
    val weekdayFormat = SimpleDateFormat("EEE", locale)
    val dayFormat = SimpleDateFormat("d", locale)
    return (0 until 7).map { offset ->
        val date = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, offset) }.time
        CalendarDayUi(
            id = offset,
            weekday = weekdayFormat.format(date),
            label = dayFormat.format(date)
        )
    }
}
