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
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Message
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.ui.unit.sp
import com.marvisociety.app.data.Booking
import com.marvisociety.app.data.BookingStage
import com.marvisociety.app.data.PendingCollaborationRequest
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.OfferImagery
import com.marvisociety.app.ui.components.CircleIconButton
import com.marvisociety.app.ui.components.EmptyStateView
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.components.MarviTextField
import com.marvisociety.app.ui.components.OfferImageView
import com.marvisociety.app.ui.components.PrimaryActionButton
import com.marvisociety.app.ui.components.SSSelectableStatusGrid
import com.marvisociety.app.ui.components.SSToggleTabs
import com.marvisociety.app.ui.components.SecondaryActionButton
import com.marvisociety.app.ui.components.StatusBadgeUi
import com.marvisociety.app.ui.components.StatusPill
import com.marvisociety.app.ui.theme.NewsreaderFamily
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.theme.MarviGradient
import com.marvisociety.app.ui.viewmodel.AppViewModel

@Composable
fun BookingsScreen(viewModel: AppViewModel, onOpenMessages: () -> Unit = {}, onOpenInbox: () -> Unit = {}) {
    var rateBooking by remember { mutableStateOf<Booking?>(null) }
    var selectedBucket by remember { mutableStateOf<BookingBucket?>(null) }
    var isInterestMode by remember { mutableStateOf(false) }

    val pendingRequests = viewModel.pendingCollaborationRequests.filter { it.isPendingCreator }
    val badges = listOf(
        StatusBadgeUi("requests", viewModel.t(MarviL10n.Key.REQUESTS), pendingRequests.size + viewModel.bookings.count { it.stage == BookingStage.INVITED }, MarviColor.Rose),
        StatusBadgeUi("confirm", viewModel.t(MarviL10n.Key.TO_CONFIRM), viewModel.bookings.count { it.stage == BookingStage.CONFIRMED }, MarviColor.Aubergine),
        StatusBadgeUi("review", viewModel.t(MarviL10n.Key.TO_REVIEW), viewModel.bookings.count { it.stage == BookingStage.PROOF_DUE }, MarviColor.Gold),
        StatusBadgeUi("visit", viewModel.t(MarviL10n.Key.TO_VISIT), viewModel.bookings.count { it.stage == BookingStage.CHECKED_IN }, MarviColor.Blue)
    )
    val requests = if (!isInterestMode && (selectedBucket == null || selectedBucket == BookingBucket.REQUESTS)) pendingRequests else emptyList()
    val bookings = if (isInterestMode) emptyList() else viewModel.bookings.filter { booking ->
        when (selectedBucket) {
            BookingBucket.REQUESTS, null -> booking.stage == BookingStage.INVITED
            BookingBucket.TO_CONFIRM -> booking.stage == BookingStage.CONFIRMED
            BookingBucket.TO_REVIEW -> booking.stage == BookingStage.PROOF_DUE
            BookingBucket.TO_VISIT -> booking.stage == BookingStage.CHECKED_IN
        }
    }
    val interest = if (isInterestMode) viewModel.interestOffers else emptyList()

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
                        style = MaterialTheme.typography.displaySmall.copy(fontFamily = NewsreaderFamily, fontSize = 34.sp),
                        color = MarviColor.Ink,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        viewModel.t(MarviL10n.Key.MY_EVENTS_SUB),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MarviColor.Muted
                    )
                }
                CircleIconButton(Icons.AutoMirrored.Filled.Message, onClick = onOpenMessages)
                Spacer(Modifier.size(8.dp))
                CircleIconButton(Icons.Outlined.Notifications, onClick = onOpenInbox, badgeCount = viewModel.unreadInboxCount)
            }

            SSSelectableStatusGrid(
                badges = badges,
                selectedId = when (selectedBucket) {
                    BookingBucket.REQUESTS -> "requests"
                    BookingBucket.TO_CONFIRM -> "confirm"
                    BookingBucket.TO_REVIEW -> "review"
                    BookingBucket.TO_VISIT -> "visit"
                    null -> null
                },
                onSelect = { id ->
                    selectedBucket = when (id) {
                        "requests" -> BookingBucket.REQUESTS
                        "confirm" -> BookingBucket.TO_CONFIRM
                        "review" -> BookingBucket.TO_REVIEW
                        "visit" -> BookingBucket.TO_VISIT
                        else -> null
                    }
                }
            )

            SSToggleTabs(
                leftTitle = viewModel.t(MarviL10n.Key.PENDING_INVITES),
                rightTitle = viewModel.t(MarviL10n.Key.INTEREST_SHOWN),
                isRightSelected = isInterestMode,
                onSelectRight = { isInterestMode = it }
            )

            if (isInterestMode) {
                if (interest.isEmpty()) {
                    EmptyStateView(
                        title = viewModel.t(MarviL10n.Key.NO_BOOKINGS),
                        subtitle = viewModel.t(MarviL10n.Key.NO_BOOKINGS_SUB)
                    )
                } else {
                    LazyColumn(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        items(interest, key = { it.id }) { offer ->
                            MarviCard {
                                Text(offer.title, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
                                Text("${offer.venue} · ${offer.area}", color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                            }
                        }
                    }
                }
            } else if (requests.isEmpty() && bookings.isEmpty()) {
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
                                viewModel.t(MarviL10n.Key.PENDING_INVITES),
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
                viewModel.creatorAcceptCollaboration(request.id) { succeeded ->
                    if (!succeeded) isAccepting = false
                }
            },
            enabled = !isAccepting
        )
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedButton(
            onClick = {
                isAccepting = true
                viewModel.creatorDeclineCollaboration(request.id) { succeeded ->
                    isAccepting = false
                    if (!succeeded) { /* keep card */ }
                }
            },
            enabled = !isAccepting,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(viewModel.t(MarviL10n.Key.DECLINE))
        }
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
    var operationBusy by remember(booking.id) { mutableStateOf(false) }

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
                    onClick = {
                        operationBusy = true
                        viewModel.acceptOffer(booking.offer.id) { operationBusy = false }
                    },
                    enabled = canAccept && !operationBusy
                )
                SecondaryActionButton(
                    title = viewModel.t(MarviL10n.Key.DECLINE),
                    onClick = {
                        operationBusy = true
                        viewModel.cancelBooking(booking.id) { operationBusy = false }
                    },
                    enabled = !operationBusy
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
                    onClick = {
                        operationBusy = true
                        viewModel.checkIn(booking.id, checkInCode) { operationBusy = false }
                    },
                    enabled = checkInCode.isNotBlank() && !operationBusy
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
                    },
                    enabled = !operationBusy
                )
                PrimaryActionButton(
                    title = if (operationBusy) {
                        viewModel.t(MarviL10n.Key.SUBMITTING)
                    } else {
                        viewModel.t(MarviL10n.Key.SUBMIT_PROOF)
                    },
                    onClick = {
                        operationBusy = true
                        viewModel.submitProof(
                            booking.id,
                            proofText.lines().map { it.trim() }.filter { it.isNotEmpty() },
                            screenshotUri
                        ) { succeeded ->
                            operationBusy = false
                            if (succeeded) {
                                proofText = ""
                                screenshotUri = null
                            }
                        }
                    },
                    enabled = !operationBusy && (proofText.isNotBlank() || screenshotUri != null)
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
