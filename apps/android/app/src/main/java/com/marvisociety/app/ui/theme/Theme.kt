package com.marvisociety.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Emerald = Color(0xFF1F7A5C)
private val Ink = Color(0xFF1A1A1F)
private val Surface = Color(0xFFF7F5F0)
private val Gold = Color(0xFFC9A227)

private val LightColors = lightColorScheme(
    primary = Emerald,
    onPrimary = Color.White,
    secondary = Gold,
    background = Surface,
    onBackground = Ink,
    surface = Color.White,
    onSurface = Ink
)

@Composable
fun MarviTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = LightColors, content = content)
}
