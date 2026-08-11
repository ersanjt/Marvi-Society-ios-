package com.marvisociety.app.network

import android.util.Base64
import com.marvisociety.app.BuildConfig
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.engine.android.Android
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.patch
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.ByteArrayContent
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class MarviApiException(message: String, val code: Int? = null) : Exception(message)

class SupabaseClient(
    private val baseUrl: String = BuildConfig.SUPABASE_URL.trimEnd('/'),
    private val anonKey: String = BuildConfig.SUPABASE_ANON_KEY
) {
    private var sessionObserver: (suspend (String?, String?) -> Unit)? = null
    private val refreshMutex = Mutex()
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    private val client = HttpClient(Android) {
        install(ContentNegotiation) { json(json) }
    }

    /** Empty base URL becomes relative `/…` → Android resolves `http://localhost` and blocks cleartext. */
    private fun requireConfiguredUrl() {
        if (baseUrl.isBlank()) {
            throw MarviApiException(
                "Supabase is not configured. Add MARVI_SUPABASE_URL to apps/android/local.properties and rebuild."
            )
        }
    }

    @Volatile
    var accessToken: String? = null
        private set

    @Volatile
    var refreshToken: String? = null
        private set

    val isAuthenticated: Boolean get() = !accessToken.isNullOrBlank()
    val usesRemoteBackend: Boolean get() = BuildConfig.USE_REMOTE_BACKEND

    fun setSession(access: String, refresh: String? = null) {
        accessToken = access
        refreshToken = refresh
    }

    fun setSessionObserver(observer: suspend (String?, String?) -> Unit) {
        sessionObserver = observer
    }

    fun clearSession() {
        accessToken = null
        refreshToken = null
    }

    fun currentUserId(): String? {
        val token = accessToken ?: return null
        return userIdFromJwt(token)
    }

    suspend fun signInWithEmail(email: String, password: String): AuthSession {
        val response = client.post("$baseUrl/auth/v1/token?grant_type=password") {
            applyHeaders(authenticated = false)
            setBody(buildJsonObject {
                put("email", email.trim())
                put("password", password)
            })
        }
        return parseAuthResponse(response)
    }

    suspend fun signUpWithEmail(email: String, password: String, metadata: Map<String, String>): AuthSession {
        val response = client.post("$baseUrl/auth/v1/signup") {
            applyHeaders(authenticated = false)
            setBody(buildJsonObject {
                put("email", email.trim())
                put("password", password)
                put("data", buildJsonObject {
                    metadata.forEach { (k, v) -> put(k, v) }
                })
            })
        }
        return parseAuthResponse(response)
    }

    suspend fun resetPassword(email: String) {
        val response = client.post("$baseUrl/auth/v1/recover") {
            applyHeaders(authenticated = false)
            setBody(buildJsonObject { put("email", email.trim()) })
        }
        validate(response)
    }

    suspend fun signOut() {
        val response = client.post("$baseUrl/auth/v1/logout") {
            applyHeaders(authenticated = true)
        }
        if (response.status.value != 401) validate(response)
        clearSession()
    }

    suspend fun refreshSession() {
        val refresh = refreshToken ?: throw MarviApiException("No refresh token")
        val response = client.post("$baseUrl/auth/v1/token?grant_type=refresh_token") {
            applyHeaders(authenticated = false)
            setBody(buildJsonObject { put("refresh_token", refresh) })
        }
        parseAuthResponse(response)
    }

    /** Call edge functions under /functions/v1/{name}. */
    suspend fun invokeFunction(name: String, body: JsonObject): String {
        val response = authenticatedRequest {
            client.post("$baseUrl/functions/v1/$name") {
                applyHeaders(authenticated = true)
                setBody(body)
            }
        }
        validate(response)
        return response.bodyAsText()
    }

    /**
     * Runs [block]; on 401 refreshes the session once and retries.
     * Caller should persist tokens after success via [accessToken]/[refreshToken].
     */
    suspend fun <T> withAuthRetry(block: suspend () -> T): T {
        return try {
            block()
        } catch (error: MarviApiException) {
            if (error.code != 401 || refreshToken.isNullOrBlank()) throw error
            refreshSession()
            block()
        }
    }

    /** PKCE exchange after Google (or other OAuth) redirect — mirrors iOS GoogleSignInService. */
    suspend fun exchangeAuthCode(code: String, codeVerifier: String): AuthSession {
        val response = client.post("$baseUrl/auth/v1/token?grant_type=pkce") {
            applyHeaders(authenticated = false)
            setBody(buildJsonObject {
                put("auth_code", code)
                put("code_verifier", codeVerifier)
            })
        }
        return parseAuthResponse(response)
    }

    suspend fun <T> select(
        table: String,
        query: Map<String, String> = emptyMap(),
        decode: (JsonElement) -> T
    ): T {
        val queryString = query.entries.joinToString("&") { (k, v) ->
            "${k}=${java.net.URLEncoder.encode(v, Charsets.UTF_8.name())}"
        }
        val url = buildString {
            append("$baseUrl/rest/v1/$table")
            if (queryString.isNotEmpty()) append("?$queryString")
        }
        val response = authenticatedRequest {
            client.get(url) { applyHeaders(authenticated = true) }
        }
        validate(response)
        return decode(response.body())
    }

    suspend fun rpcBool(function: String, body: JsonObject): Boolean {
        val response = authenticatedRequest {
            client.post("$baseUrl/rest/v1/rpc/$function") {
                applyHeaders(authenticated = true)
                header("Prefer", "return=representation")
                setBody(body)
            }
        }
        validate(response)
        val text = response.bodyAsText().trim()
        if (text.equals("true", ignoreCase = true)) return true
        if (text.equals("false", ignoreCase = true)) return false
        return text.toBooleanStrictOrNull() ?: false
    }

    suspend fun rpcVoid(function: String, body: JsonObject) {
        val response = authenticatedRequest {
            client.post("$baseUrl/rest/v1/rpc/$function") {
                applyHeaders(authenticated = true)
                setBody(body)
            }
        }
        validate(response)
    }

    suspend fun rpcJson(function: String, body: JsonObject): JsonElement {
        val response = authenticatedRequest {
            client.post("$baseUrl/rest/v1/rpc/$function") {
                applyHeaders(authenticated = true)
                header("Prefer", "return=representation")
                setBody(body)
            }
        }
        validate(response)
        return response.body()
    }

    suspend fun insert(table: String, body: JsonObject) {
        val response = authenticatedRequest {
            client.post("$baseUrl/rest/v1/$table") {
                applyHeaders(authenticated = true)
                header("Prefer", "return=minimal")
                setBody(body)
            }
        }
        validate(response)
    }

    suspend fun patch(table: String, filters: Map<String, String>, body: JsonObject) {
        val query = filters.entries.joinToString("&") { (k, v) ->
            "$k=${java.net.URLEncoder.encode(v, Charsets.UTF_8.name())}"
        }
        val response = authenticatedRequest {
            client.patch("$baseUrl/rest/v1/$table?$query") {
                applyHeaders(authenticated = true)
                setBody(body)
            }
        }
        validate(response)
    }

    suspend fun delete(table: String, filters: Map<String, String>) {
        val query = filters.entries.joinToString("&") { (k, v) ->
            "$k=${java.net.URLEncoder.encode(v, Charsets.UTF_8.name())}"
        }
        val response = authenticatedRequest {
            client.delete("$baseUrl/rest/v1/$table?$query") {
                applyHeaders(authenticated = true)
            }
        }
        validate(response)
    }

    /**
     * Raw binary Storage upload — mirrors iOS `SupabaseClient.uploadObject`.
     * Returns the relative object path (not a signed URL).
     */
    suspend fun uploadObject(
        bucket: String,
        path: String,
        data: ByteArray,
        contentType: String
    ): String {
        val cleanPath = path.trimStart('/')
        val url = "$baseUrl/storage/v1/object/$bucket/$cleanPath"
        val response = authenticatedRequest {
            client.post(url) {
                header("apikey", anonKey)
                header(
                    "Authorization",
                    if (!accessToken.isNullOrBlank()) "Bearer $accessToken" else "Bearer $anonKey"
                )
                header("x-upsert", "true")
                setBody(ByteArrayContent(data, ContentType.parse(contentType)))
            }
        }
        validate(response)
        return cleanPath
    }

    fun publicStorageUrl(bucket: String, path: String, cacheBust: Boolean = true): String {
        val cleanPath = path.trimStart('/')
        val base = "$baseUrl/storage/v1/object/public/$bucket/$cleanPath"
        return if (cacheBust) "$base?v=${System.currentTimeMillis()}" else base
    }

    private suspend fun parseAuthResponse(response: HttpResponse): AuthSession {
        validate(response)
        val obj = response.body<JsonObject>()
        val access = obj.string("access_token")
            ?: throw MarviApiException(
                "We sent a confirmation link to your email. Open it to verify your account, then come back and sign in."
            )
        val refresh = obj.string("refresh_token")
        setSession(access, refresh)
        sessionObserver?.invoke(access, refresh)
        return AuthSession(accessToken = access, refreshToken = refresh, userId = userIdFromJwt(access))
    }

    private suspend fun authenticatedRequest(block: suspend () -> HttpResponse): HttpResponse {
        val tokenUsed = accessToken
        val response = block()
        if (response.status != HttpStatusCode.Unauthorized || refreshToken.isNullOrBlank()) {
            return response
        }
        response.bodyAsText()
        refreshMutex.withLock {
            if (accessToken == tokenUsed) refreshSession()
        }
        return block()
    }

    private fun io.ktor.client.request.HttpRequestBuilder.applyHeaders(authenticated: Boolean) {
        requireConfiguredUrl()
        contentType(ContentType.Application.Json)
        header("apikey", anonKey)
        header(
            "Authorization",
            if (authenticated && !accessToken.isNullOrBlank()) "Bearer $accessToken" else "Bearer $anonKey"
        )
    }

    private suspend fun validate(response: HttpResponse) {
        if (response.status == HttpStatusCode.Unauthorized) {
            throw MarviApiException("Session expired", 401)
        }
        if (!response.status.isSuccess()) {
            val text = runCatching { response.bodyAsText() }.getOrDefault("")
            val message = runCatching {
                json.parseToJsonElement(text).jsonObject.string("message")
                    ?: json.parseToJsonElement(text).jsonObject.string("error_description")
                    ?: json.parseToJsonElement(text).jsonObject.string("msg")
                    ?: json.parseToJsonElement(text).jsonObject.string("error")
            }.getOrNull() ?: text.ifBlank { "Request failed (${response.status.value})" }
            throw MarviApiException(message, response.status.value)
        }
    }

    private fun userIdFromJwt(jwt: String): String? {
        val parts = jwt.split('.')
        if (parts.size < 2) return null
        val payload = parts[1]
        val padded = payload + "=".repeat((4 - payload.length % 4) % 4)
        val decoded = Base64.decode(padded, Base64.URL_SAFE or Base64.NO_WRAP)
        val obj = runCatching { json.parseToJsonElement(String(decoded)).jsonObject }.getOrNull() ?: return null
        return obj.string("sub")
    }
}

data class AuthSession(
    val accessToken: String,
    val refreshToken: String?,
    val userId: String?
)

fun JsonObject.string(key: String): String? {
    val el = this[key] ?: return null
    if (el is JsonNull) return null
    val value = if (el is JsonPrimitive && el.isString) el.content else el.toString().trim('"')
    // Guard against JSON/text nulls that would otherwise render as the literal "null".
    return value.takeIf { it.isNotEmpty() && !it.equals("null", ignoreCase = true) }
}

fun JsonObject.int(key: String): Int? = this[key]?.jsonPrimitive?.content?.toIntOrNull()

fun JsonObject.bool(key: String): Boolean? = this[key]?.jsonPrimitive?.content?.toBooleanStrictOrNull()

fun JsonObject.double(key: String): Double? = this[key]?.jsonPrimitive?.content?.toDoubleOrNull()

fun JsonElement.asObjectOrNull(): JsonObject? = this as? JsonObject

fun JsonElement.asArrayOrEmpty() = if (this is kotlinx.serialization.json.JsonArray) this else jsonArrayOf()

private fun jsonArrayOf(): JsonArray = JsonArray(emptyList())

fun JsonElement.stringList(key: String): List<String> {
    val arr = this.asObjectOrNull()?.get(key) ?: return emptyList()
    if (arr !is kotlinx.serialization.json.JsonArray) return emptyList()
    return arr.mapNotNull { it.jsonPrimitive.contentOrNull }
}

private val JsonPrimitive.contentOrNull: String?
    get() = if (isString) content else null
