package com.marvisociety.app.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
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
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    LaunchedEffect(member.id) {
        if (member.isVenue) {
            venueProfile = viewModel.fetchVenuePublicProfile(member.id)
        } else {
            creatorProfile = viewModel.fetchCreatorPublicProfile(member.id)
        }
    }

    MarviScreen {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(member.displayName, style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
            Text("@${member.handle} · ${member.city}", color = MarviColor.Muted)

            creatorProfile?.let { profile ->
                MarviCard {
                    Text(profile.bio, color = MarviColor.Ink)
                    Text("${profile.followerCount} ${viewModel.t(MarviL10n.Key.FOLLOWERS)}", color = MarviColor.Graphite)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = {
                            scope.launch {
                                if (profile.isFollowing) viewModel.unfollowUser(member.id) else viewModel.followUser(member.id)
                                creatorProfile = viewModel.fetchCreatorPublicProfile(member.id)
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = MarviColor.Rose)
                    ) {
                        Text(if (profile.isFollowing) viewModel.t(MarviL10n.Key.UNFOLLOW_CREATOR) else viewModel.t(MarviL10n.Key.FOLLOW_CREATOR))
                    }
                    Button(onClick = { onMessage(member.id) }) {
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
                    Text("${profile.area} · ${profile.category.name}", color = MarviColor.Muted)
                    Text(profile.bio, color = MarviColor.Ink)
                }
            }

            Button(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
                Text(viewModel.t(MarviL10n.Key.CLOSE))
            }
        }
    }
}
