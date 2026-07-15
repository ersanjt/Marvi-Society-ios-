@file:OptIn(ExperimentalTextApi::class)

package com.marvisociety.app.ui.theme

import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import com.marvisociety.app.R

// Bundled fonts that mirror the iOS design language so Android renders the same
// letterforms as the SwiftUI app instead of the platform defaults (Roboto/Noto):
//   - Inter      → stand-in for San Francisco (SF), the iOS system sans.
//   - Newsreader → stand-in for New York, the .serif design used for iOS display titles.
// Both are variable fonts; we pin the weight axis per FontWeight so Compose selects
// the correct instance from the single bundled file. These are bundled (not fetched
// via the Google Fonts provider) so they render on devices without Google Play
// Services (e.g. the TECNO KM8n test device).

private fun interFont(weight: Int) = Font(
    resId = R.font.inter,
    weight = FontWeight(weight),
    variationSettings = FontVariation.Settings(FontVariation.weight(weight))
)

private fun newsreaderFont(weight: Int) = Font(
    resId = R.font.newsreader,
    weight = FontWeight(weight),
    variationSettings = FontVariation.Settings(FontVariation.weight(weight))
)

/** SF substitute — used for all body/label/title text. */
val InterFamily = FontFamily(
    interFont(400),
    interFont(500),
    interFont(600),
    interFont(700)
)

/** New York substitute — used only for large serif display/hero titles. */
val NewsreaderFamily = FontFamily(
    newsreaderFont(500),
    newsreaderFont(600),
    newsreaderFont(700)
)
