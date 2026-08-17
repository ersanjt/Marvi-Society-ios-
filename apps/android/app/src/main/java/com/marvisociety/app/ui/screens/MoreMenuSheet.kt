package com.marvisociety.app.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Logout
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Groups
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.Policy
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material.icons.outlined.SupportAgent
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.marvisociety.app.data.AppLanguage
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel

private const val PRIVACY_URL = "https://marvisociety.com/privacy"
private const val TERMS_URL = "https://marvisociety.com/terms"
private const val GUIDELINES_URL = "https://marvisociety.com/community-guidelines"

@Composable
fun MoreMenuSheet(
    viewModel: AppViewModel,
    onDismiss: () -> Unit,
    onOpenProfile: () -> Unit,
    onOpenInbox: () -> Unit,
    onOpenBookings: () -> Unit,
    onOpenCommunity: () -> Unit
) {
    val context = LocalContext.current
    fun open(url: String) {
        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }
    }

    val items = listOf(
        MoreItem(Icons.Outlined.BarChart, viewModel.t(MarviL10n.Key.MORE_ANALYTICS)) { onOpenProfile() },
        MoreItem(Icons.Outlined.StarOutline, viewModel.t(MarviL10n.Key.MY_EVENTS)) { onOpenBookings() },
        MoreItem(Icons.Outlined.Groups, viewModel.t(MarviL10n.Key.COMMUNITY_TAB)) { onOpenCommunity() },
        MoreItem(Icons.Outlined.SupportAgent, viewModel.t(MarviL10n.Key.MORE_SUPPORT)) { onOpenInbox() },
        MoreItem(Icons.Outlined.ChatBubbleOutline, viewModel.t(MarviL10n.Key.MORE_FEEDBACK)) { onOpenInbox() },
        MoreItem(Icons.Outlined.Language, viewModel.t(MarviL10n.Key.LANGUAGE_LABEL), dismissOnClick = false) {
            val next = if (viewModel.preferredLanguage == AppLanguage.TURKISH) {
                AppLanguage.ENGLISH
            } else {
                AppLanguage.TURKISH
            }
            viewModel.switchLanguage(next)
        },
        MoreItem(Icons.Outlined.Description, viewModel.t(MarviL10n.Key.TERMS_OF_SERVICE)) { open(TERMS_URL) },
        MoreItem(Icons.Outlined.Policy, viewModel.t(MarviL10n.Key.PRIVACY_POLICY)) { open(PRIVACY_URL) },
        MoreItem(Icons.Outlined.Shield, viewModel.t(MarviL10n.Key.COMMUNITY_GUIDELINES)) { open(GUIDELINES_URL) }
    )

    val sheetShape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.45f))
                    .clickable(onClick = onDismiss)
            )
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .clip(sheetShape)
                    .background(MarviColor.Panel)
                    .border(1.dp, MarviColor.Border, sheetShape)
                    .navigationBarsPadding()
                    .padding(horizontal = 20.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp)
            ) {
                Box(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        viewModel.t(MarviL10n.Key.MORE_TAB),
                        color = MarviColor.Ink,
                        fontWeight = FontWeight.Bold,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.align(Alignment.Center)
                    )
                    Box(
                        modifier = Modifier
                            .align(Alignment.CenterEnd)
                            .size(32.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .clickable(onClick = onDismiss),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Default.Close, contentDescription = viewModel.t(MarviL10n.Key.CLOSE), tint = MarviColor.Muted, modifier = Modifier.size(18.dp))
                    }
                }
                items.chunked(3).forEach { row ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        row.forEach { item ->
                            Column(
                                modifier = Modifier
                                    .weight(1f)
                                    .clickable {
                                        item.onClick()
                                        if (item.dismissOnClick) onDismiss()
                                    }
                                    .padding(vertical = 6.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(52.dp)
                                        .clip(RoundedCornerShape(14.dp))
                                        .background(MarviColor.PanelElevated)
                                        .border(1.dp, MarviColor.Border, RoundedCornerShape(14.dp)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(item.icon, contentDescription = item.label, tint = MarviColor.Ink, modifier = Modifier.size(22.dp))
                                }
                                Text(
                                    item.label,
                                    color = MarviColor.Graphite,
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Medium,
                                    textAlign = TextAlign.Center,
                                    fontSize = 11.sp,
                                    maxLines = 2
                                )
                            }
                        }
                        repeat(3 - row.size) { Box(modifier = Modifier.weight(1f)) }
                    }
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(MarviColor.Border)
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.clickable {
                            viewModel.signOut()
                            onDismiss()
                        }
                    ) {
                        Icon(Icons.AutoMirrored.Outlined.Logout, contentDescription = null, tint = MarviColor.Tomato, modifier = Modifier.size(18.dp))
                        Text(
                            viewModel.t(MarviL10n.Key.SIGN_OUT),
                            color = MarviColor.Tomato,
                            fontWeight = FontWeight.SemiBold,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(MarviColor.PanelElevated)
                            .border(1.dp, MarviColor.Border, RoundedCornerShape(50))
                            .clickable {
                                val next = if (viewModel.preferredLanguage == AppLanguage.TURKISH) {
                                    AppLanguage.ENGLISH
                                } else {
                                    AppLanguage.TURKISH
                                }
                                viewModel.switchLanguage(next)
                            }
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            if (viewModel.preferredLanguage == AppLanguage.TURKISH) "TR" else "EN",
                            color = MarviColor.Ink,
                            fontWeight = FontWeight.Bold,
                            style = MaterialTheme.typography.labelMedium
                        )
                        Icon(Icons.Default.KeyboardArrowDown, contentDescription = null, tint = MarviColor.Muted, modifier = Modifier.size(16.dp))
                    }
                }
            }
        }
    }
}

private data class MoreItem(
    val icon: ImageVector,
    val label: String,
    val dismissOnClick: Boolean = true,
    val onClick: () -> Unit
)
