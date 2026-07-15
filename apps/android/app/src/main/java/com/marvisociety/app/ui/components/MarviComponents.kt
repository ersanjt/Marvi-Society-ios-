package com.marvisociety.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.theme.MarviGradient

@Composable
fun MarviScreen(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MarviColor.Surface)
    ) {
        // Ambient brand glow (mirrors iOS MarviScreen ellipse blur)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(280.dp)
                .align(Alignment.TopCenter)
                .offset(y = (-80).dp)
                .blur(80.dp)
                .background(MarviGradient.BrandVertical)
                .background(MarviColor.Surface.copy(alpha = 0.65f))
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
        verticalArrangement = Arrangement.spacedBy(8.dp),
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
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MarviColor.PanelElevated)
            .border(1.dp, MarviColor.Tomato.copy(alpha = 0.35f))
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            message,
            color = MarviColor.Ink,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.weight(1f),
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
        TextButton(onClick = onRetry) {
            Text(retryTitle, color = MarviColor.Rose, fontWeight = FontWeight.SemiBold)
        }
        TextButton(onClick = onDismiss) {
            Text("×", color = MarviColor.Muted, fontWeight = FontWeight.Bold)
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
            .clip(shape)
            .background(
                if (enabled) MarviGradient.Brand
                else Brush.horizontalGradient(listOf(MarviColor.Muted.copy(alpha = 0.4f), MarviColor.Muted.copy(alpha = 0.4f)))
            )
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 14.dp),
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
            .clip(shape)
            .background(MarviColor.PanelElevated)
            .border(1.dp, MarviColor.Border, shape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 12.dp),
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
        textStyle = TextStyle(color = MarviColor.Ink, fontSize = 15.sp),
        cursorBrush = SolidColor(MarviColor.Rose),
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(MarviColor.PanelElevated)
            .border(1.dp, MarviColor.Border, shape)
            .padding(12.dp),
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
fun EmptyStateView(title: String, subtitle: String, icon: ImageVector = Icons.Default.AutoAwesome) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Icon(icon, null, tint = MarviColor.Rose, modifier = Modifier.size(32.dp))
        Text(title, style = MaterialTheme.typography.headlineSmall, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
        Text(
            subtitle,
            style = MaterialTheme.typography.bodyMedium,
            color = MarviColor.Muted,
            modifier = Modifier.padding(horizontal = 24.dp)
        )
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
            .padding(horizontal = 12.dp, vertical = 8.dp)
    )
}

@Composable
fun SegmentedTabs(
    tabs: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(MarviColor.PanelElevated)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        tabs.forEachIndexed { index, label ->
            val selected = index == selectedIndex
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(10.dp))
                    .then(
                        if (selected) Modifier.background(MarviGradient.Brand)
                        else Modifier
                    )
                    .clickable { onSelect(index) }
                    .padding(vertical = 10.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    label,
                    color = if (selected) Color.White else MarviColor.Muted,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold
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
    tint: Color = MarviColor.Rose
) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(MarviColor.Panel)
            .border(1.dp, MarviColor.Border, CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
    }
}

@Composable
fun HomeHeader(
    greeting: String,
    subtitle: String,
    avatarUrl: String?,
    avatarLetter: String,
    trailing: @Composable (() -> Unit)? = null
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(MarviGradient.BrandVertical),
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
        Column(modifier = Modifier.weight(1f)) {
            Text(greeting, style = MaterialTheme.typography.headlineMedium, color = MarviColor.Ink, fontWeight = FontWeight.Bold)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MarviColor.Muted)
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
