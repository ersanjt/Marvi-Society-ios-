package com.marvisociety.app.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.marvisociety.app.data.AdminTaskStatus
import com.marvisociety.app.data.CollaborationModel
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel
import kotlinx.coroutines.launch

@Composable
fun AdminDashboardScreen(viewModel: AppViewModel) {
    LaunchedEffect(Unit) { viewModel.refreshFromServer() }

    MarviScreen {
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Text(viewModel.t(MarviL10n.Key.ADMIN), style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
            }
            item {
                Text(viewModel.t(MarviL10n.Key.ADMIN_TASKS), fontWeight = FontWeight.SemiBold, color = MarviColor.Ink)
            }
            items(viewModel.adminTasks, key = { it.id }) { task ->
                MarviCard {
                    Text(task.title, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                    Text(task.subtitle, color = MarviColor.Muted)
                    Text("${task.type.name.replace('_', ' ').lowercase().replaceFirstChar { it.uppercase() }} · ${task.priority} · ${task.dateLabel}", color = MarviColor.Graphite, style = MaterialTheme.typography.bodySmall)
                    if (task.status == AdminTaskStatus.OPEN) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                            Button(
                                onClick = { viewModel.approveTask(task.id) },
                                colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Emerald)
                            ) { Text(viewModel.t(MarviL10n.Key.APPROVE)) }
                            Button(
                                onClick = { viewModel.rejectTask(task.id) },
                                colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Tomato)
                            ) { Text(viewModel.t(MarviL10n.Key.REJECT)) }
                        }
                    }
                }
            }
            item {
                Text(viewModel.t(MarviL10n.Key.INVITE_CODES), fontWeight = FontWeight.SemiBold, color = MarviColor.Ink, modifier = Modifier.padding(top = 8.dp))
            }
            items(viewModel.adminInviteCodes, key = { it.code }) { code ->
                MarviCard {
                    Text(code.code, fontWeight = FontWeight.Bold, color = MarviColor.Rose)
                    Text("${code.useCount}/${code.maxUses} uses · ${code.ownerType}", color = MarviColor.Muted)
                    code.inviteEmail?.let { Text(it, color = MarviColor.Graphite, style = MaterialTheme.typography.bodySmall) }
                }
            }
            item {
                Text("Users", fontWeight = FontWeight.SemiBold, color = MarviColor.Ink, modifier = Modifier.padding(top = 8.dp))
            }
            items(viewModel.adminUsers, key = { it.id }) { user ->
                MarviCard {
                    Text(user.fullName.ifBlank { user.email }, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                    Text("${user.email} · ${user.city}", color = MarviColor.Muted)
                    Text(user.role.label, color = MarviColor.Rose)
                }
            }
        }
    }
}

@Composable
fun InboxScreen(viewModel: AppViewModel) {
    MarviScreen {
        Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
            Text(viewModel.t(MarviL10n.Key.INBOX_TITLE), style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
            if (viewModel.inboxMessages.isEmpty()) {
                MarviCard {
                    Text(viewModel.t(MarviL10n.Key.INBOX_EMPTY), color = MarviColor.Muted)
                }
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(viewModel.inboxMessages, key = { it.id }) { msg ->
                        MarviCard {
                            Text(msg.title, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                            Text(msg.body, color = MarviColor.Graphite)
                            Text(msg.dateLabel, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun VenueStudioScreen(viewModel: AppViewModel) {
    var showCreate by remember { mutableStateOf(false) }
    var title by remember { mutableStateOf("") }
    var valueLabel by remember { mutableStateOf("") }
    var dateLabel by remember { mutableStateOf("") }
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
    val scope = rememberCoroutineScope()

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
            items(viewModel.myVenues, key = { it.id }) { venue ->
                MarviCard {
                    Text(venue.name, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                    Text("${venue.area} · ${venue.category.name}", color = MarviColor.Muted)
                    if (venue.isActive) Text("Active", color = MarviColor.Emerald)
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
                        onClick = { showCreate = !showCreate },
                        colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                    ) {
                        Text(if (showCreate) viewModel.t(MarviL10n.Key.CLOSE) else viewModel.t(MarviL10n.Key.NEW_CAMPAIGN))
                    }
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
                                    label = { Text(option.name.lowercase().replaceFirstChar { it.uppercase() }) },
                                    colors = FilterChipDefaults.filterChipColors(
                                        selectedContainerColor = MarviColor.Rose.copy(alpha = 0.25f),
                                        selectedLabelColor = MarviColor.Rose
                                    )
                                )
                            }
                        }
                        Button(
                            onClick = {
                                val lines = deliverables.split(',', '\n').map { it.trim() }.filter { it.isNotEmpty() }
                                if (title.isBlank() || lines.isEmpty()) {
                                    formError = "Title and deliverables required"
                                    return@Button
                                }
                                formError = null
                                submitting = true
                                scope.launch {
                                    val ok = viewModel.createCampaign(
                                        title = title.trim(),
                                        model = model,
                                        dateLabel = dateLabel.ifBlank { "TBD" },
                                        valueLabel = valueLabel,
                                        slots = slots.toIntOrNull()?.coerceIn(1, 30) ?: 5,
                                        deliverables = lines,
                                        imageUri = imageUri,
                                        description = description,
                                        timeLabel = timeLabel.ifBlank { "Flexible" },
                                        requirements = requirements.split(',', '\n').map { it.trim() }.filter { it.isNotEmpty() },
                                        hostNote = hostNote
                                    )
                                    submitting = false
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
                                    } else {
                                        formError = viewModel.lastSyncError
                                    }
                                }
                            },
                            enabled = !submitting,
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                        ) {
                            Text(if (submitting) viewModel.t(MarviL10n.Key.LOADING) else viewModel.t(MarviL10n.Key.SEND_TO_REVIEW))
                        }
                        formError?.let { Text(it, color = MarviColor.Tomato) }
                        viewModel.lastSyncError?.takeIf { formError == null }?.let { Text(it, color = MarviColor.Tomato) }
                    }
                }
            }
            items(viewModel.campaigns, key = { it.id }) { campaign ->
                MarviCard {
                    Text(campaign.title, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                    Text("${campaign.venueName} · ${campaign.status}", color = MarviColor.Muted)
                    Text(campaign.dateLabel, color = MarviColor.Graphite, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}
