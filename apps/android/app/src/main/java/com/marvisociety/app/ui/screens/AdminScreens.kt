package com.marvisociety.app.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.marvisociety.app.data.AdminBookingSummary
import com.marvisociety.app.data.AdminTaskStatus
import com.marvisociety.app.data.AdminVenueSummary
import com.marvisociety.app.data.Campaign
import com.marvisociety.app.data.CollaborationModel
import com.marvisociety.app.data.InboxMessage
import com.marvisociety.app.data.InboxSection
import com.marvisociety.app.data.MembershipStatus
import com.marvisociety.app.data.UserRole
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.BrandLockup
import com.marvisociety.app.ui.components.EmptyStateView
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel
import kotlinx.coroutines.launch

private enum class AdminSection { QUEUE, BOOKINGS, VENUES, USERS, CAMPAIGNS }

@Composable
fun AdminDashboardScreen(viewModel: AppViewModel) {
    LaunchedEffect(Unit) { viewModel.refreshFromServer() }

    var section by remember { mutableStateOf(AdminSection.QUEUE) }
    var showCreateInvite by remember { mutableStateOf(false) }
    var inviteEmail by remember { mutableStateOf("") }
    var inviteMaxUses by remember { mutableStateOf("1") }
    var inviteOwnerType by remember { mutableStateOf("creator") }
    var isCreatingInvite by remember { mutableStateOf(false) }
    var resolvingTaskId by remember { mutableStateOf<String?>(null) }

    MarviScreen {
        Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
            BrandLockup(subtitle = viewModel.t(MarviL10n.Key.ADMIN))
            Spacer(modifier = Modifier.height(12.dp))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                item {
                    AdminTabChip(
                        selected = section == AdminSection.QUEUE,
                        label = "${viewModel.t(MarviL10n.Key.ADMIN_TAB_QUEUE)} (${viewModel.adminTasks.size})",
                        onClick = { section = AdminSection.QUEUE }
                    )
                }
                item {
                    AdminTabChip(
                        selected = section == AdminSection.BOOKINGS,
                        label = "${viewModel.t(MarviL10n.Key.ADMIN_TAB_BOOKINGS)} (${viewModel.adminBookings.size})",
                        onClick = { section = AdminSection.BOOKINGS }
                    )
                }
                item {
                    AdminTabChip(
                        selected = section == AdminSection.VENUES,
                        label = "${viewModel.t(MarviL10n.Key.ADMIN_TAB_VENUES)} (${viewModel.adminVenues.size})",
                        onClick = { section = AdminSection.VENUES }
                    )
                }
                item {
                    AdminTabChip(
                        selected = section == AdminSection.USERS,
                        label = "${viewModel.t(MarviL10n.Key.ADMIN_TAB_USERS)} (${viewModel.adminUsers.size})",
                        onClick = { section = AdminSection.USERS }
                    )
                }
                item {
                    AdminTabChip(
                        selected = section == AdminSection.CAMPAIGNS,
                        label = "${viewModel.t(MarviL10n.Key.ADMIN_TAB_CAMPAIGNS)} (${viewModel.campaigns.count { !it.isDeleted }})",
                        onClick = { section = AdminSection.CAMPAIGNS }
                    )
                }
            }
            Spacer(modifier = Modifier.height(12.dp))

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                when (section) {
                    AdminSection.QUEUE -> {
                        item {
                            AdminSectionHeader(
                                title = viewModel.t(MarviL10n.Key.ADMIN_TASKS),
                                count = viewModel.adminTasks.size
                            )
                        }
                        if (viewModel.adminTasks.isEmpty()) {
                            item {
                                EmptyStateView(
                                    title = viewModel.t(MarviL10n.Key.ADMIN_TASKS_EMPTY),
                                    subtitle = viewModel.t(MarviL10n.Key.ADMIN_TASKS_EMPTY_SUB),
                                    actionTitle = viewModel.t(MarviL10n.Key.REFRESH),
                                    onAction = viewModel::refreshFromServer
                                )
                            }
                        }
                        items(viewModel.adminTasks, key = { it.id }) { task ->
                            MarviCard {
                                Text(viewModel.taskTypeLabel(task.type), fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                                if (task.subtitle.isNotBlank()) {
                                    Text(task.subtitle, color = MarviColor.Muted)
                                }
                                Text(
                                    "${viewModel.priorityLabel(task.priority)} · ${viewModel.localizeServerText(task.dateLabel)}",
                                    color = MarviColor.Graphite,
                                    style = MaterialTheme.typography.bodySmall
                                )
                                if (task.status == AdminTaskStatus.OPEN) {
                                    Row(
                                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                                        modifier = Modifier.padding(top = 8.dp)
                                    ) {
                                        Button(
                                            onClick = {
                                                resolvingTaskId = task.id
                                                viewModel.approveTask(task.id) { resolvingTaskId = null }
                                            },
                                            enabled = resolvingTaskId == null,
                                            colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Emerald)
                                        ) { Text(viewModel.t(MarviL10n.Key.APPROVE)) }
                                        Button(
                                            onClick = {
                                                resolvingTaskId = task.id
                                                viewModel.rejectTask(task.id) { resolvingTaskId = null }
                                            },
                                            enabled = resolvingTaskId == null,
                                            colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Tomato)
                                        ) { Text(viewModel.t(MarviL10n.Key.REJECT)) }
                                    }
                                }
                            }
                        }
                    }

                    AdminSection.BOOKINGS -> {
                        item {
                            AdminSectionHeader(
                                title = viewModel.t(MarviL10n.Key.ADMIN_TAB_BOOKINGS),
                                count = viewModel.adminBookings.size
                            )
                        }
                        if (viewModel.adminBookings.isEmpty()) {
                            item {
                                EmptyStateView(
                                    title = viewModel.t(MarviL10n.Key.ADMIN_BOOKINGS_EMPTY),
                                    subtitle = viewModel.t(MarviL10n.Key.ADMIN_BOOKINGS_EMPTY_SUB),
                                    actionTitle = viewModel.t(MarviL10n.Key.REFRESH),
                                    onAction = { viewModel.loadAdminBookings() }
                                )
                            }
                        }
                        items(viewModel.adminBookings, key = { it.id }) { booking ->
                            AdminBookingCard(viewModel, booking)
                        }
                    }

                    AdminSection.VENUES -> {
                        item {
                            AdminSectionHeader(
                                title = viewModel.t(MarviL10n.Key.ADMIN_TAB_VENUES),
                                count = viewModel.adminVenues.size
                            )
                            Text(
                                viewModel.t(MarviL10n.Key.ADMIN_VENUES_HELP),
                                color = MarviColor.Muted,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                        if (viewModel.adminVenues.isEmpty()) {
                            item {
                                EmptyStateView(
                                    title = viewModel.t(MarviL10n.Key.ADMIN_VENUES_EMPTY),
                                    subtitle = viewModel.t(MarviL10n.Key.ADMIN_VENUES_EMPTY_SUB),
                                    actionTitle = viewModel.t(MarviL10n.Key.REFRESH),
                                    onAction = { viewModel.loadAdminVenues() }
                                )
                            }
                        }
                        items(viewModel.adminVenues, key = { it.id }) { venue ->
                            AdminVenueCard(viewModel, venue)
                        }
                    }

                    AdminSection.USERS -> {
                        item {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                AdminSectionHeader(
                                    title = viewModel.t(MarviL10n.Key.INVITE_CODES),
                                    count = viewModel.adminInviteCodes.size
                                )
                                Button(
                                    onClick = { showCreateInvite = !showCreateInvite },
                                    colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                                ) {
                                    Text(
                                        if (showCreateInvite) viewModel.t(MarviL10n.Key.CLOSE)
                                        else viewModel.t(MarviL10n.Key.CREATE_INVITE_CODE)
                                    )
                                }
                            }
                        }
                        if (showCreateInvite) {
                            item {
                                MarviCard {
                                    OutlinedTextField(
                                        value = inviteEmail,
                                        onValueChange = { inviteEmail = it },
                                        label = { Text(viewModel.t(MarviL10n.Key.INVITE_EMAIL)) },
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                    OutlinedTextField(
                                        value = inviteMaxUses,
                                        onValueChange = { inviteMaxUses = it.filter { ch -> ch.isDigit() }.ifBlank { "1" } },
                                        label = { Text(viewModel.t(MarviL10n.Key.MAX_USES)) },
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        listOf("creator", "venue").forEach { type ->
                                            FilterChip(
                                                selected = inviteOwnerType == type,
                                                onClick = { inviteOwnerType = type },
                                                label = {
                                                    Text(
                                                        if (type == "venue") viewModel.t(MarviL10n.Key.VENUE_TAG)
                                                        else viewModel.t(MarviL10n.Key.CREATOR_TAG)
                                                    )
                                                },
                                                colors = FilterChipDefaults.filterChipColors(
                                                    selectedContainerColor = MarviColor.Rose.copy(alpha = 0.25f),
                                                    selectedLabelColor = MarviColor.Rose
                                                )
                                            )
                                        }
                                    }
                                    Button(
                                        onClick = {
                                            isCreatingInvite = true
                                            viewModel.adminCreateInvite(
                                                code = null,
                                                ownerType = inviteOwnerType,
                                                maxUses = inviteMaxUses.toIntOrNull()?.coerceIn(1, 999) ?: 1,
                                                inviteEmail = inviteEmail.ifBlank { null }
                                            ) { succeeded ->
                                                isCreatingInvite = false
                                                if (succeeded) {
                                                    inviteEmail = ""
                                                    inviteMaxUses = "1"
                                                    showCreateInvite = false
                                                }
                                            }
                                        },
                                        enabled = !isCreatingInvite,
                                        modifier = Modifier.fillMaxWidth(),
                                        colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Emerald)
                                    ) {
                                        Text(
                                            if (isCreatingInvite) viewModel.t(MarviL10n.Key.SUBMITTING)
                                            else viewModel.t(MarviL10n.Key.CREATE)
                                        )
                                    }
                                }
                            }
                        }
                        if (viewModel.adminInviteCodes.isEmpty() && !showCreateInvite) {
                            item {
                                Text(
                                    viewModel.t(MarviL10n.Key.INVITE_CODES_EMPTY),
                                    color = MarviColor.Muted,
                                    style = MaterialTheme.typography.bodyMedium
                                )
                            }
                        }
                        items(viewModel.adminInviteCodes, key = { it.code }) { code ->
                            MarviCard {
                                Text(code.code, fontWeight = FontWeight.Bold, color = MarviColor.Rose)
                                val ownerLabel = if (code.ownerType.equals("venue", ignoreCase = true)) {
                                    viewModel.t(MarviL10n.Key.VENUE_TAG)
                                } else {
                                    viewModel.t(MarviL10n.Key.CREATOR_TAG)
                                }
                                Text(
                                    "${code.useCount}/${code.maxUses} ${viewModel.t(MarviL10n.Key.USES_SUFFIX)} · $ownerLabel",
                                    color = MarviColor.Muted
                                )
                                code.inviteEmail?.let {
                                    Text(it, color = MarviColor.Graphite, style = MaterialTheme.typography.bodySmall)
                                }
                            }
                        }
                        item {
                            AdminSectionHeader(
                                title = viewModel.t(MarviL10n.Key.ADMIN_USERS),
                                count = viewModel.adminUsers.size,
                                modifier = Modifier.padding(top = 8.dp)
                            )
                        }
                        if (viewModel.adminUsers.isEmpty()) {
                            item {
                                Text(
                                    viewModel.t(MarviL10n.Key.ADMIN_USERS_EMPTY),
                                    color = MarviColor.Muted,
                                    style = MaterialTheme.typography.bodyMedium
                                )
                            }
                        }
                        items(viewModel.adminUsers, key = { it.id }) { user ->
                            MarviCard {
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    if (user.avatarUrl.isNotBlank()) {
                                        AsyncImage(
                                            model = user.avatarUrl,
                                            contentDescription = null,
                                            contentScale = ContentScale.Crop,
                                            modifier = Modifier
                                                .size(48.dp)
                                                .clip(CircleShape)
                                                .background(MarviColor.PanelElevated, CircleShape)
                                        )
                                    } else {
                                        Box(
                                            modifier = Modifier
                                                .size(48.dp)
                                                .background(MarviColor.Rose.copy(alpha = 0.15f), CircleShape),
                                            contentAlignment = Alignment.Center
                                        ) {
                                            Text(
                                                user.fullName.ifBlank { user.email }.take(2).uppercase(),
                                                color = MarviColor.Rose,
                                                fontWeight = FontWeight.Bold
                                            )
                                        }
                                    }
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            user.fullName.ifBlank { user.email },
                                            fontWeight = FontWeight.Bold,
                                            color = MarviColor.Ink
                                        )
                                        Text("${user.email} · ${user.city}", color = MarviColor.Muted)
                                        Text(viewModel.roleLabel(user.role), color = MarviColor.Rose)
                                    }
                                }
                                Spacer(modifier = Modifier.height(10.dp))
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    TextButton(onClick = {
                                        viewModel.adminSetUserStatus(user.id, MembershipStatus.APPROVED)
                                    }) {
                                        Text(viewModel.t(MarviL10n.Key.APPROVE), color = MarviColor.Emerald)
                                    }
                                    TextButton(onClick = {
                                        viewModel.adminSetUserStatus(user.id, MembershipStatus.PAUSED)
                                    }) {
                                        Text(viewModel.t(MarviL10n.Key.BLOCK), color = MarviColor.Tomato)
                                    }
                                }
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    TextButton(onClick = {
                                        viewModel.adminSetUserRole(user.id, UserRole.CREATOR)
                                    }) {
                                        Text(viewModel.t(MarviL10n.Key.ADMIN_MAKE_CREATOR), color = MarviColor.Rose)
                                    }
                                    TextButton(onClick = {
                                        viewModel.adminSetUserRole(user.id, UserRole.VENUE)
                                    }) {
                                        Text(viewModel.t(MarviL10n.Key.ADMIN_MAKE_BUSINESS), color = MarviColor.Gold)
                                    }
                                    TextButton(onClick = {
                                        viewModel.adminSetUserRole(user.id, UserRole.ADMIN)
                                    }) {
                                        Text(viewModel.t(MarviL10n.Key.ADMIN_MAKE_ADMIN), color = MarviColor.Aubergine)
                                    }
                                }
                            }
                        }
                    }
                    AdminSection.CAMPAIGNS -> {
                        item {
                            AdminSectionHeader(
                                title = viewModel.t(MarviL10n.Key.ADMIN_TAB_CAMPAIGNS),
                                count = viewModel.campaigns.count { !it.isDeleted }
                            )
                        }
                        val adminCampaigns = viewModel.campaigns.filterNot { it.isDeleted }
                        if (adminCampaigns.isEmpty()) {
                            item {
                                Text(
                                    viewModel.t(MarviL10n.Key.NO_ACTIVE_CAMPAIGNS),
                                    color = MarviColor.Muted,
                                    style = MaterialTheme.typography.bodyMedium
                                )
                            }
                        }
                        items(adminCampaigns, key = { it.id }) { campaign ->
                            MarviCard {
                                Text(campaign.title, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                                Text(
                                    "${campaign.venueName} · ${campaign.status} · ${campaign.dateLabel}",
                                    color = MarviColor.Muted,
                                    style = MaterialTheme.typography.bodySmall
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    if (campaign.status.equals("live", ignoreCase = true)) {
                                        TextButton(onClick = {
                                            viewModel.adminSetOfferStatus(campaign.id, "draft")
                                        }) {
                                            Text(viewModel.t(MarviL10n.Key.UNPUBLISH_CAMPAIGN), color = MarviColor.Tomato)
                                        }
                                    } else {
                                        TextButton(onClick = {
                                            viewModel.adminSetOfferStatus(campaign.id, "live")
                                        }) {
                                            Text(viewModel.t(MarviL10n.Key.PUBLISH_CAMPAIGN), color = MarviColor.Emerald)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AdminTabChip(selected: Boolean, label: String, onClick: () -> Unit) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(label) },
        colors = FilterChipDefaults.filterChipColors(
            selectedContainerColor = MarviColor.Rose.copy(alpha = 0.25f),
            selectedLabelColor = MarviColor.Rose
        )
    )
}

@Composable
private fun AdminVenueCard(viewModel: AppViewModel, venue: AdminVenueSummary) {
    var confirmDelete by remember { mutableStateOf(false) }
    val status = venue.status
    MarviCard {
        Text(venue.venueName, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
        Text("${venue.area} · ${venue.category}", color = MarviColor.Muted)
        val owner = venue.ownerName.ifBlank { venue.ownerEmail }
        if (owner.isNotBlank()) {
            Text(owner, color = MarviColor.Graphite, style = MaterialTheme.typography.bodySmall)
        }
        Text(
            venue.id.take(8).uppercase(),
            color = MarviColor.Muted.copy(alpha = 0.7f),
            style = MaterialTheme.typography.labelSmall
        )
        Text(
            "${venue.liveOfferCount} live · ${venue.offerCount} campaigns · ${venue.bookingCount} bookings",
            color = MarviColor.Muted,
            style = MaterialTheme.typography.bodySmall
        )
        Text(
            when (status) {
                MembershipStatus.APPROVED -> viewModel.t(MarviL10n.Key.STATUS_APPROVED)
                MembershipStatus.PAUSED -> viewModel.t(MarviL10n.Key.STATUS_PAUSED)
                MembershipStatus.UNDER_REVIEW, null -> viewModel.t(MarviL10n.Key.STATUS_UNDER_REVIEW)
            },
            color = when (status) {
                MembershipStatus.APPROVED -> MarviColor.Emerald
                MembershipStatus.PAUSED -> MarviColor.Tomato
                else -> MarviColor.Gold
            },
            fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.labelMedium
        )
        if (status == MembershipStatus.APPROVED && venue.liveOfferCount == 0) {
            Text(
                viewModel.t(MarviL10n.Key.ADMIN_VENUE_NO_LIVE_HINT),
                color = MarviColor.Gold,
                style = MaterialTheme.typography.labelSmall
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
            when (status) {
                MembershipStatus.APPROVED -> {
                    TextButton(onClick = {
                        viewModel.adminSetVenueStatus(venue.id, MembershipStatus.PAUSED)
                    }) {
                        Text(viewModel.t(MarviL10n.Key.ADMIN_VENUE_NEEDS_CHANGES), color = MarviColor.Tomato)
                    }
                    TextButton(onClick = {
                        viewModel.adminSetVenueStatus(venue.id, MembershipStatus.UNDER_REVIEW)
                    }) {
                        Text(viewModel.t(MarviL10n.Key.ADMIN_VENUE_SEND_REVIEW), color = MarviColor.Gold)
                    }
                }
                MembershipStatus.PAUSED -> {
                    TextButton(onClick = {
                        viewModel.adminSetVenueStatus(venue.id, MembershipStatus.APPROVED)
                    }) {
                        Text(viewModel.t(MarviL10n.Key.APPROVE), color = MarviColor.Emerald)
                    }
                    TextButton(onClick = {
                        viewModel.adminSetVenueStatus(venue.id, MembershipStatus.UNDER_REVIEW)
                    }) {
                        Text(viewModel.t(MarviL10n.Key.ADMIN_VENUE_SEND_REVIEW), color = MarviColor.Gold)
                    }
                }
                else -> {
                    TextButton(onClick = {
                        viewModel.adminSetVenueStatus(venue.id, MembershipStatus.APPROVED)
                    }) {
                        Text(viewModel.t(MarviL10n.Key.APPROVE), color = MarviColor.Emerald)
                    }
                    TextButton(onClick = {
                        viewModel.adminSetVenueStatus(venue.id, MembershipStatus.PAUSED)
                    }) {
                        Text(viewModel.t(MarviL10n.Key.ADMIN_VENUE_NEEDS_CHANGES), color = MarviColor.Tomato)
                    }
                }
            }
        }
        TextButton(onClick = { confirmDelete = true }) {
            Text(viewModel.t(MarviL10n.Key.ADMIN_VENUE_DELETE), color = MarviColor.Tomato)
        }
        if (confirmDelete) {
            Text(
                viewModel.t(MarviL10n.Key.ADMIN_VENUE_DELETE_CONFIRM),
                color = MarviColor.Muted,
                style = MaterialTheme.typography.bodySmall
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextButton(onClick = {
                    viewModel.adminDeleteVenue(venue.id)
                    confirmDelete = false
                }) {
                    Text(viewModel.t(MarviL10n.Key.DELETE), color = MarviColor.Tomato)
                }
                TextButton(onClick = { confirmDelete = false }) {
                    Text(viewModel.t(MarviL10n.Key.CANCEL), color = MarviColor.Muted)
                }
            }
        }
    }
}

@Composable
private fun AdminBookingCard(viewModel: AppViewModel, booking: AdminBookingSummary) {
    MarviCard {
        Text(booking.offerTitle.ifBlank { "—" }, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
        Text(booking.venueName.ifBlank { "—" }, color = MarviColor.Muted)
        if (booking.guestName.isNotBlank()) {
            Text(booking.guestName, color = MarviColor.Graphite, fontWeight = FontWeight.SemiBold)
        }
        if (booking.guestEmail.isNotBlank()) {
            Text(booking.guestEmail, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
        }
        Text(
            booking.stage.replace('_', ' '),
            color = MarviColor.Rose,
            fontWeight = FontWeight.Bold,
            style = MaterialTheme.typography.labelMedium
        )
        if (booking.dateLabel.isNotBlank()) {
            Text(booking.dateLabel, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
        }
        if (booking.proofStatus.isNotBlank()) {
            Text(
                "Proof: ${booking.proofStatus.replace('_', ' ')}",
                color = MarviColor.Aubergine,
                style = MaterialTheme.typography.labelSmall
            )
        }
    }
}

@Composable
fun InboxScreen(viewModel: AppViewModel) {
    val role = viewModel.selectedRole
    val subtitle = when (role) {
        UserRole.CREATOR -> viewModel.t(MarviL10n.Key.INBOX_SUB_CREATOR)
        UserRole.VENUE -> viewModel.t(MarviL10n.Key.INBOX_SUB_BUSINESS)
        UserRole.ADMIN -> viewModel.t(MarviL10n.Key.INBOX_SUB_ADMIN)
    }
    val emptySub = when (role) {
        UserRole.CREATOR -> viewModel.t(MarviL10n.Key.INBOX_EMPTY_CREATOR)
        UserRole.VENUE -> viewModel.t(MarviL10n.Key.INBOX_EMPTY_BUSINESS)
        UserRole.ADMIN -> viewModel.t(MarviL10n.Key.INBOX_EMPTY_ADMIN)
    }
    val sections = InboxSection.ordered(role).mapNotNull { section ->
        val items = viewModel.inboxMessages.filter { it.section == section }
        if (items.isEmpty()) null else section to items
    }

    MarviScreen {
        Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
            BrandLockup(subtitle = viewModel.t(MarviL10n.Key.INBOX_TITLE))
            Spacer(Modifier.height(8.dp))
            Text(subtitle, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
            Spacer(Modifier.height(12.dp))
            if (viewModel.inboxMessages.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        viewModel.t(MarviL10n.Key.INBOX_UNREAD_COUNT)
                            .replace("%d", viewModel.unreadInboxCount.toString()),
                        color = MarviColor.Muted,
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.SemiBold
                    )
                    TextButton(onClick = viewModel::markAllInboxRead) {
                        Text(viewModel.t(MarviL10n.Key.INBOX_MARK_ALL_READ), color = MarviColor.Rose)
                    }
                }
                Spacer(Modifier.height(8.dp))
            }
            if (viewModel.inboxMessages.isEmpty()) {
                EmptyStateView(
                    title = viewModel.t(MarviL10n.Key.INBOX_EMPTY),
                    subtitle = emptySub,
                    actionTitle = viewModel.t(MarviL10n.Key.REFRESH),
                    onAction = viewModel::refreshFromServer
                )
            } else {
                LazyColumn(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    sections.forEach { (section, messages) ->
                        item(key = "section-${section.name}") {
                            Text(
                                inboxSectionTitle(viewModel, section, role),
                                color = MarviColor.Muted,
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.Bold
                            )
                        }
                        items(messages, key = { it.id }) { msg ->
                            MarviCard(
                                modifier = Modifier.clickable {
                                    viewModel.openInboxMessage(msg)
                                }
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(8.dp)
                                            .clip(CircleShape)
                                            .background(MarviColor.Rose)
                                    )
                                    Text(
                                        viewModel.localizeServerText(msg.title),
                                        fontWeight = FontWeight.Bold,
                                        color = MarviColor.Ink,
                                        modifier = Modifier.weight(1f)
                                    )
                                    Text(
                                        viewModel.t(MarviL10n.Key.OPEN_ACTION),
                                        color = MarviColor.Emerald,
                                        fontWeight = FontWeight.Bold,
                                        style = MaterialTheme.typography.bodySmall
                                    )
                                }
                                Text(viewModel.localizeServerText(msg.body), color = MarviColor.Graphite)
                                Text(
                                    viewModel.localizeServerText(msg.dateLabel),
                                    color = MarviColor.Muted,
                                    style = MaterialTheme.typography.bodySmall
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun inboxSectionTitle(
    viewModel: AppViewModel,
    section: InboxSection,
    role: UserRole
): String {
    val key = when (section) {
        InboxSection.ACTION_NEEDED -> when (role) {
            UserRole.VENUE -> MarviL10n.Key.INBOX_SECTION_REQUESTS
            UserRole.ADMIN -> MarviL10n.Key.INBOX_SECTION_OPS
            else -> MarviL10n.Key.INBOX_SECTION_ACTION
        }
        InboxSection.BOOKINGS -> when (role) {
            UserRole.VENUE -> MarviL10n.Key.INBOX_SECTION_CAMPAIGNS
            else -> MarviL10n.Key.INBOX_SECTION_BOOKINGS
        }
        InboxSection.MESSAGES -> MarviL10n.Key.INBOX_SECTION_MESSAGES
        InboxSection.ACCOUNT -> MarviL10n.Key.INBOX_SECTION_ACCOUNT
        InboxSection.OPS -> MarviL10n.Key.INBOX_SECTION_OPS
    }
    return viewModel.t(key)
}

@Composable
private fun AdminSectionHeader(title: String, count: Int, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
        Text(count.toString(), color = MarviColor.Muted, style = MaterialTheme.typography.labelMedium)
    }
}

@Composable
fun VenueStudioScreen(
    viewModel: AppViewModel,
    onAddEstablishment: () -> Unit = {},
    onEditEstablishment: (String) -> Unit = {}
) {
    var showCreate by remember { mutableStateOf(false) }
    var title by remember { mutableStateOf("") }
    var valueLabel by remember { mutableStateOf("") }
    var dateLabel by remember { mutableStateOf("") }
    val focusedVenue = viewModel.myVenues.firstOrNull { it.isActive } ?: viewModel.myVenues.firstOrNull()
    val canCreateCampaign = focusedVenue?.status == MembershipStatus.APPROVED
    val pendingConfirmations = viewModel.pendingVenueConfirmations
    val hasLiveCampaign = viewModel.liveCampaignId != null
    var timeLabel by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var deliverables by remember { mutableStateOf("") }
    var requirements by remember { mutableStateOf("") }
    var hostNote by remember { mutableStateOf("") }
    var slots by remember { mutableStateOf("5") }
    var model by remember { mutableStateOf(CollaborationModel.INVITATION) }
    var imageUri by remember { mutableStateOf<Uri?>(null) }
    var submitting by remember { mutableStateOf(false) }
    var formError by remember { mutableStateOf<String?>(null) }
    var campaignPendingDelete by remember { mutableStateOf<Campaign?>(null) }
    var deleteFeedback by remember { mutableStateOf<String?>(null) }
    var showPastCampaigns by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val visibleCampaigns = viewModel.campaigns.filterNot { it.isDeleted }.filter { campaign ->
        val completed = campaign.status.equals("Completed", ignoreCase = true)
            || campaign.status.equals("completed", ignoreCase = true)
            || campaign.status.contains("Tamam", ignoreCase = true)
        if (showPastCampaigns) completed else !completed
    }

    LaunchedEffect(Unit) {
        viewModel.loadSwipeCandidates()
        viewModel.loadVenueReviewQueue()
        viewModel.loadMyBrands()
    }

    val imagePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri -> imageUri = uri }

    MarviScreen {
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Text(viewModel.t(MarviL10n.Key.STUDIO), style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
            }
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(viewModel.t(MarviL10n.Key.MY_ESTABLISHMENTS), fontWeight = FontWeight.SemiBold, color = MarviColor.Ink)
                    Button(
                        onClick = onAddEstablishment,
                        colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                    ) {
                        Text(viewModel.t(MarviL10n.Key.ADD_ESTABLISHMENT))
                    }
                }
            }
            items(viewModel.myVenues, key = { it.id }) { venue ->
                MarviCard(
                    modifier = Modifier.clickable {
                        if (!venue.isActive) viewModel.setActiveVenue(venue.id)
                    }
                ) {
                    Text(venue.name, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                    Text("${venue.area} · ${viewModel.categoryLabel(venue.category)}", color = MarviColor.Muted)
                    when (venue.status) {
                        MembershipStatus.UNDER_REVIEW -> Text(
                            viewModel.t(MarviL10n.Key.VENUE_PENDING_BANNER_TITLE),
                            color = MarviColor.Gold,
                            fontWeight = FontWeight.SemiBold
                        )
                        MembershipStatus.APPROVED -> Text(
                            viewModel.t(MarviL10n.Key.LOCATION_APPROVED),
                            color = MarviColor.Emerald,
                            fontWeight = FontWeight.SemiBold
                        )
                        MembershipStatus.PAUSED -> Text(
                            viewModel.t(MarviL10n.Key.LOCATION_REJECTED),
                            color = MarviColor.Tomato,
                            fontWeight = FontWeight.SemiBold
                        )
                        null -> Unit
                    }
                    if (venue.isActive) Text(viewModel.t(MarviL10n.Key.VENUE_ACTIVE), color = MarviColor.Rose)
                }
            }
            item {
                val focused = focusedVenue
                when (focused?.status) {
                    MembershipStatus.UNDER_REVIEW -> MarviCard {
                        Text(viewModel.t(MarviL10n.Key.VENUE_PENDING_BANNER_TITLE), fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                        Text(viewModel.t(MarviL10n.Key.VENUE_PENDING_BANNER_SUB), color = MarviColor.Muted)
                    }
                    MembershipStatus.APPROVED -> MarviCard {
                        val hasLive = viewModel.campaigns.any { !it.isDeleted && it.status.equals("live", ignoreCase = true) }
                        Text(viewModel.t(MarviL10n.Key.VENUE_APPROVED_BANNER_TITLE), fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                        Text(
                            viewModel.t(
                                if (hasLive) MarviL10n.Key.VENUE_APPROVED_BANNER_SUB
                                else MarviL10n.Key.VENUE_APPROVED_NEEDS_LIVE_SUB
                            ),
                            color = MarviColor.Muted
                        )
                    }
                    MembershipStatus.PAUSED -> MarviCard {
                        Text(viewModel.t(MarviL10n.Key.VENUE_REJECTED_BANNER_TITLE), fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                        Text(viewModel.t(MarviL10n.Key.VENUE_REJECTED_BANNER_SUB), color = MarviColor.Muted)
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(
                            onClick = { focused?.id?.let(onEditEstablishment) },
                            colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                        ) {
                            Text(viewModel.t(MarviL10n.Key.VENUE_EDIT_AND_RESUBMIT))
                        }
                    }
                    null -> Unit
                }
            }
            if (viewModel.myVenues.isEmpty()) {
                item {
                    Text(
                        viewModel.t(MarviL10n.Key.EST_HUB_SUB),
                        color = MarviColor.Muted,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(viewModel.t(MarviL10n.Key.CAMPAIGNS), fontWeight = FontWeight.SemiBold, color = MarviColor.Ink)
                    Button(
                        onClick = {
                            if (!canCreateCampaign) {
                                formError = viewModel.t(MarviL10n.Key.VENUE_MUST_BE_APPROVED)
                                return@Button
                            }
                            formError = null
                            showCreate = !showCreate
                        },
                        enabled = canCreateCampaign || showCreate,
                        colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                    ) {
                        Text(if (showCreate) viewModel.t(MarviL10n.Key.CLOSE) else viewModel.t(MarviL10n.Key.NEW_CAMPAIGN))
                    }
                }
                if (!canCreateCampaign && !showCreate) {
                    Text(
                        viewModel.t(MarviL10n.Key.VENUE_MUST_BE_APPROVED),
                        color = MarviColor.Muted,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }
            if (showCreate) {
                item {
                    MarviCard {
                        Text(viewModel.t(MarviL10n.Key.NEW_CAMPAIGN), fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                        OutlinedButton(
                            onClick = {
                                imagePicker.launch(
                                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                                )
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                if (imageUri != null) viewModel.t(MarviL10n.Key.CAMPAIGN_PHOTO_ADDED)
                                else viewModel.t(MarviL10n.Key.ADD_CAMPAIGN_PHOTO)
                            )
                        }
                        if (imageUri != null) {
                            AsyncImage(
                                model = imageUri,
                                contentDescription = null,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(140.dp),
                                contentScale = ContentScale.Crop
                            )
                        }
                        OutlinedTextField(
                            value = title,
                            onValueChange = { title = it },
                            label = { Text(viewModel.t(MarviL10n.Key.CAMPAIGN_TITLE)) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = dateLabel,
                            onValueChange = { dateLabel = it },
                            label = { Text(viewModel.t(MarviL10n.Key.EVENT_DATE)) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = timeLabel,
                            onValueChange = { timeLabel = it },
                            label = { Text(viewModel.t(MarviL10n.Key.EVENT_TIME)) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = valueLabel,
                            onValueChange = { valueLabel = it },
                            label = { Text(viewModel.t(MarviL10n.Key.CREATOR_VALUE)) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = description,
                            onValueChange = { description = it },
                            label = { Text(viewModel.t(MarviL10n.Key.CAMPAIGN_DESCRIPTION)) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = deliverables,
                            onValueChange = { deliverables = it },
                            label = { Text(viewModel.t(MarviL10n.Key.DELIVERABLES_HINT)) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = requirements,
                            onValueChange = { requirements = it },
                            label = { Text(viewModel.t(MarviL10n.Key.REQUIREMENTS_HINT)) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = hostNote,
                            onValueChange = { hostNote = it },
                            label = { Text(viewModel.t(MarviL10n.Key.HOST_NOTE)) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        OutlinedTextField(
                            value = slots,
                            onValueChange = { slots = it.filter { ch -> ch.isDigit() }.ifBlank { "5" } },
                            label = { Text(viewModel.t(MarviL10n.Key.CREATOR_SLOTS)) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            CollaborationModel.entries.forEach { option ->
                                FilterChip(
                                    selected = model == option,
                                    onClick = { model = option },
                                    label = { Text(viewModel.modelLabel(option)) },
                                    colors = FilterChipDefaults.filterChipColors(
                                        selectedContainerColor = MarviColor.Rose.copy(alpha = 0.25f),
                                        selectedLabelColor = MarviColor.Rose
                                    )
                                )
                            }
                        }
                        Button(
                            onClick = {
                                if (submitting) return@Button
                                val lines = deliverables.split(',', '\n').map { it.trim() }.filter { it.isNotEmpty() }
                                if (title.isBlank() || lines.isEmpty()) {
                                    formError = viewModel.t(MarviL10n.Key.ERR_TITLE_DELIVERABLES)
                                    return@Button
                                }
                                formError = null
                                submitting = true
                                scope.launch {
                                    val ok = viewModel.createCampaign(
                                        title = title.trim(),
                                        model = model,
                                        dateLabel = dateLabel.ifBlank { viewModel.t(MarviL10n.Key.VALUE_TBD) },
                                        valueLabel = valueLabel,
                                        slots = slots.toIntOrNull()?.coerceIn(1, 30) ?: 5,
                                        deliverables = lines,
                                        imageUri = imageUri,
                                        description = description,
                                        timeLabel = timeLabel.ifBlank { viewModel.t(MarviL10n.Key.VALUE_FLEXIBLE) },
                                        requirements = requirements.split(',', '\n').map { it.trim() }.filter { it.isNotEmpty() },
                                        hostNote = hostNote
                                    )
                                    if (ok) {
                                        showCreate = false
                                        title = ""
                                        valueLabel = ""
                                        dateLabel = ""
                                        timeLabel = ""
                                        description = ""
                                        deliverables = ""
                                        requirements = ""
                                        hostNote = ""
                                        imageUri = null
                                        formError = null
                                        submitting = false
                                    } else {
                                        formError = viewModel.lastSyncError
                                            ?: viewModel.t(MarviL10n.Key.SYNC_ERROR)
                                        submitting = false
                                    }
                                }
                            },
                            enabled = !submitting,
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MarviColor.Rose,
                                disabledContainerColor = MarviColor.Muted.copy(alpha = 0.4f)
                            )
                        ) {
                            Text(if (submitting) viewModel.t(MarviL10n.Key.SUBMITTING) else viewModel.t(MarviL10n.Key.SEND_TO_REVIEW))
                        }
                        formError?.let { Text(it, color = MarviColor.Tomato) }
                        viewModel.lastSyncError?.takeIf { formError == null }?.let { Text(it, color = MarviColor.Tomato) }
                    }
                }
            }
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    FilterChip(
                        selected = !showPastCampaigns,
                        onClick = { showPastCampaigns = false },
                        label = { Text(viewModel.t(MarviL10n.Key.STUDIO_CAMPAIGNS_ACTIVE)) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = MarviColor.Rose.copy(alpha = 0.2f),
                            selectedLabelColor = MarviColor.Ink
                        )
                    )
                    FilterChip(
                        selected = showPastCampaigns,
                        onClick = { showPastCampaigns = true },
                        label = { Text(viewModel.t(MarviL10n.Key.STUDIO_CAMPAIGNS_PAST)) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = MarviColor.Muted.copy(alpha = 0.2f),
                            selectedLabelColor = MarviColor.Ink
                        )
                    )
                }
            }
            deleteFeedback?.let { msg ->
                item {
                    Text(msg, color = MarviColor.Emerald, style = MaterialTheme.typography.bodySmall)
                }
            }
            if (visibleCampaigns.isEmpty()) {
                item {
                    MarviCard {
                        Text(
                            if (showPastCampaigns) viewModel.t(MarviL10n.Key.NO_PAST_CAMPAIGNS)
                            else viewModel.t(MarviL10n.Key.NO_ACTIVE_CAMPAIGNS),
                            fontWeight = FontWeight.Bold,
                            color = MarviColor.Ink
                        )
                        Text(
                            if (showPastCampaigns) viewModel.t(MarviL10n.Key.NO_PAST_CAMPAIGNS_SUB)
                            else if (canCreateCampaign) viewModel.t(MarviL10n.Key.NO_ACTIVE_CAMPAIGNS_APPROVED_SUB)
                            else viewModel.t(MarviL10n.Key.NO_ACTIVE_CAMPAIGNS_SUB),
                            color = MarviColor.Muted,
                            style = MaterialTheme.typography.bodySmall
                        )
                        if (!showPastCampaigns) {
                            Button(
                                onClick = { showCreate = true },
                                modifier = Modifier.padding(top = 8.dp),
                                colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                            ) {
                                Text(viewModel.t(MarviL10n.Key.NEW_CAMPAIGN))
                            }
                        }
                    }
                }
            }
            items(visibleCampaigns, key = { it.id }) { campaign ->
                MarviCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.Top
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(campaign.title, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                            Text("${campaign.venueName} · ${campaign.status}", color = MarviColor.Muted)
                            Text(
                                viewModel.localizeServerText(campaign.dateLabel),
                                color = MarviColor.Graphite,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                        TextButton(onClick = { campaignPendingDelete = campaign }) {
                            Text(viewModel.t(MarviL10n.Key.DELETE), color = MarviColor.Tomato)
                        }
                    }
                }
            }

            campaignPendingDelete?.let { pending ->
                item {
                    androidx.compose.material3.AlertDialog(
                        onDismissRequest = { campaignPendingDelete = null },
                        title = { Text(viewModel.t(MarviL10n.Key.DELETE)) },
                        text = { Text(viewModel.t(MarviL10n.Key.DELETE_CAMPAIGN_CONFIRM)) },
                        confirmButton = {
                            TextButton(
                                onClick = {
                                    scope.launch {
                                        val ok = viewModel.deleteCampaign(pending.id)
                                        campaignPendingDelete = null
                                        deleteFeedback = if (ok) {
                                            viewModel.t(MarviL10n.Key.CAMPAIGN_DELETED)
                                        } else {
                                            viewModel.lastSyncError
                                        }
                                    }
                                }
                            ) {
                                Text(viewModel.t(MarviL10n.Key.DELETE), color = MarviColor.Tomato)
                            }
                        },
                        dismissButton = {
                            TextButton(onClick = { campaignPendingDelete = null }) {
                                Text(viewModel.t(MarviL10n.Key.CANCEL))
                            }
                        }
                    )
                }
            }

            if (pendingConfirmations.isNotEmpty()) {
                item {
                    Text(
                        viewModel.t(MarviL10n.Key.PENDING_VENUE_CONFIRM),
                        fontWeight = FontWeight.SemiBold,
                        color = MarviColor.Ink,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                    Text(
                        viewModel.t(MarviL10n.Key.PENDING_VENUE_CONFIRM_SUB),
                        color = MarviColor.Muted,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
                items(pendingConfirmations, key = { "confirm-${it.id}" }) { booking ->
                    MarviCard {
                        Text(booking.offer.title, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                        Text(
                            booking.offer.venue.ifBlank { booking.offer.area },
                            color = MarviColor.Muted,
                            style = MaterialTheme.typography.bodySmall
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(
                                onClick = { viewModel.venueConfirmBooking(booking.id) },
                                colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Emerald),
                                modifier = Modifier.weight(1f)
                            ) {
                                Text(viewModel.t(MarviL10n.Key.CONFIRM_COLLABORATION))
                            }
                            OutlinedButton(
                                onClick = { viewModel.venueDeclineBooking(booking.id) },
                                modifier = Modifier.weight(1f)
                            ) {
                                Text(viewModel.t(MarviL10n.Key.DECLINE))
                            }
                        }
                    }
                }
            }

            item {
                Text(
                    viewModel.t(MarviL10n.Key.MATCH_CREATORS_TITLE),
                    fontWeight = FontWeight.SemiBold,
                    color = MarviColor.Ink,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
            if (!hasLiveCampaign) {
                item {
                    MarviCard {
                        Text(viewModel.t(MarviL10n.Key.SWIPE_NEEDS_LIVE_TITLE), fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                        Text(viewModel.t(MarviL10n.Key.SWIPE_NEEDS_LIVE_SUB), color = MarviColor.Muted)
                    }
                }
            } else if (viewModel.swipeCandidates.isEmpty()) {
                item {
                    Text(viewModel.t(MarviL10n.Key.NO_CANDIDATES), color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                }
            } else {
                items(viewModel.swipeCandidates, key = { it.id }) { candidate ->
                    MarviCard {
                        Text(candidate.name, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                        Text(
                            "${candidate.niche} · ${candidate.followers}",
                            color = MarviColor.Muted,
                            style = MaterialTheme.typography.bodySmall
                        )
                        Text(
                            "${viewModel.t(MarviL10n.Key.SCORE_LABEL)} ${candidate.score} · ${viewModel.t(MarviL10n.Key.PUNCTUALITY)} ${candidate.punctuality} · ${viewModel.t(MarviL10n.Key.PRESENTATION)} ${candidate.presentation}",
                            color = MarviColor.Graphite,
                            style = MaterialTheme.typography.bodySmall
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                            Button(
                                onClick = { viewModel.shortlistCreator(candidate.id) },
                                colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Emerald)
                            ) { Text(viewModel.t(MarviL10n.Key.SHORTLIST)) }
                            OutlinedButton(onClick = { viewModel.passCreator(candidate.id) }) {
                                Text(viewModel.t(MarviL10n.Key.PASS))
                            }
                        }
                    }
                }
            }

            item {
                Text(
                    viewModel.t(MarviL10n.Key.REVIEW_QUEUE_TITLE),
                    fontWeight = FontWeight.SemiBold,
                    color = MarviColor.Ink,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
            if (viewModel.venueReviewQueue.isEmpty()) {
                item {
                    Text(viewModel.t(MarviL10n.Key.NO_REVIEWS), color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                }
            } else {
                items(viewModel.venueReviewQueue, key = { it.id }) { review ->
                    VenueReviewCard(review, viewModel)
                }
            }
        }
    }
}

@Composable
private fun VenueReviewCard(review: com.marvisociety.app.data.VenueReviewItem, viewModel: AppViewModel) {
    var punctuality by remember(review.id) { mutableIntStateOf(4) }
    var presentation by remember(review.id) { mutableIntStateOf(4) }
    var comment by remember(review.id) { mutableStateOf("") }
    var expanded by remember(review.id) { mutableStateOf(false) }
    var submitting by remember(review.id) { mutableStateOf(false) }

    MarviCard {
        Text(review.creatorName.ifBlank { "@${review.instagramHandle}" }, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
        Text(review.offerTitle, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
        Text(
            listOf(review.stageLabel, review.checkedInLabel).filter { it.isNotBlank() }.joinToString(" · "),
            color = MarviColor.Graphite,
            style = MaterialTheme.typography.bodySmall
        )
        if (review.hasReview) {
            Text(viewModel.t(MarviL10n.Key.REVIEWED), color = MarviColor.Emerald, fontWeight = FontWeight.SemiBold)
        } else if (!expanded) {
            Button(
                onClick = { expanded = true },
                modifier = Modifier.padding(top = 6.dp),
                colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
            ) { Text(viewModel.t(MarviL10n.Key.RATE_CREATOR)) }
        } else {
            RatingRow(viewModel.t(MarviL10n.Key.PUNCTUALITY), punctuality) { punctuality = it }
            RatingRow(viewModel.t(MarviL10n.Key.PRESENTATION), presentation) { presentation = it }
            OutlinedTextField(
                value = comment,
                onValueChange = { comment = it },
                label = { Text(viewModel.t(MarviL10n.Key.REVIEW_COMMENT)) },
                modifier = Modifier.fillMaxWidth()
            )
            Button(
                onClick = {
                    submitting = true
                    viewModel.submitVenueReview(review.id, punctuality, presentation, comment.trim()) { succeeded ->
                        submitting = false
                        if (succeeded) expanded = false
                    }
                },
                enabled = !submitting,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Emerald)
            ) {
                Text(
                    if (submitting) {
                        viewModel.t(MarviL10n.Key.SUBMITTING)
                    } else {
                        viewModel.t(MarviL10n.Key.SUBMIT_REVIEW)
                    }
                )
            }
        }
    }
}

@Composable
private fun RatingRow(label: String, value: Int, onChange: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(label, color = MarviColor.Graphite, modifier = Modifier.weight(1f))
        (1..5).forEach { star ->
            Text(
                if (star <= value) "★" else "☆",
                color = MarviColor.Gold,
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.clickable { onChange(star) }
            )
        }
    }
}
