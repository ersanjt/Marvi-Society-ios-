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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.marvisociety.app.data.CollaborationModel
import com.marvisociety.app.data.MembershipStatus
import com.marvisociety.app.data.Offer
import com.marvisociety.app.data.OfferCategory
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.OfferImagery
import com.marvisociety.app.ui.components.CalendarDayUi
import com.marvisociety.app.ui.components.EmptyStateView
import com.marvisociety.app.ui.components.EventCalendarStrip
import com.marvisociety.app.ui.components.FilterChipPill
import com.marvisociety.app.ui.components.HomeHeader
import com.marvisociety.app.ui.components.MarviActionSheet
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.components.MarviTextField
import com.marvisociety.app.ui.components.MembershipStatusBanner
import com.marvisociety.app.ui.components.OfferImageView
import com.marvisociety.app.ui.components.PrimaryActionButton
import com.marvisociety.app.ui.components.SecondaryActionButton
import com.marvisociety.app.ui.components.SSDiscoverAxisPills
import com.marvisociety.app.ui.components.SSExploreHeader
import com.marvisociety.app.ui.components.SSFilterChip
import com.marvisociety.app.ui.components.SSFilterToolbar
import com.marvisociety.app.ui.components.SegmentedTabs
import com.marvisociety.app.ui.components.StatusPill
import com.marvisociety.app.ui.theme.MarviColor
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

    val featured = filtered.take(5)
    val featuredIds = featured.map { it.id }.toSet()
    val listOffers = filtered.filter { it.id !in featuredIds }

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
                HomeHeader(
                    greeting = viewModel.profile.name.ifBlank { viewModel.t(MarviL10n.Key.MEMBER_LABEL) },
                    subtitle = "$city · ${viewModel.t(MarviL10n.Key.PRIVATE_ACCESS)}",
                    avatarUrl = viewModel.profile.avatarUrl.takeIf { it.isNotBlank() },
                    avatarLetter = viewModel.profile.name.ifBlank { "M" },
                    hiPrefix = viewModel.t(MarviL10n.Key.HI_GREETING),
                    unreadCount = viewModel.unreadInboxCount,
                    onProfile = onOpenProfile,
                    onNotifications = onOpenInbox
                )
            }

            if (viewModel.profile.status != MembershipStatus.APPROVED) {
                item {
                    MembershipStatusBanner(
                        status = viewModel.profile.status,
                        pausedBySelf = viewModel.accountPausedBySelf,
                        viewModelLabel = viewModel::t,
                        onReactivate = viewModel::reactivateAccount
                    )
                }
            }

            item {
                SSExploreHeader(
                    eyebrow = viewModel.t(MarviL10n.Key.FIND_EXPLORE_EVENTS),
                    cityPrefix = viewModel.t(MarviL10n.Key.UP_NEXT_IN),
                    city = city,
                    eventsFound = viewModel.tf(MarviL10n.Key.EVENTS_FOUND, filtered.size)
                )
            }

            item {
                SSDiscoverAxisPills(
                    whenTitle = viewModel.t(MarviL10n.Key.WHEN_AXIS),
                    whereTitle = viewModel.t(MarviL10n.Key.WHERE_AXIS),
                    typeTitle = viewModel.t(MarviL10n.Key.EVENT_TYPE_AXIS),
                    whenReset = viewModel.t(MarviL10n.Key.ANY_WHEN),
                    whereReset = viewModel.t(MarviL10n.Key.ANY_WHERE),
                    typeReset = viewModel.t(MarviL10n.Key.ANY_TYPE),
                    whenOptions = whenOptions,
                    whereOptions = whereOptions,
                    typeOptions = eventTypes,
                    selectedWhen = selectedWhen,
                    selectedWhere = selectedWhere,
                    selectedType = selectedEventType,
                    onWhen = { selectedWhen = it },
                    onWhere = { selectedWhere = it },
                    onType = { selectedEventType = it }
                )
            }

            item {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(OfferCategory.entries) { cat ->
                        SSFilterChip(
                            title = viewModel.categoryLabel(cat),
                            dimmed = categoryFilter != null && categoryFilter != cat,
                            onClick = { categoryFilter = if (categoryFilter == cat) null else cat }
                        )
                    }
                }
            }

            item {
                SSFilterToolbar(
                    filtersLabel = viewModel.t(MarviL10n.Key.FILTERS),
                    sortLabel = viewModel.t(MarviL10n.Key.SORT_BY),
                    locationLabel = viewModel.t(MarviL10n.Key.LOCATION),
                    dateLabel = viewModel.t(MarviL10n.Key.DATE),
                    onFilters = {
                        filter = if (filter == DiscoverFilter.ALL) DiscoverFilter.SAVED else DiscoverFilter.ALL
                    },
                    onSort = { showSort = true },
                    onLocation = {
                        selectedWhere = if (selectedWhere == whereOptions.firstOrNull()) null else whereOptions.firstOrNull()
                    },
                    onDate = { selectedCalendarDay = if (selectedCalendarDay == 0) null else 0 }
                )
            }

            item {
                MarviTextField(
                    value = searchText,
                    onValueChange = { searchText = it },
                    placeholder = viewModel.t(MarviL10n.Key.SEARCH_VENUE_PROMPT)
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
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(
                            viewModel.t(MarviL10n.Key.FEATURED_EVENTS).uppercase(),
                            style = MaterialTheme.typography.labelMedium,
                            color = MarviColor.Muted,
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 1.sp
                        )
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                            items(featured, key = { "feat-${it.id}" }) { offer ->
                                FeaturedOfferCard(offer) { onOfferClick(offer) }
                            }
                        }
                    }
                }
            }

            item {
                EventCalendarStrip(
                    days = calendarDays,
                    selectedDay = selectedCalendarDay,
                    onSelect = { selectedCalendarDay = it }
                )
            }

            item {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    item {
                        FilterChipPill(
                            viewModel.t(MarviL10n.Key.FILTER_ALL),
                            selected = filter == DiscoverFilter.ALL,
                            onClick = { filter = DiscoverFilter.ALL }
                        )
                    }
                    item {
                        FilterChipPill(
                            viewModel.t(MarviL10n.Key.FILTER_SAVED),
                            selected = filter == DiscoverFilter.SAVED,
                            onClick = { filter = DiscoverFilter.SAVED }
                        )
                    }
                    item {
                        FilterChipPill(
                            viewModel.t(MarviL10n.Key.FILTER_FEW_SLOTS),
                            selected = filter == DiscoverFilter.URGENT,
                            onClick = { filter = DiscoverFilter.URGENT }
                        )
                    }
                }
            }

            item {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    item {
                        FilterChipPill(
                            viewModel.t(MarviL10n.Key.FILTER_ALL),
                            selected = modelFilter == null,
                            onClick = { modelFilter = null }
                        )
                    }
                    items(CollaborationModel.entries) { model ->
                        FilterChipPill(
                            viewModel.modelLabel(model),
                            selected = modelFilter == model,
                            onClick = { modelFilter = if (modelFilter == model) null else model }
                        )
                    }
                }
            }

            if (filtered.isEmpty()) {
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
                    EventListCard(
                        offer = offer,
                        saved = offer.id in viewModel.savedOfferIds,
                        accepted = offer.id in viewModel.acceptedOfferIds,
                        acceptedLabel = viewModel.t(MarviL10n.Key.CONFIRMED_STATUS),
                        dateLabel = viewModel.localizeServerText(offer.dateLabel),
                        onClick = { onOfferClick(offer) },
                        onToggleSaved = { viewModel.toggleSaved(offer.id) }
                    )
                }
            }

            item { Spacer(Modifier.height(24.dp)) }
        }
    }

    if (showSort) {
        MarviActionSheet(
            title = viewModel.t(MarviL10n.Key.SORT_EVENTS),
            onDismiss = { showSort = false }
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
            SecondaryActionButton(
                title = viewModel.t(MarviL10n.Key.CLOSE),
                onClick = { showSort = false }
            )
        }
    }
}

@Composable
private fun FeaturedOfferCard(offer: Offer, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .width(200.dp)
            .clip(RoundedCornerShape(16.dp))
            .border(1.dp, MarviColor.Border, RoundedCornerShape(16.dp))
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
                .padding(10.dp),
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
                style = MaterialTheme.typography.labelMedium,
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
    acceptedLabel: String,
    dateLabel: String,
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
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        OfferImageView(
            url = OfferImagery.imageUrl(offer),
            contentDescription = offer.title,
            modifier = Modifier.size(72.dp, 80.dp),
            height = 80.dp,
            cornerRadius = 14.dp
        )
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                offer.venue.uppercase(),
                style = MaterialTheme.typography.labelSmall,
                color = MarviColor.Rose,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp,
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
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(dateLabel, style = MaterialTheme.typography.bodySmall, color = MarviColor.Muted, maxLines = 1)
                if (accepted) StatusPill(acceptedLabel, MarviColor.Emerald)
            }
        }
        Box(
            modifier = Modifier
                .size(36.dp)
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
