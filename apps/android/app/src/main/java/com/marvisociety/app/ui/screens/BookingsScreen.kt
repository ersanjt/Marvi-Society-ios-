package com.marvisociety.app.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.unit.dp
import com.marvisociety.app.data.Booking
import com.marvisociety.app.data.BookingStage
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.OfferImagery
import com.marvisociety.app.ui.components.EmptyStateView
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.components.MarviTextField
import com.marvisociety.app.ui.components.OfferImageView
import com.marvisociety.app.ui.components.PrimaryActionButton
import com.marvisociety.app.ui.components.SecondaryActionButton
import com.marvisociety.app.ui.components.StatusPill
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel

@Composable
fun BookingsScreen(viewModel: AppViewModel) {
    MarviScreen {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp)
                .padding(top = 8.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Text(
                viewModel.t(MarviL10n.Key.MY_EVENTS_TITLE),
                style = MaterialTheme.typography.displayLarge,
                color = MarviColor.Ink
            )
            Text(
                viewModel.t(MarviL10n.Key.NO_BOOKINGS_SUB),
                style = MaterialTheme.typography.bodyMedium,
                color = MarviColor.Muted
            )

            if (viewModel.bookings.isEmpty()) {
                EmptyStateView(
                    title = viewModel.t(MarviL10n.Key.NO_BOOKINGS),
                    subtitle = viewModel.t(MarviL10n.Key.NO_BOOKINGS_SUB)
                )
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(14.dp)) {
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
    var screenshotUri by remember(booking.id) { mutableStateOf<Uri?>(null) }

    val photoPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri -> screenshotUri = uri }

    MarviCard {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top
        ) {
            OfferImageView(
                url = OfferImagery.imageUrl(booking.offer),
                contentDescription = booking.offer.title,
                modifier = Modifier.size(72.dp, 80.dp),
                height = 80.dp,
                cornerRadius = 12.dp
            )
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(booking.offer.title, style = MaterialTheme.typography.titleMedium, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
                Text("${booking.offer.venue} · ${booking.offer.area}", style = MaterialTheme.typography.bodySmall, color = MarviColor.Muted)
                StatusPill(viewModel.stageLabel(booking.stage), stageTint(booking.stage))
                if (booking.proofDeadline.isNotEmpty()) {
                    Text(booking.proofDeadline, style = MaterialTheme.typography.bodySmall, color = MarviColor.Graphite)
                }
            }
        }

        when (booking.stage) {
            BookingStage.INVITED -> {
                val canAccept = viewModel.canAcceptOffers
                viewModel.acceptBlockedReason?.takeIf { !canAccept }?.let { reason ->
                    Text(reason, color = MarviColor.Gold, style = MaterialTheme.typography.bodySmall)
                }
                PrimaryActionButton(
                    title = viewModel.t(MarviL10n.Key.ACCEPT_INVITATION),
                    onClick = { viewModel.acceptOffer(booking.offer.id) },
                    enabled = canAccept
                )
            }
            BookingStage.CONFIRMED -> {
                MarviTextField(
                    value = checkInCode,
                    onValueChange = { checkInCode = it },
                    placeholder = viewModel.t(MarviL10n.Key.CHECK_IN)
                )
                PrimaryActionButton(
                    title = viewModel.t(MarviL10n.Key.CHECK_IN),
                    onClick = { viewModel.checkIn(booking.id, checkInCode) },
                    enabled = checkInCode.isNotBlank()
                )
            }
            BookingStage.CHECKED_IN, BookingStage.PROOF_DUE -> {
                MarviTextField(
                    value = proofText,
                    onValueChange = { proofText = it },
                    placeholder = viewModel.t(MarviL10n.Key.PROOF_LINKS),
                    singleLine = false
                )
                SecondaryActionButton(
                    title = if (screenshotUri != null) {
                        viewModel.t(MarviL10n.Key.PROOF_SCREENSHOT_ATTACHED)
                    } else {
                        viewModel.t(MarviL10n.Key.PROOF_ADD_SCREENSHOT)
                    },
                    onClick = {
                        photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    }
                )
                PrimaryActionButton(
                    title = viewModel.t(MarviL10n.Key.SUBMIT_PROOF),
                    onClick = {
                        viewModel.submitProof(
                            booking.id,
                            proofText.lines().map { it.trim() }.filter { it.isNotEmpty() },
                            screenshotUri
                        )
                    }
                )
            }
            else -> Unit
        }
    }
}

private fun stageTint(stage: BookingStage) = when (stage) {
    BookingStage.INVITED -> MarviColor.Gold
    BookingStage.CONFIRMED -> MarviColor.Emerald
    BookingStage.CHECKED_IN -> MarviColor.Blue
    BookingStage.PROOF_DUE -> MarviColor.Tomato
    BookingStage.COMPLETED -> MarviColor.Aubergine
    BookingStage.CANCELLED -> MarviColor.Muted
}
