package com.marvisociety.app.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.marvisociety.app.data.MemberSearchResult
import com.marvisociety.app.data.PublicCreatorProfile
import com.marvisociety.app.data.PublicVenueProfile
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel
import kotlinx.coroutines.launch

@Composable
fun MemberProfileScreen(
    member: MemberSearchResult,
    viewModel: AppViewModel,
    onMessage: (peerUserId: String) -> Unit,
    onBack: () -> Unit
) {
    var creatorProfile by remember { mutableStateOf<PublicCreatorProfile?>(null) }
    var venueProfile by remember { mutableStateOf<PublicVenueProfile?>(null) }
    var comments by remember { mutableStateOf<List<com.marvisociety.app.data.ProfileComment>>(emptyList()) }
    var commentDraft by remember { mutableStateOf("") }
    var profileError by remember { mutableStateOf<String?>(null) }
    var isFollowBusy by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val commentTargetId = member.userId.ifBlank { member.id }

    LaunchedEffect(member.id) {
        runCatching {
            if (member.isVenue) {
                venueProfile = viewModel.fetchVenuePublicProfile(member.id)
            } else {
                creatorProfile = viewModel.fetchCreatorPublicProfile(member.id)
            }
            comments = viewModel.fetchProfileComments(commentTargetId)
        }.onFailure { profileError = it.message }
    }

    val displayName = creatorProfile?.name?.takeIf { it.isNotBlank() }
        ?: venueProfile?.name?.takeIf { it.isNotBlank() }
        ?: member.displayName
    val coverUrl = creatorProfile?.coverUrl?.takeIf { it.isNotBlank() }
    val avatarUrl = creatorProfile?.avatarUrl?.takeIf { it.isNotBlank() }
        ?: member.avatarUrl?.takeIf { it.isNotBlank() }

    MarviScreen {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(modifier = Modifier.fillMaxWidth()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(120.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(MarviColor.Aubergine.copy(alpha = 0.45f))
                ) {
                    if (coverUrl != null) {
                        AsyncImage(
                            model = coverUrl,
                            contentDescription = null,
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop
                        )
                    }
                }
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .offset(x = 12.dp, y = 28.dp)
                        .size(72.dp)
                        .clip(CircleShape)
                        .background(MarviColor.Rose.copy(alpha = 0.2f)),
                    contentAlignment = Alignment.Center
                ) {
                    if (avatarUrl != null) {
                        AsyncImage(
                            model = avatarUrl,
                            contentDescription = displayName,
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop
                        )
                    } else {
                        Text(
                            displayName.take(1).ifBlank { "?" }.uppercase(),
                            color = MarviColor.Rose,
                            fontWeight = FontWeight.Bold,
                            style = MaterialTheme.typography.headlineSmall
                        )
                    }
                }
            }

            Column(modifier = Modifier.padding(top = 28.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(displayName, style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
                Text("@${member.handle} · ${member.city}", color = MarviColor.Muted)
            }

            creatorProfile?.let { profile ->
                MarviCard {
                    if (profile.bio.isNotBlank()) {
                        Text(profile.bio, color = MarviColor.Ink)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Text("${profile.followerCount} ${viewModel.t(MarviL10n.Key.FOLLOWERS)}", color = MarviColor.Graphite)
                        Text("${profile.followingCount} ${viewModel.t(MarviL10n.Key.FOLLOWING_LABEL)}", color = MarviColor.Graphite)
                        Text("${viewModel.t(MarviL10n.Key.SCORE_LABEL)} ${profile.score}", color = MarviColor.Gold)
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = {
                            scope.launch {
                                val targetUserId = member.userId.ifBlank { member.id }
                                isFollowBusy = true
                                val onResult: (Boolean) -> Unit = { succeeded ->
                                    if (succeeded) {
                                        scope.launch {
                                            runCatching {
                                                creatorProfile = viewModel.fetchCreatorPublicProfile(member.id)
                                            }.onFailure { profileError = it.message }
                                            isFollowBusy = false
                                        }
                                    } else {
                                        isFollowBusy = false
                                    }
                                }
                                if (profile.isFollowing) {
                                    viewModel.unfollowUser(targetUserId, onResult)
                                } else {
                                    viewModel.followUser(targetUserId, onResult)
                                }
                            }
                        },
                        enabled = !isFollowBusy,
                        colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                    ) {
                        Text(if (profile.isFollowing) viewModel.t(MarviL10n.Key.UNFOLLOW_CREATOR) else viewModel.t(MarviL10n.Key.FOLLOW_CREATOR))
                    }
                    Button(onClick = { onMessage(member.userId.ifBlank { member.id }) }) {
                        Text(viewModel.t(MarviL10n.Key.MESSAGE))
                    }
                }
                if (profile.handle.isNotBlank()) {
                    Button(onClick = {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://instagram.com/${profile.handle.removePrefix("@")}")))
                    }) { Text("Instagram") }
                }
                if (profile.tiktokHandle.isNotBlank()) {
                    Button(onClick = {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://tiktok.com/@${profile.tiktokHandle.removePrefix("@")}")))
                    }) { Text("TikTok") }
                }
            }

            venueProfile?.let { profile ->
                MarviCard {
                    Text("${profile.area} · ${viewModel.categoryLabel(profile.category)}", color = MarviColor.Muted)
                    Text(profile.bio, color = MarviColor.Ink)
                }
            }

            profileError?.let {
                Text(it, color = MarviColor.Tomato, style = MaterialTheme.typography.bodySmall)
            }

            MarviCard {
                Text(
                    viewModel.t(MarviL10n.Key.COMMENTS),
                    color = MarviColor.Ink,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.titleMedium
                )
                if (comments.isEmpty()) {
                    Text(viewModel.t(MarviL10n.Key.NO_COMMENTS), color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                } else {
                    comments.forEach { comment ->
                        Column(modifier = Modifier.padding(vertical = 4.dp)) {
                            Text(
                                comment.authorName.ifBlank { "@${comment.authorHandle}" },
                                color = MarviColor.Ink,
                                fontWeight = FontWeight.SemiBold,
                                style = MaterialTheme.typography.bodyMedium
                            )
                            Text(comment.body, color = MarviColor.Graphite, style = MaterialTheme.typography.bodyMedium)
                            Text(comment.createdLabel, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
                OutlinedTextField(
                    value = commentDraft,
                    onValueChange = { commentDraft = it },
                    label = { Text(viewModel.t(MarviL10n.Key.ADD_COMMENT)) },
                    modifier = Modifier.fillMaxWidth()
                )
                Button(
                    onClick = {
                        val body = commentDraft.trim()
                        if (body.isNotEmpty()) {
                            viewModel.addProfileComment(commentTargetId, body) {
                                commentDraft = ""
                                scope.launch {
                                    runCatching {
                                        comments = viewModel.fetchProfileComments(commentTargetId)
                                    }.onFailure { profileError = it.message }
                                }
                            }
                        }
                    },
                    enabled = commentDraft.isNotBlank(),
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                ) { Text(viewModel.t(MarviL10n.Key.SEND)) }
            }

            Button(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
                Text(viewModel.t(MarviL10n.Key.CLOSE))
            }
        }
    }
}
