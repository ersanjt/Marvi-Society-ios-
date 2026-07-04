package com.marvisociety.app.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.PrimaryTabRow
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.marvisociety.app.data.DirectThread
import com.marvisociety.app.data.MemberActivityItem
import com.marvisociety.app.data.MemberSearchResult
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommunityScreen(
    viewModel: AppViewModel,
    onOpenMember: (MemberSearchResult) -> Unit,
    onOpenThread: (DirectThread) -> Unit
) {
    var tab by remember { mutableIntStateOf(0) }
    var search by remember { mutableStateOf("") }

    LaunchedEffect(tab) {
        when (tab) {
            0 -> viewModel.loadFollowingActivity()
            1 -> viewModel.searchMembers(null)
            2 -> viewModel.loadDirectThreads()
        }
    }

    MarviScreen {
        Column(modifier = Modifier.fillMaxSize()) {
            Text(
                viewModel.t(MarviL10n.Key.COMMUNITY_TAB),
                modifier = Modifier.padding(16.dp),
                style = MaterialTheme.typography.headlineSmall,
                color = MarviColor.Ink,
                fontWeight = FontWeight.Bold
            )
            PrimaryTabRow(selectedTabIndex = tab, containerColor = MarviColor.Panel) {
                Tab(selected = tab == 0, onClick = { tab = 0 }, text = { Text(viewModel.t(MarviL10n.Key.COMMUNITY_SEGMENT_FEED)) })
                Tab(selected = tab == 1, onClick = { tab = 1 }, text = { Text(viewModel.t(MarviL10n.Key.COMMUNITY_SEGMENT_MEMBERS)) })
                Tab(selected = tab == 2, onClick = { tab = 2 }, text = { Text(viewModel.t(MarviL10n.Key.COMMUNITY_SEGMENT_MESSAGES)) })
            }

            if (tab == 1) {
                OutlinedTextField(
                    value = search,
                    onValueChange = { search = it },
                    placeholder = { Text(viewModel.t(MarviL10n.Key.COMMUNITY_SEARCH_PROMPT)) },
                    modifier = Modifier.fillMaxWidth().padding(16.dp)
                )
                Text(
                    viewModel.t(MarviL10n.Key.COMMUNITY_SEARCH_PROMPT),
                    modifier = Modifier.padding(horizontal = 16.dp).clickable { viewModel.searchMembers(search) },
                    color = MarviColor.Rose
                )
            }

            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                when (tab) {
                    0 -> items(viewModel.followingActivity, key = { it.id }) { item ->
                        ActivityCard(item)
                    }
                    1 -> items(viewModel.memberSearchResults, key = { it.id }) { member ->
                        MemberCard(member, viewModel) { onOpenMember(member) }
                    }
                    2 -> items(viewModel.directThreads, key = { it.id }) { thread ->
                        ThreadCard(thread) { onOpenThread(thread) }
                    }
                }
            }
        }
    }
}

@Composable
private fun ActivityCard(item: MemberActivityItem) {
    MarviCard {
        Text(item.actorName, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
        Text("@${item.actorHandle}", color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
        Text(item.title, color = MarviColor.Ink)
        Text(item.subtitle, color = MarviColor.Graphite)
        Text(item.createdLabel, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
private fun MemberCard(member: MemberSearchResult, viewModel: AppViewModel, onClick: () -> Unit) {
    MarviCard(modifier = Modifier.clickable(onClick = onClick)) {
        Text(member.displayName, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
        Text("@${member.handle} · ${member.city}", color = MarviColor.Muted)
        Text(if (member.isVenue) "Venue" else "Creator", color = MarviColor.Rose, style = MaterialTheme.typography.bodySmall)
        if (member.isFollowing) Text(viewModel.t(MarviL10n.Key.FOLLOWING_LABEL), color = MarviColor.Emerald)
    }
}

@Composable
private fun ThreadCard(thread: DirectThread, onClick: () -> Unit) {
    MarviCard(modifier = Modifier.clickable(onClick = onClick)) {
        Text(thread.peerName, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
        Text("@${thread.peerHandle}", color = MarviColor.Muted)
        Text(thread.lastMessage, color = MarviColor.Graphite)
        Text(thread.lastMessageAt, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
    }
}
