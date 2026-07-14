package com.marvisociety.app.network

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.ByteArrayOutputStream

/** Lightweight JPEG prep aligned with iOS `ImageUploadPreprocessor` profiles. */
object ImageUploadHelper {
    enum class Profile(val maxPx: Int, val quality: Int, val targetBytes: Int) {
        PROOF(maxPx = 2048, quality = 78, targetBytes = 2_000_000),
        AVATAR(maxPx = 1024, quality = 82, targetBytes = 900_000),
        COVER(maxPx = 1920, quality = 80, targetBytes = 1_800_000)
    }

    fun prepareJpeg(context: Context, uri: Uri, profile: Profile): ByteArray {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
            ?: throw MarviApiException("Could not read image")

        var sample = 1
        val longest = maxOf(bounds.outWidth, bounds.outHeight).coerceAtLeast(1)
        while (longest / sample > profile.maxPx * 2) sample *= 2

        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        val bitmap = context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, opts)
        } ?: throw MarviApiException("Could not decode image")

        val scaled = scaleDown(bitmap, profile.maxPx)
        if (scaled !== bitmap) bitmap.recycle()

        var quality = profile.quality
        var bytes = compress(scaled, quality)
        while (bytes.size > profile.targetBytes && quality > 55) {
            quality -= 8
            bytes = compress(scaled, quality)
        }
        scaled.recycle()
        if (bytes.size > 4_500_000) {
            throw MarviApiException("Image is too large after compression")
        }
        return bytes
    }

    private fun scaleDown(source: Bitmap, maxPx: Int): Bitmap {
        val longest = maxOf(source.width, source.height)
        if (longest <= maxPx) return source
        val scale = maxPx.toFloat() / longest
        val w = (source.width * scale).toInt().coerceAtLeast(1)
        val h = (source.height * scale).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(source, w, h, true)
    }

    private fun compress(bitmap: Bitmap, quality: Int): ByteArray {
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
        return out.toByteArray()
    }
}
