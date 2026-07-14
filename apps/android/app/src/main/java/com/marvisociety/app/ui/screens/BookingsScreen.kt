package com.marvisociety.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.marvisociety.app.data.Booking
import com.marvisociety.app.data.BookingStage
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel

@Composable
fun BookingsScreen(viewModel: AppViewModel) {
    MarviScreen {
        Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
            Text(
                viewModel.t(MarviL10n.Key.MY_EVENTS_TITLE),
                style = MaterialTheme.typography.headlineSmall,
                color = MarviColor.Ink,
                fontWeight = FontWeight.Bold
            )
            if (viewModel.bookings.isEmpty()) {
                MarviCard {
                    Text(viewModel.t(MarviL10n.Key.NO_BOOKINGS), fontWeight = FontWeight.SemiBold, color = MarviColor.Ink)
                    Text(viewModel.t(MarviL10n.Key.NO_BOOKINGS_SUB), color = MarviColor.Muted)
                }
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(viewModel.bookings, key = { it.id }) { booking ->
                        BookingCard(booking, viewModel)
                    }
                }
            }
        }
    }
}

@Composable
private fun BookingCard(booking: Booking, viewModel: AppViewModel) {
    var checkInCode by remember(booking.id) { mutableStateOf("") }
    var proofText by remember(booking.id) { mutableStateOf("") }

    MarviCard {
        Text(booking.offer.title, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
        Text("${booking.offer.venue} · ${stageLabel(booking.stage, viewModel)}", color = MarviColor.Muted)
        if (booking.proofDeadline.isNotEmpty()) {
            Text(booking.proofDeadline, color = MarviColor.Graphite, style = MaterialTheme.typography.bodySmall)
        }

        when (booking.stage) {
            BookingStage.INVITED -> {
                val canAccept = viewModel.canAcceptOffers
                viewModel.acceptBlockedReason?.takeIf { !canAccept }?.let { reason ->
                    Text(
                        reason,
                        color = MarviColor.Gold,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
                Button(
                    onClick = { viewModel.acceptOffer(booking.offer.id) },
                    enabled = canAccept,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                ) { Text(viewModel.t(MarviL10n.Key.ACCEPT_INVITATION)) }
            }
            BookingStage.CONFIRMED -> {
                OutlinedTextField(
                    value = checkInCode,
                    onValueChange = { checkInCode = it },
                    label = { Text(viewModel.t(MarviL10n.Key.CHECK_IN)) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp)
                )
                Button(
                    onClick = { viewModel.checkIn(booking.id, checkInCode) },
                    enabled = checkInCode.isNotBlank(),
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                ) { Text(viewModel.t(MarviL10n.Key.CHECK_IN)) }
            }
            BookingStage.CHECKED_IN, BookingStage.PROOF_DUE -> {
                OutlinedTextField(
                    value = proofText,
                    onValueChange = { proofText = it },
                    label = { Text(viewModel.t(MarviL10n.Key.PROOF_LINKS)) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    minLines = 2
                )
                Button(
                    onClick = {
                        viewModel.submitProof(
                            booking.id,
                            proofText.lines().map { it.trim() }.filter { it.isNotEmpty() }
                        )
                    },
                    enabled = proofText.isNotBlank(),
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                ) { Text(viewModel.t(MarviL10n.Key.SUBMIT_PROOF)) }
            }
            else -> Unit
        }
    }
}

private fun stageLabel(stage: BookingStage, viewModel: AppViewModel): String = when (stage) {
    BookingStage.INVITED -> viewModel.t(MarviL10n.Key.STAGE_INVITED)
    BookingStage.CONFIRMED -> viewModel.t(MarviL10n.Key.STAGE_CONFIRMED)
    BookingStage.CHECKED_IN -> viewModel.t(MarviL10n.Key.STAGE_CHECKED_IN)
    BookingStage.PROOF_DUE -> viewModel.t(MarviL10n.Key.STAGE_PROOF_DUE)
    BookingStage.COMPLETED -> viewModel.t(MarviL10n.Key.STAGE_COMPLETED)
    BookingStage.CANCELLED -> "Cancelled"
}
