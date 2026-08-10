package com.marvisociety.app.data

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

private val Context.dataStore by preferencesDataStore("marvi_session")

class SessionStore(private val context: Context) {
    private val accessTokenKey = stringPreferencesKey("access_token")
    private val refreshTokenKey = stringPreferencesKey("refresh_token")
    private val snapshotKey = stringPreferencesKey("snapshot_json")
    private val securePreferences = context.getSharedPreferences("marvi_secure_session", Context.MODE_PRIVATE)

    private val keyStore: KeyStore by lazy {
        KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    }

    private fun secretKey(): SecretKey {
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE).run {
            init(
                KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .build()
            )
            generateKey()
        }
    }

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        val payload = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(payload, Base64.NO_WRAP)
    }

    private fun decrypt(value: String): String? = runCatching {
        val payload = Base64.decode(value, Base64.NO_WRAP)
        require(payload.size > GCM_IV_BYTES)
        val iv = payload.copyOfRange(0, GCM_IV_BYTES)
        val encrypted = payload.copyOfRange(GCM_IV_BYTES, payload.size)
        Cipher.getInstance(TRANSFORMATION).run {
            init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
            String(doFinal(encrypted), Charsets.UTF_8)
        }
    }.getOrNull()

    suspend fun saveTokens(access: String?, refresh: String?) {
        if (access.isNullOrBlank()) {
            securePreferences.edit().remove(SECURE_SESSION_KEY).apply()
        } else {
            securePreferences.edit()
                .putString(SECURE_SESSION_KEY, encrypt("$access\n${refresh.orEmpty()}"))
                .apply()
        }
        removeLegacyPlaintextTokens()
    }

    suspend fun loadTokens(): Pair<String?, String?> {
        securePreferences.getString(SECURE_SESSION_KEY, null)?.let { encrypted ->
            decrypt(encrypted)?.let { plaintext ->
                val parts = plaintext.split('\n', limit = 2)
                return parts.firstOrNull() to parts.getOrNull(1)?.takeIf(String::isNotBlank)
            }
            securePreferences.edit().remove(SECURE_SESSION_KEY).apply()
        }

        // One-time migration from releases that persisted JWTs in plaintext DataStore.
        val prefs = context.dataStore.data.first()
        val legacy = prefs[accessTokenKey] to prefs[refreshTokenKey]
        if (!legacy.first.isNullOrBlank()) saveTokens(legacy.first, legacy.second)
        return legacy
    }

    private suspend fun removeLegacyPlaintextTokens() {
        context.dataStore.edit { prefs ->
            prefs.remove(accessTokenKey)
            prefs.remove(refreshTokenKey)
        }
    }

    suspend fun saveSnapshot(snapshot: AppSnapshot) {
        val json = buildString {
            append("{")
            append("\"onboarding\":${snapshot.hasCompletedOnboarding},")
            append("\"role\":\"${snapshot.selectedRole.name}\",")
            append("\"lang\":\"${snapshot.preferredLanguage.name}\",")
            append("\"langManual\":${snapshot.languageManuallySet},")
            append("\"push\":${snapshot.pushNotificationsEnabled},")
            append("\"proof\":${snapshot.proofRemindersEnabled}")
            append("}")
        }
        context.dataStore.edit { it[snapshotKey] = json }
    }

    suspend fun loadSnapshot(): AppSnapshot {
        val raw = context.dataStore.data.map { it[snapshotKey] }.first() ?: return AppSnapshot()
        fun bool(key: String, default: Boolean = false): Boolean =
            Regex("""\"$key\":(true|false)""").find(raw)?.groupValues?.get(1)?.toBooleanStrictOrNull() ?: default
        fun str(key: String): String? =
            Regex("""\"$key\":\"([^\"]+)\"""").find(raw)?.groupValues?.get(1)
        return AppSnapshot(
            hasCompletedOnboarding = bool("onboarding"),
            selectedRole = str("role")?.let { runCatching { UserRole.valueOf(it) }.getOrNull() } ?: UserRole.CREATOR,
            preferredLanguage = str("lang")?.let { runCatching { AppLanguage.valueOf(it) }.getOrNull() }
                ?: AppLanguage.TURKISH,
            languageManuallySet = bool("langManual"),
            pushNotificationsEnabled = bool("push", true),
            proofRemindersEnabled = bool("proof", true)
        )
    }

    suspend fun clearAll() {
        securePreferences.edit().clear().apply()
        context.dataStore.edit { it.clear() }
    }

    private companion object {
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val KEY_ALIAS = "marvi_session_aes_v1"
        const val SECURE_SESSION_KEY = "encrypted_tokens"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val GCM_IV_BYTES = 12
        const val GCM_TAG_BITS = 128
    }
}
