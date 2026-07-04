package com.marvisociety.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.marvisociety.app.data.AdminTaskStatus
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel

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
                Text(viewModel.t(MarviL10n.Key.CAMPAIGNS), fontWeight = FontWeight.SemiBold, color = MarviColor.Ink)
            }
            items(viewModel.campaigns, key = { it.id }) { campaign ->
                MarviCard {
                    Text(campaign.title, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                    Text("${campaign.venueName} · ${campaign.status}", color = MarviColor.Muted)
                }
            }
        }
    }
}
