import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}
fun readSigningValue(propertyKey: String, envKey: String): String? {
    val envValue = System.getenv(envKey)?.trim()
    if (!envValue.isNullOrBlank()) {
        return envValue
    }

    val propertyValue = (keystoreProperties[propertyKey] as String?)?.trim()
    if (!propertyValue.isNullOrBlank()) {
        return propertyValue
    }

    return null
}

val signingStoreFilePath = readSigningValue("storeFile", "SIGNING_STORE_FILE")
val signingStorePassword = readSigningValue("storePassword", "SIGNING_STORE_PASSWORD")
val signingKeyAlias = readSigningValue("keyAlias", "SIGNING_KEY_ALIAS")
val signingKeyPassword = readSigningValue("keyPassword", "SIGNING_KEY_PASSWORD")
val hasReleaseSigningConfig =
    !signingStoreFilePath.isNullOrBlank() &&
        !signingStorePassword.isNullOrBlank() &&
        !signingKeyAlias.isNullOrBlank() &&
        !signingKeyPassword.isNullOrBlank()
val adMobAppId =
    (project.findProperty("ADMOB_APP_ID") as String?)
        ?.takeIf { it.isNotBlank() }
        ?: "ca-app-pub-3940256099942544~3347511713"

android {
    namespace = "com.leonerdi.lotosmart"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.leonerdi.lotosmart"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = adMobAppId
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigningConfig) {
                storeFile = rootProject.file(signingStoreFilePath!!)
                storePassword = signingStorePassword
                keyAlias = signingKeyAlias
                keyPassword = signingKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (!hasReleaseSigningConfig) {
                throw GradleException(
                    "Release signing requires SIGNING_* environment variables or android/key.properties with production credentials.",
                )
            }
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-splashscreen:1.0.1")
}
