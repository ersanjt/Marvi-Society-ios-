package com.marvisociety.app.ui.theme

import androidx.compose.ui.graphics.Color

object MarviColor {
    val Ink = Color(0xFFF5F5F7)
    val InkOnLight = Color(0xFF1C1C1E)
    val Graphite = Color(0xFFC8C8CC)
    /** OLED near-black — matches landing. */
    val Surface = Color(0xFF000000)
    val SurfaceCool = Color(0xFF07070A)
    val Panel = Color(0xFF121214)
    val PanelElevated = Color(0xFF1A1A1E)
    /** Success / confirmed only. */
    val Emerald = Color(0xFF34D399)
    /** Brand violet — matches landing gradient end. */
    val Aubergine = Color(0xFF8B5CF6)
    /** Highlight / pending — brand-aligned (not literal gold). Prefer Rose in new UI. */
    val Gold = Color(0xFFFF2D78)
    /** Brand pink — matches landing CTA / gradient start. */
    val Rose = Color(0xFFFF2D78)
    /** Error / destructive only. */
    val Tomato = Color(0xFFFF6B6B)
    /** Info — brand-aligned (not sky blue). Prefer Aubergine in new UI. */
    val Blue = Color(0xFF8B5CF6)
    val Muted = Color(0xFF8E8E93)
    val Border = Color.White.copy(alpha = 0.08f)
}
