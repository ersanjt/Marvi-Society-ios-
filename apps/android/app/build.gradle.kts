import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

val localProps = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

fun prop(name: String, default: String = ""): String =
    localProps.getProperty(name)?.trim()?.replace("\"", "\\\"") ?: default

val keystoreProps = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

fun keystoreProp(name: String): String? =
    keystoreProps.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }

android {
    namespace = "com.marvisociety.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.marvisociety.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 39
        versionName = "1.4.8"

        buildConfigField("String", "SUPABASE_URL", "\"${prop("MARVI_SUPABASE_URL")}\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${prop("MARVI_SUPABASE_ANON_KEY")}\"")
        buildConfigField(
            "boolean",
            "USE_REMOTE_BACKEND",
            "${prop("MARVI_API_MODE", "supabase") == "supabase" && prop("MARVI_SUPABASE_URL").isNotEmpty()}"
        )
        buildConfigField(
            "boolean",
            "GOOGLE_SIGN_IN_ENABLED",
            "${prop("MARVI_GOOGLE_SIGN_IN_ENABLED", "true") == "true"}"
        )
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProp("storeFile")
            if (storeFilePath != null) {
                storeFile = rootProject.file(storeFilePath)
                storePassword = keystoreProp("storePassword")
                keyAlias = keystoreProp("keyAlias")
                keyPassword = keystoreProp("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            val releaseSigning = signingConfigs.getByName("release")
            if (releaseSigning.storeFile?.exists() == true) {
                signingConfig = releaseSigning
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2025.01.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.10.0")
    implementation("androidx.navigation:navigation-compose:2.8.6")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.datastore:datastore-preferences:1.1.2")
    implementation("androidx.browser:browser:1.8.0")
    implementation("io.coil-kt:coil-compose:2.7.0")
    implementation("io.ktor:ktor-client-android:3.0.3")
    implementation("io.ktor:ktor-client-content-negotiation:3.0.3")
    implementation("io.ktor:ktor-serialization-kotlinx-json:3.0.3")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.0")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
