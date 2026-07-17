package com.marvisociety.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.marvisociety.app.data.DirectThread
import com.marvisociety.app.data.MemberActivityItem
import com.marvisociety.app.data.MemberSearchResult
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.EmptyStateView
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.components.MarviTextField
import com.marvisociety.app.ui.components.SectionTitle
import com.marvisociety.app.ui.components.SegmentedTabs
import com.marvisociety.app.ui.components.StatusPill
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.theme.MarviGradient
import com.marvisociety.app.ui.viewmodel.AppViewModel

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            SectionTitle(viewModel.t(MarviL10n.Key.COMMUNITY_TAB))
            SegmentedTabs(
                tabs = listOf(
                    viewModel.t(MarviL10n.Key.COMMUNITY_SEGMENT_FEED),
                    viewModel.t(MarviL10n.Key.COMMUNITY_SEGMENT_MEMBERS),
                    viewModel.t(MarviL10n.Key.COMMUNITY_SEGMENT_MESSAGES)
                ),
                selectedIndex = tab,
                onSelect = { tab = it }
            )

            when (tab) {
                0 -> {
                    if (viewModel.followingActivity.isEmpty()) {
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxWidth(),
                            contentAlignment = Alignment.Center
                        ) {
                            EmptyStateView(
                                title = viewModel.t(MarviL10n.Key.COMMUNITY_FEED_EMPTY),
                                subtitle = viewModel.t(MarviL10n.Key.COMMUNITY_FEED_EMPTY_SUB),
                                actionTitle = viewModel.t(MarviL10n.Key.REFRESH),
                                onAction = viewModel::loadFollowingActivity
                            )
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier.weight(1f),
                            verticalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            items(viewModel.followingActivity, key = { it.id }) { item ->
                                ActivityCard(
                                    item = item,
                                    createdLabel = viewModel.localizeServerText(item.createdLabel)
                                )
                            }
                        }
                    }
                }
                1 -> {
                    MarviTextField(
                        value = search,
                        onValueChange = {
                            search = it
                            viewModel.searchMembers(it.ifBlank { null })
                        },
                        placeholder = viewModel.t(MarviL10n.Key.COMMUNITY_SEARCH_PROMPT)
                    )
                    if (viewModel.memberSearchResults.isEmpty()) {
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxWidth(),
                            contentAlignment = Alignment.Center
                        ) {
                            EmptyStateView(
                                title = viewModel.t(MarviL10n.Key.COMMUNITY_MEMBERS_EMPTY),
                                subtitle = viewModel.t(MarviL10n.Key.COMMUNITY_MEMBERS_EMPTY_SUB),
                                actionTitle = viewModel.t(MarviL10n.Key.REFRESH),
                                onAction = { viewModel.searchMembers(search.ifBlank { null }) }
                            )
                        }
                    } else {
                        LazyColumn(
                            verticalArrangement = Arrangement.spacedBy(10.dp),
                            modifier = Modifier
                                .weight(1f)
                                .padding(top = 8.dp)
                        ) {
                            items(viewModel.memberSearchResults, key = { it.id }) { member ->
                                MemberCard(member, viewModel) { onOpenMember(member) }
                            }
                        }
                    }
                }
                else -> {
                    if (viewModel.directThreads.isEmpty()) {
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxWidth(),
                            contentAlignment = Alignment.Center
                        ) {
                            EmptyStateView(
                                title = viewModel.t(MarviL10n.Key.NO_MESSAGES_YET),
                                subtitle = viewModel.t(MarviL10n.Key.NO_MESSAGES_YET_SUB),
                                actionTitle = viewModel.t(MarviL10n.Key.REFRESH),
                                onAction = viewModel::loadDirectThreads
                            )
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier.weight(1f),
                            verticalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            items(viewModel.directThreads, key = { it.id }) { thread ->
                                ThreadCard(thread) { onOpenThread(thread) }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ActivityCard(item: MemberActivityItem, createdLabel: String) {
    MarviCard {
        Text(item.actorName, fontWeight = FontWeight.Bold, color = MarviColor.Ink, style = MaterialTheme.typography.titleMedium)
        Text(item.title, color = MarviColor.Ink, style = MaterialTheme.typography.bodyMedium)
        if (item.subtitle.isNotBlank()) Text(item.subtitle, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
        Text(
            createdLabel,
            color = MarviColor.Muted,
            style = MaterialTheme.typography.bodySmall
        )
    }
}

@Composable
private fun MemberCard(member: MemberSearchResult, viewModel: AppViewModel, onClick: () -> Unit) {
    MarviCard(modifier = Modifier.clickable(onClick = onClick)) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(MarviGradient.BrandVertical),
                contentAlignment = Alignment.Center
            ) {
                val avatar = member.avatarUrl
                if (!avatar.isNullOrBlank()) {
                    AsyncImage(
                        model = avatar,
                        contentDescription = member.displayName,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Text(
                        member.displayName.take(1).ifBlank { "?" }.uppercase(),
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(member.displayName, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                val memberSubtitle = listOfNotNull(
                    member.handle.takeIf { it.isNotBlank() }?.let { "@$it" },
                    member.city.takeIf { it.isNotBlank() }
                ).joinToString(" · ")
                if (memberSubtitle.isNotBlank()) {
                    Text(memberSubtitle, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                }
                Text(
                    if (member.isVenue) viewModel.t(MarviL10n.Key.VENUE_TAG) else viewModel.t(MarviL10n.Key.CREATOR_TAG),
                    color = MarviColor.Rose,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.SemiBold
                )
            }
            if (member.isFollowing) {
                StatusPill(viewModel.t(MarviL10n.Key.FOLLOWING_LABEL), MarviColor.Emerald)
            }
        }
    }
}

@Composable
private fun ThreadCard(thread: DirectThread, onClick: () -> Unit) {
    MarviCard(modifier = Modifier.clickable(onClick = onClick)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(MarviGradient.BrandVertical),
                contentAlignment = Alignment.Center
            ) {
                if (!thread.peerAvatarUrl.isNullOrBlank()) {
                    AsyncImage(
                        model = thread.peerAvatarUrl,
                        contentDescription = thread.peerName,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Text(thread.peerName.take(1).uppercase(), color = Color.White, fontWeight = FontWeight.Bold)
                }
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(thread.peerName, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                if (thread.peerHandle.isNotBlank()) {
                    Text("@${thread.peerHandle}", color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                }
                Text(thread.lastMessage, color = MarviColor.Graphite, style = MaterialTheme.typography.bodyMedium, maxLines = 1)
            }
            if (thread.unreadCount > 0) {
                StatusPill("${thread.unreadCount}", MarviColor.Rose)
            }
        }
    }
}
