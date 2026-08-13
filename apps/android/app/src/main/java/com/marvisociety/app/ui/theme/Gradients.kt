package com.marvisociety.app.ui.theme

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

/** Mirrors iOS `MarviGradient`. */
object MarviGradient {
    val Brand: Brush = Brush.horizontalGradient(
        colors = listOf(MarviColor.Rose, MarviColor.Aubergine)
    )

    val BrandVertical: Brush = Brush.linearGradient(
        colors = listOf(MarviColor.Rose, MarviColor.Aubergine, Color(0xFF4C1D95)),
        start = Offset.Zero,
        end = Offset.Infinite
    )

    val Warm: Brush = Brush.linearGradient(
        colors = listOf(
            MarviColor.Rose.copy(alpha = 0.18f),
            MarviColor.Aubergine.copy(alpha = 0.14f),
            MarviColor.Surface
        ),
        start = Offset.Zero,
        end = Offset.Infinite
    )

    val Cool: Brush = Brush.linearGradient(
        colors = listOf(
            MarviColor.Aubergine.copy(alpha = 0.16f),
            MarviColor.Rose.copy(alpha = 0.08f),
            MarviColor.Surface
        ),
        start = Offset(Float.POSITIVE_INFINITY, 0f),
        end = Offset(0f, Float.POSITIVE_INFINITY)
    )

    val HeroOverlay: Brush = Brush.verticalGradient(
        colors = listOf(
            Color.Transparent,
            MarviColor.Surface.copy(alpha = 0.4f),
            MarviColor.Surface
        )
    )

    val TopFade: Brush = Brush.verticalGradient(
        colors = listOf(MarviColor.Surface, MarviColor.Surface.copy(alpha = 0f))
    )
}

/** Tab bar selected tint — brand rose. */
val TabSelected = Color(0xFFFF2D78)
val TabBarBackground = Color(0xFF050508)
