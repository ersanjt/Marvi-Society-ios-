package com.marvisociety.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val MarviDark = darkColorScheme(
    primary = MarviColor.Rose,
    onPrimary = Color.White,
    secondary = MarviColor.Gold,
    onSecondary = MarviColor.InkOnLight,
    tertiary = MarviColor.Emerald,
    background = MarviColor.Surface,
    onBackground = MarviColor.Ink,
    surface = MarviColor.Panel,
    onSurface = MarviColor.Ink,
    surfaceVariant = MarviColor.PanelElevated,
    onSurfaceVariant = MarviColor.Graphite,
    error = MarviColor.Tomato,
    outline = MarviColor.Border
)

@Composable
fun MarviTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = MarviDark,
        content = content
    )
}
