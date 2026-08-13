package com.marvisociety.app.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Archive
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Gesture
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.PauseCircle
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.marvisociety.app.R
import com.marvisociety.app.data.MembershipStatus
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.theme.InterFamily
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.theme.MarviGradient
import com.marvisociety.app.ui.theme.NewsreaderFamily

@Composable
fun MarviScreen(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MarviColor.Surface)
    ) {
        // Ambient brand glow: the iOS source uses a translucent Ellipse. Keeping
        // this clipped avoids the hard purple rectangle previously visible atop
        // every Android screen.
        Box(
            modifier = Modifier
                .width(480.dp)
                .height(280.dp)
                .align(Alignment.TopCenter)
                .offset(y = (-80).dp)
                .blur(80.dp)
                .alpha(0.35f)
                .clip(CircleShape)
                .background(MarviGradient.BrandVertical)
        )
        content()
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(58.dp)
                .align(Alignment.TopCenter)
                .background(MarviGradient.TopFade)
        )
    }
}

@Composable
fun MarviCard(
    modifier: Modifier = Modifier,
    contentPadding: Dp = 16.dp,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MarviColor.Panel)
            .border(1.dp, MarviColor.Border, RoundedCornerShape(16.dp))
            .padding(contentPadding),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        content = content
    )
}

@Composable
fun SyncErrorBanner(
    message: String,
    retryTitle: String,
    onRetry: () -> Unit,
    onDismiss: () -> Unit
) {
    val shape = RoundedCornerShape(12.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(shape)
            .background(MarviColor.PanelElevated)
            .border(1.dp, MarviColor.Tomato.copy(alpha = 0.35f), shape)
            .padding(12.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(Icons.Default.Warning, null, tint = MarviColor.Tomato, modifier = Modifier.size(16.dp))
        Text(
            message,
            color = MarviColor.Ink,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f)
        )
        TextButton(onClick = onRetry) {
            Text(retryTitle, color = MarviColor.Rose, fontWeight = FontWeight.Bold)
        }
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(CircleShape)
                .clickable(onClick = onDismiss),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Default.Close, null, tint = MarviColor.Muted, modifier = Modifier.size(12.dp))
        }
    }
}

@Composable
fun SectionTitle(text: String, subtitle: String? = null) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.padding(bottom = 4.dp)) {
        Text(
            text = text,
            style = MaterialTheme.typography.headlineMedium,
            color = MarviColor.Ink,
            fontWeight = FontWeight.Bold
        )
        if (!subtitle.isNullOrBlank()) {
            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MarviColor.Muted)
        }
    }
}

@Composable
fun StatusPill(text: String, tint: Color, icon: ImageVector? = null) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(tint.copy(alpha = 0.16f))
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        if (icon != null) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(12.dp))
        }
        Text(
            text,
            color = tint,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1
        )
    }
}

@Composable
fun InfoBadge(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelMedium,
        color = MarviColor.Graphite,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(MarviColor.PanelElevated)
            .padding(horizontal = 9.dp, vertical = 7.dp),
        maxLines = 1
    )
}

@Composable
fun MetricTile(value: String, label: String, tint: Color, icon: ImageVector? = null) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(MarviColor.Panel)
            .border(1.dp, MarviColor.Border, RoundedCornerShape(14.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (icon != null) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
        }
        Text(
            value,
            style = MaterialTheme.typography.headlineMedium,
            color = MarviColor.Ink,
            fontWeight = FontWeight.Bold,
            maxLines = 1
        )
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = MarviColor.Muted,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1
        )
    }
}

@Composable
fun PrimaryActionButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    icon: ImageVector? = null
) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 50.dp)
            .clip(shape)
            .background(
                if (enabled) MarviGradient.Brand
                else Brush.horizontalGradient(listOf(MarviColor.Muted.copy(alpha = 0.4f), MarviColor.Muted.copy(alpha = 0.4f)))
            )
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 13.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (icon != null) {
            Icon(icon, null, tint = Color.White, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
        }
        Text(
            title,
            color = Color.White,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
fun SecondaryActionButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    val shape = RoundedCornerShape(14.dp)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 48.dp)
            .clip(shape)
            .background(MarviColor.PanelElevated)
            .border(1.dp, MarviColor.Border, shape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            title,
            color = MarviColor.Ink,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
fun MarviTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    singleLine: Boolean = true
) {
    val shape = RoundedCornerShape(12.dp)
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = singleLine,
        textStyle = TextStyle(color = MarviColor.Ink, fontSize = 15.sp, fontFamily = InterFamily),
        cursorBrush = SolidColor(MarviColor.Rose),
        modifier = modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 52.dp)
            .clip(shape)
            .background(MarviColor.PanelElevated)
            .border(1.dp, MarviColor.Border, shape)
            .padding(horizontal = 14.dp, vertical = 14.dp),
        decorationBox = { inner ->
            Box {
                if (value.isEmpty()) {
                    Text(placeholder, color = MarviColor.Muted, fontSize = 15.sp)
                }
                inner()
            }
        }
    )
}

@Composable
fun EmptyStateView(
    title: String,
    subtitle: String,
    icon: ImageVector = Icons.Default.AutoAwesome,
    actionTitle: String? = null,
    onAction: (() -> Unit)? = null
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Icon(icon, null, tint = MarviColor.Rose, modifier = Modifier.size(32.dp))
        Text(title, style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
        Text(
            subtitle,
            style = MaterialTheme.typography.bodyMedium,
            color = MarviColor.Muted,
            modifier = Modifier.padding(horizontal = 24.dp),
            textAlign = TextAlign.Center
        )
        if (!actionTitle.isNullOrBlank() && onAction != null) {
            TextButton(onClick = onAction) {
                Text(actionTitle, color = MarviColor.Rose, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
fun FilterChipPill(
    label: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    val shape = RoundedCornerShape(50)
    Text(
        text = label,
        color = if (selected) Color.White else MarviColor.Ink,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.Bold,
        modifier = Modifier
            .clip(shape)
            .then(
                if (selected) Modifier.background(MarviGradient.Brand)
                else Modifier
                    .background(MarviColor.PanelElevated)
                    .border(1.dp, MarviColor.Border, shape)
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp)
    )
}

@Composable
fun SegmentedTabs(
    tabs: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    uppercase: Boolean = true
) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(MarviColor.Panel)
            .border(1.dp, MarviColor.Border, shape)
            .padding(4.dp)
    ) {
        tabs.forEachIndexed { index, label ->
            val selected = index == selectedIndex
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(10.dp))
                    .then(if (selected) Modifier.background(MarviGradient.Brand) else Modifier)
                    .clickable { onSelect(index) }
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    if (uppercase) label.uppercase() else label,
                    color = if (selected) Color.White else MarviColor.Muted,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 0.8.sp,
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
fun OfferImageView(
    url: String,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    height: Dp = 140.dp,
    cornerRadius: Dp = 14.dp
) {
    Box(
        modifier = modifier
            .height(height)
            .clip(RoundedCornerShape(cornerRadius))
            .background(MarviGradient.BrandVertical)
    ) {
        AsyncImage(
            model = url,
            contentDescription = contentDescription,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop
        )
    }
}

@Composable
fun CircleIconButton(
    icon: ImageVector,
    onClick: () -> Unit,
    tint: Color = MarviColor.Ink,
    badgeCount: Int = 0
) {
    Box {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(MarviColor.Panel)
                .clickable(onClick = onClick),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
        }
        if (badgeCount > 0) {
            Text(
                badgeCount.coerceAtMost(99).toString(),
                color = Color.White,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = 6.dp, y = (-4).dp)
                    .clip(RoundedCornerShape(50))
                    .background(MarviColor.Rose)
                    .padding(horizontal = 5.dp, vertical = 2.dp)
            )
        }
    }
}

@Composable
fun HomeHeader(
    greeting: String,
    subtitle: String,
    avatarUrl: String?,
    avatarLetter: String,
    hiPrefix: String? = null,
    unreadCount: Int = 0,
    onProfile: (() -> Unit)? = null,
    onSearch: (() -> Unit)? = null,
    onNotifications: (() -> Unit)? = null,
    trailing: @Composable (() -> Unit)? = null
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        val leading = @Composable {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(MarviGradient.Brand),
                    contentAlignment = Alignment.Center
                ) {
                    if (!avatarUrl.isNullOrBlank()) {
                        AsyncImage(
                            model = avatarUrl,
                            contentDescription = null,
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop
                        )
                    } else {
                        Text(avatarLetter.take(1).uppercase(), color = Color.White, fontWeight = FontWeight.Bold)
                    }
                }
                Column {
                    Text(
                        if (hiPrefix.isNullOrBlank()) greeting else "$hiPrefix, $greeting",
                        style = MaterialTheme.typography.headlineSmall,
                        color = MarviColor.Ink,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1
                    )
                    Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MarviColor.Muted, maxLines = 1)
                }
            }
        }
        if (onProfile != null) {
            Box(modifier = Modifier.weight(1f).clickable(onClick = onProfile)) { leading() }
        } else {
            Box(modifier = Modifier.weight(1f)) { leading() }
        }
        if (onSearch != null) {
            CircleIconButton(Icons.Outlined.Search, onClick = onSearch)
        }
        if (onNotifications != null) {
            CircleIconButton(Icons.Outlined.Notifications, onClick = onNotifications, badgeCount = unreadCount)
        }
        trailing?.invoke()
    }
}

@Composable
fun ProgressBar(progress: Float, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(7.dp)
            .clip(RoundedCornerShape(50))
            .background(Color.White.copy(alpha = 0.08f))
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(progress.coerceIn(0f, 1f))
                .height(7.dp)
                .clip(RoundedCornerShape(50))
                .background(MarviGradient.Brand)
        )
    }
}

/** Marvi brand mark — mirrors iOS `BrandMark` (continuous rounded square, r = size*0.2237). */
@Composable
fun BrandMark(size: Dp = 46.dp, modifier: Modifier = Modifier) {
    Image(
        painter = painterResource(R.drawable.brand_mark),
        contentDescription = "Marvi Society",
        modifier = modifier
            .size(size)
            .clip(RoundedCornerShape(size * 0.2237f)),
        contentScale = ContentScale.Crop
    )
}

/** Brand mark + wordmark stack — mirrors iOS `BrandLockup`. */
@Composable
fun BrandLockup(subtitle: String, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        BrandMark(size = 48.dp)
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                "Marvi Society",
                style = MaterialTheme.typography.titleLarge,
                color = MarviColor.Ink,
                fontWeight = FontWeight.Bold,
                maxLines = 1
            )
            Text(
                subtitle.uppercase(),
                style = MaterialTheme.typography.labelSmall,
                color = MarviColor.Muted,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.2.sp,
                maxLines = 1
            )
        }
    }
}

/** Launch/bootstrap screen — mirrors iOS `BootstrapSplashView`. */
@Composable
fun BootstrapSplash(message: String) {
    val transition = rememberInfiniteTransition(label = "splash")
    val pulse by transition.animateFloat(
        initialValue = 0.92f,
        targetValue = 1.06f,
        animationSpec = infiniteRepeatable(
            animation = tween(1400),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MarviColor.Surface),
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .size(220.dp)
                .scale(pulse)
                .blur(48.dp)
                .clip(CircleShape)
                .background(MarviColor.Rose.copy(alpha = 0.18f))
        )
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            BrandMark(size = 72.dp, modifier = Modifier.scale(pulse))
            CircularProgressIndicator(color = MarviColor.Rose)
            Text(
                message,
                style = MaterialTheme.typography.titleMedium,
                color = MarviColor.Muted,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
fun MembershipStatusBanner(
    status: MembershipStatus,
    pausedBySelf: Boolean,
    viewModelLabel: (MarviL10n.Key) -> String,
    onReactivate: (() -> Unit)? = null
) {
    val tint = when (status) {
        MembershipStatus.UNDER_REVIEW -> MarviColor.Gold
        MembershipStatus.APPROVED -> MarviColor.Emerald
        MembershipStatus.PAUSED -> MarviColor.Tomato
    }
    val icon = when (status) {
        MembershipStatus.UNDER_REVIEW -> Icons.Default.HourglassEmpty
        MembershipStatus.APPROVED -> Icons.Default.AutoAwesome
        MembershipStatus.PAUSED -> Icons.Default.PauseCircle
    }
    val title = when (status) {
        MembershipStatus.UNDER_REVIEW -> viewModelLabel(MarviL10n.Key.UNDER_REVIEW_BANNER)
        MembershipStatus.APPROVED -> viewModelLabel(MarviL10n.Key.APPROVED_BANNER)
        MembershipStatus.PAUSED -> viewModelLabel(
            if (pausedBySelf) MarviL10n.Key.PAUSED_SELF_BANNER else MarviL10n.Key.PAUSED_ADMIN_BANNER
        )
    }
    val message = when (status) {
        MembershipStatus.UNDER_REVIEW -> viewModelLabel(MarviL10n.Key.UNDER_REVIEW_BANNER_SUB)
        MembershipStatus.APPROVED -> viewModelLabel(MarviL10n.Key.APPROVED_BANNER_SUB)
        MembershipStatus.PAUSED -> viewModelLabel(
            if (pausedBySelf) MarviL10n.Key.PAUSED_SELF_BANNER_SUB else MarviL10n.Key.PAUSED_ADMIN_BANNER_SUB
        )
    }
    val shape = RoundedCornerShape(14.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(tint.copy(alpha = 0.1f))
            .border(1.dp, tint.copy(alpha = 0.25f), shape)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
            Column(verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.weight(1f)) {
                Text(title, color = MarviColor.Ink, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
                Text(message, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
            }
        }
        if (status == MembershipStatus.PAUSED && pausedBySelf && onReactivate != null) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(MarviColor.Emerald.copy(alpha = 0.12f))
                    .clickable(onClick = onReactivate)
                    .padding(vertical = 10.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    viewModelLabel(MarviL10n.Key.REACTIVATE_ACCOUNT),
                    color = MarviColor.Emerald,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.labelMedium
                )
            }
        }
    }
}

@Composable
fun SSExploreHeader(eyebrow: String, cityPrefix: String, city: String, eventsFound: String) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            eyebrow.uppercase(),
            style = MaterialTheme.typography.labelMedium,
            color = MarviColor.Muted,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.2.sp
        )
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                cityPrefix,
                style = MaterialTheme.typography.displaySmall.copy(fontFamily = NewsreaderFamily),
                color = MarviColor.Ink,
                fontWeight = FontWeight.Bold
            )
            Text(
                city,
                style = MaterialTheme.typography.displaySmall.copy(fontFamily = NewsreaderFamily).merge(
                    TextStyle(brush = MarviGradient.Brand)
                ),
                fontWeight = FontWeight.Bold
            )
        }
        Text(eventsFound, color = MarviColor.Rose, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium)
    }
}

@Composable
fun SSDiscoverAxisPills(
    whenTitle: String,
    whereTitle: String,
    typeTitle: String,
    whenReset: String,
    whereReset: String,
    typeReset: String,
    whenOptions: List<String>,
    whereOptions: List<String>,
    typeOptions: List<String>,
    selectedWhen: String?,
    selectedWhere: String?,
    selectedType: String?,
    onWhen: (String?) -> Unit,
    onWhere: (String?) -> Unit,
    onType: (String?) -> Unit
) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        AxisMenu(Modifier.weight(1f), Icons.Default.CalendarMonth, whenTitle, whenReset, whenOptions, selectedWhen, onWhen)
        AxisMenu(Modifier.weight(1f), Icons.Default.Place, whereTitle, whereReset, whereOptions, selectedWhere, onWhere)
        AxisMenu(Modifier.weight(1f), Icons.Default.AutoAwesome, typeTitle, typeReset, typeOptions, selectedType, onType)
    }
}

@Composable
private fun AxisMenu(
    modifier: Modifier,
    icon: ImageVector,
    title: String,
    resetLabel: String,
    options: List<String>,
    value: String?,
    onSelect: (String?) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val shape = RoundedCornerShape(14.dp)
    Box(modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(shape)
                .background(MarviColor.Panel)
                .border(
                    if (value != null) 2.dp else 1.dp,
                    if (value != null) MarviColor.Rose else MarviColor.Border,
                    shape
                )
                .clickable { expanded = true }
                .padding(vertical = 14.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(icon, null, tint = MarviColor.Rose, modifier = Modifier.size(16.dp))
            Text(
                value ?: title,
                color = MarviColor.Ink,
                fontWeight = FontWeight.Bold,
                style = MaterialTheme.typography.labelSmall,
                maxLines = 1
            )
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            DropdownMenuItem(text = { Text(resetLabel) }, onClick = { onSelect(null); expanded = false })
            options.forEach { option ->
                DropdownMenuItem(text = { Text(option) }, onClick = { onSelect(option); expanded = false })
            }
        }
    }
}

@Composable
fun SSFilterChip(title: String, icon: ImageVector? = null, onClick: () -> Unit, dimmed: Boolean = false) {
    Row(
        modifier = Modifier
            .alpha(if (dimmed) 0.45f else 1f)
            .clip(RoundedCornerShape(50))
            .background(MarviColor.Panel)
            .border(1.dp, MarviColor.Border, RoundedCornerShape(50))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        if (icon != null) Icon(icon, null, tint = MarviColor.Ink, modifier = Modifier.size(14.dp))
        Text(title, color = MarviColor.Ink, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelMedium)
    }
}

@Composable
fun SSFilterToolbar(
    filtersLabel: String,
    sortLabel: String,
    locationLabel: String,
    dateLabel: String,
    onFilters: () -> Unit,
    onSort: () -> Unit,
    onLocation: () -> Unit,
    onDate: () -> Unit
) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        item { SSFilterChip(filtersLabel, Icons.Default.Tune, onFilters) }
        item { SSFilterChip(sortLabel, Icons.Default.SwapVert, onSort) }
        item { SSFilterChip(locationLabel, Icons.Default.Place, onLocation) }
        item { SSFilterChip(dateLabel, Icons.Default.CalendarMonth, onDate) }
    }
}

data class CalendarDayUi(val id: Int, val weekday: String, val label: String)

@Composable
fun EventCalendarStrip(days: List<CalendarDayUi>, selectedDay: Int?, onSelect: (Int?) -> Unit) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        items(days, key = { it.id }) { day ->
            val selected = selectedDay == day.id
            val shape = RoundedCornerShape(14.dp)
            Column(
                modifier = Modifier
                    .width(52.dp)
                    .height(64.dp)
                    .clip(shape)
                    .then(if (selected) Modifier.background(MarviGradient.Brand) else Modifier.background(MarviColor.Panel))
                    .then(if (selected) Modifier else Modifier.border(1.dp, MarviColor.Border, shape))
                    .clickable { onSelect(if (selected) null else day.id) }
                    .padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    day.weekday,
                    color = if (selected) Color.White else MarviColor.Muted,
                    fontWeight = FontWeight.SemiBold,
                    style = MaterialTheme.typography.labelSmall
                )
                Text(
                    day.label,
                    color = if (selected) Color.White else MarviColor.Ink,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.titleLarge
                )
            }
        }
    }
}

@Composable
fun SSManagementButton(title: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(MarviGradient.Brand)
            .clickable(onClick = onClick)
            .padding(vertical = 15.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            title.uppercase(),
            color = Color.White,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.6.sp,
            style = MaterialTheme.typography.titleMedium
        )
    }
}

@Composable
fun GradientCTA(title: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(MarviGradient.Brand)
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            title.uppercase(),
            color = Color.White,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.5.sp,
            style = MaterialTheme.typography.titleMedium
        )
    }
}

data class StatusBadgeUi(val id: String, val title: String, val count: Int, val tint: Color)

@Composable
fun SSSelectableStatusGrid(
    badges: List<StatusBadgeUi>,
    selectedId: String?,
    onSelect: (String?) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        badges.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                row.forEach { badge ->
                    val selected = selectedId == badge.id
                    val shape = RoundedCornerShape(14.dp)
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .clip(shape)
                            .then(if (selected) Modifier.background(MarviGradient.Brand) else Modifier.background(MarviColor.Panel))
                            .then(if (selected) Modifier else Modifier.border(1.dp, MarviColor.Border, shape))
                            .clickable { onSelect(if (selected) null else badge.id) }
                            .padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text(
                            badge.count.toString(),
                            color = if (selected) Color.White else badge.tint,
                            fontWeight = FontWeight.Bold,
                            style = MaterialTheme.typography.headlineLarge
                        )
                        Text(
                            badge.title,
                            color = if (selected) Color.White.copy(alpha = 0.9f) else MarviColor.Muted,
                            fontWeight = FontWeight.SemiBold,
                            style = MaterialTheme.typography.labelMedium,
                            maxLines = 2
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun SSToggleTabs(leftTitle: String, rightTitle: String, isRightSelected: Boolean, onSelectRight: (Boolean) -> Unit) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(MarviColor.Panel)
            .border(1.dp, MarviColor.Border, shape)
            .padding(4.dp)
    ) {
        listOf(leftTitle to false, rightTitle to true).forEach { (title, right) ->
            val selected = isRightSelected == right
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(10.dp))
                    .then(if (selected) Modifier.background(MarviGradient.Brand) else Modifier)
                    .clickable { onSelectRight(right) }
                    .padding(vertical = 11.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    title,
                    color = if (selected) Color.White else MarviColor.Muted,
                    fontWeight = FontWeight.Bold,
                    style = MaterialTheme.typography.titleMedium
                )
            }
        }
    }
}

enum class StudioGridFocus { UNDER_REVIEW, UPCOMING, HAPPENING, PAST }

@Composable
fun StudioStatusGrid(
    underReview: String,
    upcoming: String,
    openSwipe: String,
    happening: String,
    past: String,
    create: String,
    selected: StudioGridFocus?,
    onUnderReview: () -> Unit,
    onUpcoming: () -> Unit,
    onSwipe: () -> Unit,
    onHappening: () -> Unit,
    onPast: () -> Unit,
    onCreate: () -> Unit
) {
    val tiles = listOf(
        Triple(underReview, Icons.Default.HourglassEmpty, MarviColor.Gold) to Pair(selected == StudioGridFocus.UNDER_REVIEW, onUnderReview),
        Triple(upcoming, Icons.Default.CalendarMonth, MarviColor.Blue) to Pair(selected == StudioGridFocus.UPCOMING, onUpcoming),
        Triple(openSwipe, Icons.Default.Gesture, MarviColor.Rose) to Pair(false, onSwipe),
        Triple(happening, Icons.Default.AutoAwesome, MarviColor.Emerald) to Pair(selected == StudioGridFocus.HAPPENING, onHappening),
        Triple(past, Icons.Default.Archive, MarviColor.Muted) to Pair(selected == StudioGridFocus.PAST, onPast),
        Triple(create, Icons.Default.Add, MarviColor.Aubergine) to Pair(false, onCreate)
    )
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        tiles.chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                row.forEach { (meta, state) ->
                    val (title, icon, tint) = meta
                    val (isSelected, action) = state
                    val shape = RoundedCornerShape(14.dp)
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .height(88.dp)
                            .clip(shape)
                            .background(if (isSelected) tint.copy(alpha = 0.12f) else MarviColor.Panel)
                            .border(if (isSelected) 1.5.dp else 1.dp, if (isSelected) tint.copy(alpha = 0.55f) else MarviColor.Border, shape)
                            .clickable(onClick = action)
                            .padding(8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Icon(icon, null, tint = tint, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.height(8.dp))
                        Text(
                            title,
                            color = if (isSelected) MarviColor.Ink else MarviColor.Muted,
                            fontWeight = FontWeight.Bold,
                            style = MaterialTheme.typography.labelSmall,
                            textAlign = TextAlign.Center,
                            maxLines = 2
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun ProfileHealthRing(score: Int, label: String) {
    Box(modifier = Modifier.size(110.dp), contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val stroke = 10.dp.toPx()
            drawCircle(color = Color.White.copy(alpha = 0.08f), style = Stroke(width = stroke))
            drawArc(
                brush = MarviGradient.Brand,
                startAngle = -90f,
                sweepAngle = 360f * (score.coerceIn(0, 100) / 100f),
                useCenter = false,
                style = Stroke(width = stroke, cap = StrokeCap.Round)
            )
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("$score%", color = MarviColor.Ink, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.headlineMedium)
            Text(label, color = MarviColor.Muted, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.labelSmall)
        }
    }
}

@Composable
fun DeclineAcceptRow(declineTitle: String, acceptTitle: String, onDecline: () -> Unit, onAccept: () -> Unit, acceptEnabled: Boolean = true) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        Box(modifier = Modifier.weight(1f)) { SecondaryActionButton(declineTitle, onDecline) }
        Box(modifier = Modifier.weight(1f)) { PrimaryActionButton(acceptTitle, onAccept, enabled = acceptEnabled) }
    }
}
