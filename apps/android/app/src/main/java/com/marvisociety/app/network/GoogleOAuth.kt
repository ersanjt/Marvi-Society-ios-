package com.marvisociety.app.network

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Base64
import androidx.browser.customtabs.CustomTabsIntent
import com.marvisociety.app.BuildConfig
import java.security.MessageDigest
import java.security.SecureRandom

/**
 * Google (Supabase OAuth) via Custom Tabs + PKCE — mirrors iOS GoogleSignInService.
 * Flow: authorize → marvisociety://auth/callback?code=… → exchange → session.
 */
object GoogleOAuth {
    const val CALLBACK_SCHEME = "marvisociety"
    const val CALLBACK_HOST = "auth"
    const val REDIRECT_URI = "marvisociety://auth/callback"

    data class Pending(
        val codeVerifier: String,
        val startedAtMs: Long = System.currentTimeMillis()
    )

    @Volatile
    var pending: Pending? = null
        private set

    fun isEnabled(): Boolean = BuildConfig.GOOGLE_SIGN_IN_ENABLED && BuildConfig.USE_REMOTE_BACKEND

    fun clearPending() {
        pending = null
    }

    fun start(context: Context) {
        val verifier = generateCodeVerifier()
        pending = Pending(codeVerifier = verifier)
        val challenge = codeChallenge(verifier)
        val url = buildAuthorizeUrl(challenge)
        CustomTabsIntent.Builder().build().launchUrl(context, Uri.parse(url))
    }

    fun isAuthCallback(uri: Uri): Boolean {
        if (!uri.scheme.equals(CALLBACK_SCHEME, ignoreCase = true)) return false
        if (!uri.host.equals(CALLBACK_HOST, ignoreCase = true)) return false
        val path = uri.path?.trim('/') ?: ""
        return path.equals("callback", ignoreCase = true) || path.isEmpty()
    }

    suspend fun completeIfPossible(uri: Uri, client: SupabaseClient): AuthSession? {
        if (!isAuthCallback(uri)) return null
        val verifier = pending?.codeVerifier
            ?: throw MarviApiException("Google sign-in expired. Try again.")
        clearPending()

        val error = uri.getQueryParameter("error_description")
            ?: uri.getQueryParameter("error")
        if (!error.isNullOrBlank()) {
            throw MarviApiException(error.replace('+', ' '))
        }

        val access = uri.getQueryParameter("access_token")
        if (!access.isNullOrBlank()) {
            val refresh = uri.getQueryParameter("refresh_token")
            client.setSession(access, refresh)
            return AuthSession(accessToken = access, refreshToken = refresh, userId = client.currentUserId())
        }

        val code = uri.getQueryParameter("code")
            ?: throw MarviApiException("Google sign-in did not return a session.")
        return client.exchangeAuthCode(code, verifier)
    }

    private fun buildAuthorizeUrl(challenge: String): String {
        val base = BuildConfig.SUPABASE_URL.trimEnd('/')
        val anon = BuildConfig.SUPABASE_ANON_KEY
        return buildString {
            append("$base/auth/v1/authorize?")
            append("provider=google")
            append("&redirect_to=${Uri.encode(REDIRECT_URI)}")
            append("&scopes=${Uri.encode("email profile")}")
            append("&apikey=${Uri.encode(anon)}")
            append("&code_challenge=${Uri.encode(challenge)}")
            append("&code_challenge_method=S256")
        }
    }

    private fun generateCodeVerifier(): String {
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        return base64Url(bytes)
    }

    private fun codeChallenge(verifier: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.UTF_8))
        return base64Url(digest)
    }

    private fun base64Url(bytes: ByteArray): String =
        Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
}

/** Open Google OAuth without tying Activity lifecycle to the helper. */
fun Context.launchGoogleSignIn() {
    GoogleOAuth.start(this)
}

fun Intent?.authCallbackUri(): Uri? {
    val data = this?.data ?: return null
    return if (GoogleOAuth.isAuthCallback(data)) data else null
}
