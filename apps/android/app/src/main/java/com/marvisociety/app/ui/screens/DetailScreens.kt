package com.marvisociety.app.ui.screens

import androidx.compose.foundation.background
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
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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
import com.marvisociety.app.data.ChatMessage
import com.marvisociety.app.data.Offer
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.OfferImagery
import com.marvisociety.app.ui.components.InfoBadge
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
    val filled = if (offer.capacity > 0) {
        (offer.capacity - offer.remaining).toFloat() / offer.capacity.toFloat()
    } else 0f

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
                ) {
                    OfferImageView(
                        url = OfferImagery.imageUrl(offer),
                        contentDescription = offer.title,
                        modifier = Modifier.fillMaxWidth(),
                        height = 190.dp,
                        cornerRadius = 16.dp
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
                            .align(Alignment.TopEnd)
                            .padding(12.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        StatusPill(viewModel.modelLabel(offer.collaborationModel), MarviColor.Rose)
                        StatusPill("${offer.remaining} ${viewModel.t(MarviL10n.Key.SLOTS_SUFFIX)}", MarviColor.Gold)
                    }
                    Column(
                        modifier = Modifier
                            .align(Alignment.BottomStart)
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(offer.venue, style = MaterialTheme.typography.labelMedium, color = MarviColor.Rose, fontWeight = FontWeight.Bold)
                        Text(offer.title, style = MaterialTheme.typography.displaySmall, color = Color.White)
                        Text("${offer.area} · ${offer.dateLabel}", style = MaterialTheme.typography.bodySmall, color = Color.White.copy(alpha = 0.85f))
                    }
                }

                MarviCard {
                    if (offer.description.isNotBlank()) {
                        Text(offer.description, style = MaterialTheme.typography.bodyMedium, color = MarviColor.Graphite)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                        Box(modifier = Modifier.weight(1f)) {
                            MetricTile(offer.dateLabel.ifBlank { viewModel.t(MarviL10n.Key.VALUE_TBD) }, viewModel.t(MarviL10n.Key.METRIC_DATE), MarviColor.Rose)
                        }
                        Box(modifier = Modifier.weight(1f)) {
                            MetricTile(offer.timeLabel.ifBlank { viewModel.t(MarviL10n.Key.VALUE_FLEXIBLE) }, viewModel.t(MarviL10n.Key.METRIC_TIME), MarviColor.Aubergine)
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
                        title = viewModel.t(MarviL10n.Key.ACCEPT_INVITATION),
                        onClick = { viewModel.acceptOffer(offer.id); onBack() },
                        enabled = canAccept,
                        icon = Icons.Default.Check
                    )
                } else {
                    StatusPill(viewModel.t(MarviL10n.Key.ALREADY_ACCEPTED), MarviColor.Emerald)
                }
                SecondaryActionButton(title = viewModel.t(MarviL10n.Key.CLOSE), onClick = onBack)
            }
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
    val scope = rememberCoroutineScope()

    LaunchedEffect(threadId) {
        runCatching { messages = viewModel.fetchDirectMessages(threadId) }
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
                    val bubbleColor = if (msg.isMine) MarviColor.Rose.copy(alpha = 0.18f) else MarviColor.PanelElevated
                    val textColor = if (msg.isMine) MarviColor.Rose else MarviColor.Ink
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(14.dp))
                            .background(bubbleColor)
                            .padding(12.dp),
                        horizontalAlignment = if (msg.isMine) Alignment.End else Alignment.Start
                    ) {
                        Text(msg.body, color = textColor, style = MaterialTheme.typography.bodyMedium)
                        Text(msg.createdLabel, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
            MarviTextField(
                value = draft,
                onValueChange = { draft = it },
                placeholder = viewModel.t(MarviL10n.Key.MESSAGE)
            )
            PrimaryActionButton(
                title = viewModel.t(MarviL10n.Key.SEND),
                onClick = {
                    val body = draft.trim()
                    if (body.isEmpty()) return@PrimaryActionButton
                    draft = ""
                    scope.launch {
                        runCatching {
                            val msg = viewModel.sendDirectMessage(threadId, body)
                            messages = messages + msg
                        }
                    }
                }
            )
        }
    }
}
