package com.marvisociety.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.marvisociety.app.data.ChatMessage
import com.marvisociety.app.data.Offer
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.OfferImagery
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel
import kotlinx.coroutines.launch

@Composable
fun OfferDetailScreen(offer: Offer, viewModel: AppViewModel, onBack: () -> Unit) {
    val accepted = offer.id in viewModel.acceptedOfferIds
    MarviScreen {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            AsyncImage(
                model = OfferImagery.imageUrl(offer),
                contentDescription = offer.title,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(190.dp)
                    .clip(RoundedCornerShape(14.dp)),
                contentScale = ContentScale.Crop
            )
            Text(offer.title, style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
            Text("${offer.venue} · ${offer.area}", color = MarviColor.Muted)
            Text("${offer.dateLabel} ${offer.timeLabel}".trim(), color = MarviColor.Graphite)
            Text(offer.valueLabel, color = MarviColor.Rose, fontWeight = FontWeight.SemiBold)
            if (offer.description.isNotEmpty()) Text(offer.description, color = MarviColor.Ink)
            if (offer.deliverables.isNotEmpty()) {
                MarviCard {
                    Text(viewModel.t(MarviL10n.Key.DELIVERABLES_HINT), fontWeight = FontWeight.SemiBold, color = MarviColor.Ink)
                    offer.deliverables.forEach { Text("• $it", color = MarviColor.Graphite) }
                }
            }
            if (offer.requirements.isNotEmpty()) {
                MarviCard {
                    Text(viewModel.t(MarviL10n.Key.REQUIREMENTS_HINT), fontWeight = FontWeight.SemiBold, color = MarviColor.Ink)
                    offer.requirements.forEach { Text("• $it", color = MarviColor.Graphite) }
                }
            }
            if (offer.hostNote.isNotBlank()) {
                MarviCard {
                    Text(viewModel.t(MarviL10n.Key.HOST_NOTE), fontWeight = FontWeight.SemiBold, color = MarviColor.Ink)
                    Text(offer.hostNote, color = MarviColor.Graphite)
                }
            }
            if (!accepted) {
                val canAccept = viewModel.canAcceptOffers
                viewModel.acceptBlockedReason?.takeIf { !canAccept }?.let { reason ->
                    Text(reason, color = MarviColor.Gold, style = MaterialTheme.typography.bodySmall)
                }
                Button(
                    onClick = { viewModel.acceptOffer(offer.id); onBack() },
                    enabled = canAccept,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                ) { Text(viewModel.t(MarviL10n.Key.ACCEPT_INVITATION)) }
            } else {
                Text("Already accepted", color = MarviColor.Emerald)
            }
            Button(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
                Text(viewModel.t(MarviL10n.Key.CLOSE))
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
        Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
            Text(peerName, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(messages, key = { it.id }) { msg ->
                    MarviCard {
                        Text(msg.body, color = if (msg.isMine) MarviColor.Rose else MarviColor.Ink)
                        Text(msg.createdLabel, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
            OutlinedTextField(
                value = draft,
                onValueChange = { draft = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text(viewModel.t(MarviL10n.Key.MESSAGE)) }
            )
            Button(
                onClick = {
                    val body = draft.trim()
                    if (body.isEmpty()) return@Button
                    draft = ""
                    scope.launch {
                        runCatching {
                            val msg = viewModel.sendDirectMessage(threadId, body)
                            messages = messages + msg
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
            ) { Text(viewModel.t(MarviL10n.Key.SEND)) }
            Button(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
                Text(viewModel.t(MarviL10n.Key.CLOSE))
            }
        }
    }
}
