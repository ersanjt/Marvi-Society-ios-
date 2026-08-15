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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.marvisociety.app.data.ChatConversation
import com.marvisociety.app.data.ChatMessage
import com.marvisociety.app.data.CollaborationModel
import com.marvisociety.app.data.Offer
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.OfferImagery
import com.marvisociety.app.ui.components.ChatBubble
import com.marvisociety.app.ui.components.EmptyStateView
import com.marvisociety.app.ui.components.InfoBadge
import com.marvisociety.app.ui.components.MarviActionSheet
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.components.MarviTextField
import com.marvisociety.app.ui.components.MetricTile
import com.marvisociety.app.ui.components.OfferImageView
import com.marvisociety.app.ui.components.PrimaryActionButton
import com.marvisociety.app.ui.components.ProgressBar
import com.marvisociety.app.ui.components.SecondaryActionButton
import com.marvisociety.app.ui.components.StatusPill
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.theme.MarviGradient
import com.marvisociety.app.ui.viewmodel.AppViewModel
import kotlinx.coroutines.launch

@Composable
fun OfferDetailScreen(offer: Offer, viewModel: AppViewModel, onBack: () -> Unit) {
    val accepted = offer.id in viewModel.acceptedOfferIds
    val saved = offer.id in viewModel.savedOfferIds
    val filled = if (offer.capacity > 0) {
        (offer.capacity - offer.remaining).toFloat() / offer.capacity.toFloat()
    } else 0f

    var showShippingDialog by remember { mutableStateOf(false) }
    var showRsvpDialog by remember { mutableStateOf(false) }
    var showCancelDialog by remember { mutableStateOf(false) }
    var shippingAddress by remember { mutableStateOf("") }
    var rsvpGuests by remember { mutableIntStateOf(2) }
    var isAccepting by remember { mutableStateOf(false) }
    var isCancelling by remember { mutableStateOf(false) }

    fun beginAccept() {
        when (offer.collaborationModel) {
            CollaborationModel.GIFT -> showShippingDialog = true
            CollaborationModel.EVENT -> showRsvpDialog = true
            else -> {
                isAccepting = true
                viewModel.acceptOffer(offer.id) { succeeded ->
                    isAccepting = false
                    if (succeeded) onBack()
                }
            }
        }
    }

    val acceptTitle = when {
        offer.collaborationModel == CollaborationModel.INSTANT -> viewModel.t(MarviL10n.Key.USE_NOW)
        offer.collaborationModel == CollaborationModel.EVENT -> viewModel.t(MarviL10n.Key.RSVP_EVENT)
        offer.collaborationModel == CollaborationModel.GIFT -> viewModel.t(MarviL10n.Key.CONFIRM_GIFT)
        else -> viewModel.t(MarviL10n.Key.ACCEPT_INVITATION)
    }

    MarviScreen {
        Column(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(MarviColor.Panel)
                        .border(1.dp, MarviColor.Border, RoundedCornerShape(16.dp))
                ) {
                    Column {
                        Box {
                            OfferImageView(
                                url = OfferImagery.imageUrl(offer),
                                contentDescription = offer.title,
                                modifier = Modifier.fillMaxWidth(),
                                height = 190.dp,
                                cornerRadius = 0.dp
                            )
                            Box(
                                modifier = Modifier
                                    .matchParentSize()
                                    .background(MarviGradient.HeroOverlay)
                            )
                            IconButton(
                                onClick = onBack,
                                modifier = Modifier
                                    .align(Alignment.TopStart)
                                    .padding(8.dp)
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(MarviColor.Panel.copy(alpha = 0.85f))
                            ) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = MarviColor.Ink)
                            }
                            Row(
                                modifier = Modifier
                                    .align(Alignment.TopStart)
                                    .padding(start = 52.dp, top = 14.dp, end = 14.dp),
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                StatusPill(viewModel.categoryLabel(offer.category), MarviColor.Rose)
                                StatusPill(viewModel.modelLabel(offer.collaborationModel), MarviColor.Gold)
                                if (accepted) StatusPill(viewModel.t(MarviL10n.Key.CONFIRMED_STATUS), MarviColor.Emerald)
                            }
                        }
                        Column(
                            modifier = Modifier.padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Text(
                                offer.title,
                                style = MaterialTheme.typography.displaySmall,
                                color = MarviColor.Ink,
                                fontWeight = FontWeight.Bold,
                                maxLines = 2
                            )
                            Text(
                                "${offer.venue} · ${offer.area}",
                                style = MaterialTheme.typography.titleMedium,
                                color = MarviColor.Muted,
                                fontWeight = FontWeight.SemiBold
                            )
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                if (viewModel.profile.score > 0) {
                                    StatusPill(
                                        viewModel.tf(MarviL10n.Key.MATCH_PERCENT, viewModel.profile.score),
                                        MarviColor.Gold
                                    )
                                }
                                StatusPill(
                                    viewModel.tf(MarviL10n.Key.SLOTS_LEFT, offer.remaining),
                                    MarviColor.Rose
                                )
                                Spacer(Modifier.weight(1f))
                                IconButton(
                                    onClick = { viewModel.toggleSaved(offer.id) },
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(MarviColor.PanelElevated)
                                ) {
                                    Icon(
                                        if (saved) Icons.Default.Bookmark else Icons.Default.BookmarkBorder,
                                        null,
                                        tint = if (saved) MarviColor.Rose else MarviColor.Muted
                                    )
                                }
                            }
                        }
                    }
                }

                MarviCard {
                    Text(viewModel.t(MarviL10n.Key.CAMPAIGN_BRIEF), style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
                    if (offer.description.isNotBlank()) {
                        Text(offer.description, style = MaterialTheme.typography.bodyMedium, color = MarviColor.Graphite)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                        Box(modifier = Modifier.weight(1f)) {
                            MetricTile(
                                viewModel.localizeServerText(offer.dateLabel).ifBlank { viewModel.t(MarviL10n.Key.VALUE_TBD) },
                                viewModel.t(MarviL10n.Key.METRIC_DATE),
                                MarviColor.Rose
                            )
                        }
                        Box(modifier = Modifier.weight(1f)) {
                            MetricTile(
                                viewModel.localizeServerText(offer.timeLabel).ifBlank { viewModel.t(MarviL10n.Key.VALUE_FLEXIBLE) },
                                viewModel.t(MarviL10n.Key.METRIC_TIME),
                                MarviColor.Aubergine
                            )
                        }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                        Box(modifier = Modifier.weight(1f)) {
                            MetricTile(offer.valueLabel, viewModel.t(MarviL10n.Key.METRIC_VALUE), MarviColor.Gold)
                        }
                        Box(modifier = Modifier.weight(1f)) {
                            MetricTile("${offer.remaining}/${offer.capacity}", viewModel.t(MarviL10n.Key.METRIC_SLOTS), MarviColor.Emerald)
                        }
                    }
                    Text(viewModel.t(MarviL10n.Key.CAPACITY), style = MaterialTheme.typography.labelMedium, color = MarviColor.Muted)
                    ProgressBar(filled)
                }

                if (offer.deliverables.isNotEmpty()) {
                    MarviCard {
                        Text(viewModel.t(MarviL10n.Key.DELIVERABLES_TITLE), style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink)
                        offer.deliverables.forEach { Text("• $it", color = MarviColor.Graphite, style = MaterialTheme.typography.bodyMedium) }
                    }
                }
                if (offer.requirements.isNotEmpty()) {
                    MarviCard {
                        Text(viewModel.t(MarviL10n.Key.REQUIREMENTS_TITLE), style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink)
                        offer.requirements.forEach { Text("• $it", color = MarviColor.Graphite, style = MaterialTheme.typography.bodyMedium) }
                    }
                }
                if (offer.hostNote.isNotBlank()) {
                    MarviCard {
                        Text(viewModel.t(MarviL10n.Key.HOST_NOTE_TITLE), style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink)
                        Text(offer.hostNote, color = MarviColor.Graphite, style = MaterialTheme.typography.bodyMedium)
                    }
                }

                MarviCard {
                    Text(viewModel.t(MarviL10n.Key.ACCEPTANCE_TERMS), style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
                    TermRow(viewModel.t(MarviL10n.Key.TERM_ATTENDANCE), viewModel.t(MarviL10n.Key.TERM_ATTENDANCE_VAL))
                    TermRow(viewModel.t(MarviL10n.Key.TERM_CONTENT), viewModel.t(MarviL10n.Key.TERM_CONTENT_VAL))
                    TermRow(viewModel.t(MarviL10n.Key.TERM_POLICY), viewModel.t(MarviL10n.Key.TERM_POLICY_VAL))
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    InfoBadge(viewModel.categoryLabel(offer.category))
                    InfoBadge(viewModel.modelLabel(offer.collaborationModel))
                }

                Spacer(Modifier.height(80.dp))
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MarviColor.Panel.copy(alpha = 0.95f))
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                if (!accepted) {
                    val canAccept = viewModel.canAcceptOffers
                    viewModel.acceptBlockedReason?.takeIf { !canAccept }?.let { reason ->
                        Text(reason, color = MarviColor.Gold, style = MaterialTheme.typography.bodySmall)
                    }
                    PrimaryActionButton(
                        title = acceptTitle,
                        onClick = { beginAccept() },
                        enabled = canAccept && !isAccepting
                    )
                } else {
                    PrimaryActionButton(
                        title = viewModel.t(MarviL10n.Key.CANCEL_INVITATION),
                        onClick = { showCancelDialog = true },
                        enabled = !isCancelling
                    )
                }
            }
        }

        if (showShippingDialog) {
            MarviActionSheet(
                title = viewModel.t(MarviL10n.Key.CONFIRM_GIFT),
                subtitle = viewModel.t(MarviL10n.Key.EXTRAS_REQUIRED_SUB),
                onDismiss = { if (!isAccepting) showShippingDialog = false },
                confirmTitle = viewModel.t(MarviL10n.Key.CONFIRM_GIFT),
                confirmEnabled = shippingAddress.isNotBlank() && !isAccepting,
                onConfirm = {
                    isAccepting = true
                    viewModel.acceptOffer(offer.id, shippingAddress = shippingAddress) { succeeded ->
                        isAccepting = false
                        if (succeeded) {
                            showShippingDialog = false
                            onBack()
                        }
                    }
                },
                dismissTitle = viewModel.t(MarviL10n.Key.CANCEL)
            ) {
                MarviTextField(
                    value = shippingAddress,
                    onValueChange = { shippingAddress = it },
                    placeholder = viewModel.t(MarviL10n.Key.SHIPPING_ADDRESS),
                    singleLine = false
                )
            }
        }

        if (showRsvpDialog) {
            MarviActionSheet(
                title = viewModel.t(MarviL10n.Key.RSVP_EVENT),
                onDismiss = { if (!isAccepting) showRsvpDialog = false },
                confirmTitle = viewModel.t(MarviL10n.Key.RSVP_EVENT),
                confirmEnabled = !isAccepting,
                onConfirm = {
                    isAccepting = true
                    viewModel.acceptOffer(offer.id, rsvpGuests = rsvpGuests) { succeeded ->
                        isAccepting = false
                        if (succeeded) {
                            showRsvpDialog = false
                            onBack()
                        }
                    }
                },
                dismissTitle = viewModel.t(MarviL10n.Key.CANCEL)
            ) {
                Text(
                    "${viewModel.t(MarviL10n.Key.GUEST_COUNT)}: $rsvpGuests",
                    color = MarviColor.Ink,
                    style = MaterialTheme.typography.titleMedium
                )
                Slider(
                    value = rsvpGuests.toFloat(),
                    onValueChange = { rsvpGuests = it.toInt() },
                    valueRange = 1f..6f,
                    steps = 4,
                    colors = SliderDefaults.colors(
                        thumbColor = MarviColor.Rose,
                        activeTrackColor = MarviColor.Rose,
                        inactiveTrackColor = MarviColor.Border
                    )
                )
            }
        }

        if (showCancelDialog) {
            MarviActionSheet(
                title = viewModel.t(MarviL10n.Key.CANCEL_INVITATION_Q),
                subtitle = viewModel.t(MarviL10n.Key.VENUE_NOTIFIED_CANCEL),
                onDismiss = { if (!isCancelling) showCancelDialog = false },
                confirmTitle = viewModel.t(MarviL10n.Key.CANCEL_INVITATION),
                confirmEnabled = !isCancelling,
                confirmDestructive = true,
                onConfirm = {
                    viewModel.bookings.firstOrNull { it.offer.id == offer.id }?.let {
                        isCancelling = true
                        viewModel.cancelBooking(it.id) { succeeded ->
                            isCancelling = false
                            if (succeeded) {
                                showCancelDialog = false
                                onBack()
                            }
                        }
                    }
                },
                dismissTitle = viewModel.t(MarviL10n.Key.KEEP_BTN)
            )
        }
    }
}

@Composable
fun DirectChatScreen(
    threadId: String,
    peerName: String,
    viewModel: AppViewModel,
    onBack: () -> Unit
) {
    var messages by remember { mutableStateOf(emptyList<ChatMessage>()) }
    var draft by remember { mutableStateOf("") }
    var chatError by remember { mutableStateOf<String?>(null) }
    var isSending by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(threadId) {
        runCatching { messages = viewModel.fetchDirectMessages(threadId) }
            .onFailure { chatError = it.message }
    }

    MarviScreen {
        Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = MarviColor.Ink)
                }
                Text(peerName, style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
            }
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(messages, key = { it.id }) { msg ->
                    ChatBubble(body = msg.body, isMine = msg.isMine, timeLabel = msg.createdLabel)
                }
            }
            MarviTextField(
                value = draft,
                onValueChange = { draft = it },
                placeholder = viewModel.t(MarviL10n.Key.MESSAGE)
            )
            chatError?.let { Text(it, color = MarviColor.Tomato, style = MaterialTheme.typography.bodySmall) }
            PrimaryActionButton(
                title = viewModel.t(MarviL10n.Key.SEND),
                onClick = {
                    val body = draft.trim()
                    if (body.isEmpty()) return@PrimaryActionButton
                    chatError = null
                    isSending = true
                    scope.launch {
                        runCatching {
                            val msg = viewModel.sendDirectMessage(threadId, body)
                            messages = messages + msg
                            if (draft.trim() == body) draft = ""
                        }.onFailure { chatError = it.message }
                        isSending = false
                    }
                },
                enabled = draft.isNotBlank() && !isSending
            )
        }
    }
}

@Composable
fun CollaborationChatScreen(
    viewModel: AppViewModel,
    onOpenConversation: (ChatConversation) -> Unit,
    onBack: () -> Unit
) {
    LaunchedEffect(Unit) { viewModel.loadConversations() }

    MarviScreen {
        Column(
            modifier = Modifier.fillMaxSize().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = MarviColor.Ink)
                }
                Text(
                    viewModel.t(MarviL10n.Key.MESSAGES_TITLE),
                    style = MaterialTheme.typography.headlineSmall,
                    color = MarviColor.Ink,
                    fontWeight = FontWeight.Bold
                )
            }

            if (viewModel.conversations.isEmpty()) {
                EmptyStateView(
                    title = viewModel.t(MarviL10n.Key.NO_MESSAGES_YET),
                    subtitle = viewModel.t(MarviL10n.Key.NO_MESSAGES_YET_SUB)
                )
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(viewModel.conversations, key = { it.id }) { convo ->
                        MarviCard(modifier = Modifier.clickable { onOpenConversation(convo) }) {
                            Text(
                                convo.title,
                                style = MaterialTheme.typography.titleMedium,
                                color = MarviColor.Ink,
                                fontWeight = FontWeight.Bold
                            )
                            Text(
                                convo.preview,
                                style = MaterialTheme.typography.bodySmall,
                                color = MarviColor.Muted,
                                maxLines = 2
                            )
                            if (convo.lastMessageAt.isNotBlank()) {
                                Text(
                                    convo.lastMessageAt,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MarviColor.Graphite
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun CollaborationThreadScreen(
    conversationId: String,
    title: String,
    viewModel: AppViewModel,
    onBack: () -> Unit
) {
    var messages by remember { mutableStateOf(emptyList<ChatMessage>()) }
    var draft by remember { mutableStateOf("") }
    var chatError by remember { mutableStateOf<String?>(null) }
    var isSending by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(conversationId) {
        runCatching { messages = viewModel.fetchConversationMessages(conversationId) }
            .onFailure { chatError = it.message }
    }

    MarviScreen {
        Column(modifier = Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = MarviColor.Ink)
                }
                Text(title, style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
            }
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(messages, key = { it.id }) { msg ->
                    ChatBubble(body = msg.body, isMine = msg.isMine, timeLabel = msg.createdLabel)
                }
            }
            MarviTextField(
                value = draft,
                onValueChange = { draft = it },
                placeholder = viewModel.t(MarviL10n.Key.MESSAGE)
            )
            chatError?.let { Text(it, color = MarviColor.Tomato, style = MaterialTheme.typography.bodySmall) }
            PrimaryActionButton(
                title = viewModel.t(MarviL10n.Key.SEND),
                onClick = {
                    val body = draft.trim()
                    if (body.isEmpty()) return@PrimaryActionButton
                    chatError = null
                    isSending = true
                    scope.launch {
                        runCatching {
                            val msg = viewModel.sendConversationMessage(conversationId, body)
                            messages = messages + msg
                            if (draft.trim() == body) draft = ""
                        }.onFailure { chatError = it.message }
                        isSending = false
                    }
                },
                enabled = draft.isNotBlank() && !isSending
            )
        }
    }
}


@Composable
private fun TermRow(title: String, value: String) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp), modifier = Modifier.fillMaxWidth()) {
        Text(title, color = MarviColor.Ink, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
        Text(value, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
    }
}
