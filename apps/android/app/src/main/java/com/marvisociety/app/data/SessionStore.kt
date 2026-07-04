package com.marvisociety.app.data

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore("marvi_session")

class SessionStore(private val context: Context) {
    private val accessTokenKey = stringPreferencesKey("access_token")
    private val refreshTokenKey = stringPreferencesKey("refresh_token")
    private val snapshotKey = stringPreferencesKey("snapshot_json")

    suspend fun saveTokens(access: String?, refresh: String?) {
        context.dataStore.edit { prefs ->
            if (access.isNullOrBlank()) {
                prefs.remove(accessTokenKey)
                prefs.remove(refreshTokenKey)
            } else {
                prefs[accessTokenKey] = access
                if (refresh != null) prefs[refreshTokenKey] = refresh else prefs.remove(refreshTokenKey)
            }
        }
    }

    suspend fun loadTokens(): Pair<String?, String?> {
        val prefs = context.dataStore.data.first()
        return prefs[accessTokenKey] to prefs[refreshTokenKey]
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
                ?: AppLanguage.ENGLISH,
            languageManuallySet = bool("langManual"),
            pushNotificationsEnabled = bool("push", true),
            proofRemindersEnabled = bool("proof", true)
        )
    }

    suspend fun clearAll() {
        context.dataStore.edit { it.clear() }
    }
}
