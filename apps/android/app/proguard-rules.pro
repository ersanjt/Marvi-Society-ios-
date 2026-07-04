-keep class com.marvisociety.app.** { *; }
-keepattributes *Annotation*

# Kotlin serialization (RPC JSON)
-keepclassmembers class kotlinx.serialization.json.** { *; }
-keep @kotlinx.serialization.Serializable class com.marvisociety.app.** { *; }

# Ktor
-dontwarn io.ktor.**
-keep class io.ktor.** { *; }

# Compose
-dontwarn androidx.compose.**
