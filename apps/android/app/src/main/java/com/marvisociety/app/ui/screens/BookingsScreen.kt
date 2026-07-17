package com.marvisociety.app.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Message
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import com.marvisociety.app.data.PendingCollaborationRequest
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
import com.marvisociety.app.ui.theme.MarviGradient
import com.marvisociety.app.ui.viewmodel.AppViewModel

@Composable
fun BookingsScreen(viewModel: AppViewModel, onOpenMessages: () -> Unit = {}) {
    var rateBooking by remember { mutableStateOf<Booking?>(null) }
    var selectedBucket by remember { mutableStateOf(BookingBucket.REQUESTS) }

    val pendingRequests = viewModel.pendingCollaborationRequests.filter { it.isPendingCreator }
    val counts = mapOf(
        BookingBucket.REQUESTS to pendingRequests.size + viewModel.bookings.count { it.stage == BookingStage.INVITED },
        BookingBucket.TO_CONFIRM to viewModel.bookings.count { it.stage == BookingStage.CONFIRMED },
        BookingBucket.TO_REVIEW to viewModel.bookings.count { it.stage == BookingStage.PROOF_DUE },
        BookingBucket.TO_VISIT to viewModel.bookings.count { it.stage == BookingStage.CHECKED_IN }
    )
    val requests = if (selectedBucket == BookingBucket.REQUESTS) pendingRequests else emptyList()
    val bookings = viewModel.bookings.filter { booking ->
        when (selectedBucket) {
            BookingBucket.REQUESTS -> booking.stage == BookingStage.INVITED
            BookingBucket.TO_CONFIRM -> booking.stage == BookingStage.CONFIRMED
            BookingBucket.TO_REVIEW -> booking.stage == BookingStage.PROOF_DUE
            BookingBucket.TO_VISIT -> booking.stage == BookingStage.CHECKED_IN
        }
    }

    MarviScreen {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp)
                .padding(top = 8.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Row(verticalAlignment = Alignment.Top) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        viewModel.t(MarviL10n.Key.MY_EVENTS_TITLE),
                        style = MaterialTheme.typography.displaySmall,
                        color = MarviColor.Ink
                    )
                    Text(
                        viewModel.t(MarviL10n.Key.NO_BOOKINGS_SUB),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MarviColor.Muted
                    )
                }
                IconButton(
                    onClick = onOpenMessages,
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(MarviColor.Panel)
                ) {
                    Icon(Icons.AutoMirrored.Filled.Message, null, tint = MarviColor.Ink)
                }
            }

            BookingStatusGrid(
                selected = selectedBucket,
                counts = counts,
                viewModel = viewModel,
                onSelect = { selectedBucket = it }
            )

            if (requests.isEmpty() && bookings.isEmpty()) {
                EmptyStateView(
                    title = viewModel.t(MarviL10n.Key.NO_BOOKINGS),
                    subtitle = viewModel.t(MarviL10n.Key.NO_BOOKINGS_SUB)
                )
            } else {
                LazyColumn(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    if (requests.isNotEmpty()) {
                        item {
                            Text(
                                viewModel.t(MarviL10n.Key.PENDING_INVITES_TITLE),
                                style = MaterialTheme.typography.headlineSmall,
                                color = MarviColor.Ink,
                                fontWeight = FontWeight.Bold
                            )
                        }
                        items(requests, key = { it.id }) { request ->
                            PendingCollaborationRequestCard(request, viewModel)
                        }
                    }
                    items(bookings, key = { it.id }) { booking ->
                        BookingCard(booking, viewModel, onRate = { rateBooking = booking })
                    }
                }
            }
        }

        rateBooking?.let { booking ->
            RateVenueDialog(
                booking = booking,
                viewModel = viewModel,
                onDismiss = { rateBooking = null }
            )
        }
    }
}

private enum class BookingBucket { REQUESTS, TO_CONFIRM, TO_REVIEW, TO_VISIT }

@Composable
private fun BookingStatusGrid(
    selected: BookingBucket,
    counts: Map<BookingBucket, Int>,
    viewModel: AppViewModel,
    onSelect: (BookingBucket) -> Unit
) {
    val items = listOf(
        Triple(BookingBucket.REQUESTS, MarviL10n.Key.REQUESTS, MarviColor.Rose),
        Triple(BookingBucket.TO_CONFIRM, MarviL10n.Key.TO_CONFIRM, MarviColor.Aubergine),
        Triple(BookingBucket.TO_REVIEW, MarviL10n.Key.TO_REVIEW, MarviColor.Gold),
        Triple(BookingBucket.TO_VISIT, MarviL10n.Key.TO_VISIT, MarviColor.Blue)
    )
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        items.chunked(2).forEach { rowItems ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                rowItems.forEach { (bucket, key, tint) ->
                    val isSelected = selected == bucket
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(14.dp))
                            .then(
                                if (isSelected) Modifier.background(MarviGradient.Brand)
                                else Modifier.background(MarviColor.Panel)
                            )
                            .then(
                                if (isSelected) Modifier
                                else Modifier.border(1.dp, MarviColor.Border, RoundedCornerShape(14.dp))
                            )
                            .clickable { onSelect(bucket) }
                            .padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text(
                            (counts[bucket] ?: 0).toString(),
                            style = MaterialTheme.typography.headlineLarge,
                            color = if (isSelected) androidx.compose.ui.graphics.Color.White else tint,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            viewModel.t(key),
                            style = MaterialTheme.typography.labelMedium,
                            color = if (isSelected) androidx.compose.ui.graphics.Color.White.copy(alpha = 0.9f) else MarviColor.Muted,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PendingCollaborationRequestCard(
    request: PendingCollaborationRequest,
    viewModel: AppViewModel
) {
    var isAccepting by remember(request.id) { mutableStateOf(false) }
    MarviCard {
        Text(
            viewModel.t(MarviL10n.Key.VENUE_INVITE_TITLE),
            style = MaterialTheme.typography.titleMedium,
            color = MarviColor.Ink,
            fontWeight = FontWeight.Bold
        )
        Text(
            viewModel.t(MarviL10n.Key.VENUE_INVITE_SUB),
            style = MaterialTheme.typography.bodySmall,
            color = MarviColor.Muted
        )
        Text(request.offerTitle, style = MaterialTheme.typography.bodyMedium, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
        if (request.venueName.isNotBlank()) {
            Text(request.venueName, style = MaterialTheme.typography.bodySmall, color = MarviColor.Muted)
        }
        PrimaryActionButton(
            title = if (isAccepting) {
                viewModel.t(MarviL10n.Key.SAVING)
            } else {
                viewModel.t(MarviL10n.Key.ACCEPT_VENUE_INVITE)
            },
            onClick = {
                isAccepting = true
                viewModel.creatorAcceptCollaboration(request.id)
            },
            enabled = !isAccepting
        )
    }
}

@Composable
private fun BookingCard(
    booking: Booking,
    viewModel: AppViewModel,
    onRate: () -> Unit
) {
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
                    Text(
                        viewModel.localizeServerText(booking.proofDeadline),
                        style = MaterialTheme.typography.bodySmall,
                        color = MarviColor.Graphite
                    )
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
                SecondaryActionButton(
                    title = viewModel.t(MarviL10n.Key.DECLINE),
                    onClick = { viewModel.cancelBooking(booking.id) }
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
                SecondaryActionButton(
                    title = viewModel.t(MarviL10n.Key.RATE_VENUE),
                    onClick = onRate
                )
            }
            BookingStage.COMPLETED -> {
                SecondaryActionButton(
                    title = viewModel.t(MarviL10n.Key.RATE_VENUE),
                    onClick = onRate
                )
            }
            else -> Unit
        }
    }
}

@Composable
private fun RateVenueDialog(
    booking: Booking,
    viewModel: AppViewModel,
    onDismiss: () -> Unit
) {
    var hospitality by remember { mutableIntStateOf(5) }
    var experience by remember { mutableIntStateOf(5) }
    var comment by remember { mutableStateOf("") }
    var isSubmitting by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = { if (!isSubmitting) onDismiss() },
        containerColor = MarviColor.Panel,
        title = { Text(viewModel.t(MarviL10n.Key.SHARE_THOUGHTS), color = MarviColor.Ink) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    "${booking.offer.venue} · ${booking.offer.title}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MarviColor.Muted
                )
                RatingRow(
                    label = "${viewModel.t(MarviL10n.Key.HOSPITALITY)}: $hospitality",
                    value = hospitality,
                    onChange = { hospitality = it }
                )
                RatingRow(
                    label = "${viewModel.t(MarviL10n.Key.EXPERIENCE)}: $experience",
                    value = experience,
                    onChange = { experience = it }
                )
                MarviTextField(
                    value = comment,
                    onValueChange = { comment = it },
                    placeholder = viewModel.t(MarviL10n.Key.OPTIONAL_NOTE),
                    singleLine = false
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    isSubmitting = true
                    viewModel.submitCreatorReview(
                        bookingId = booking.id,
                        hospitality = hospitality,
                        experience = experience,
                        comment = comment
                    ) { ok ->
                        isSubmitting = false
                        if (ok) onDismiss()
                    }
                },
                enabled = !isSubmitting
            ) {
                Text(
                    if (isSubmitting) viewModel.t(MarviL10n.Key.SUBMITTING) else viewModel.t(MarviL10n.Key.SUBMIT_REVIEW),
                    color = MarviColor.Rose
                )
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, enabled = !isSubmitting) {
                Text(viewModel.t(MarviL10n.Key.CANCEL), color = MarviColor.Muted)
            }
        }
    )
}

@Composable
private fun RatingRow(label: String, value: Int, onChange: (Int) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label, style = MaterialTheme.typography.titleMedium, color = MarviColor.Ink)
        Slider(
            value = value.toFloat(),
            onValueChange = { onChange(it.toInt().coerceIn(1, 5)) },
            valueRange = 1f..5f,
            steps = 3
        )
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
