import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // wires google-services.json in — applied below, only when the file is there
    id("com.google.gms.google-services") apply false
}

// The Google Services plugin fails the whole build when google-services.json is
// missing. PushService already degrades to "no push" in that case (see its
// init()), so apply the plugin only when the file is actually present — a fresh
// clone still builds and runs, it just gets no notifications.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn(
        "google-services.json not found in android/app — building without Firebase; " +
            "push notifications will be disabled.",
    )
}

// Release signing. key.properties holds the upload keystore path and passwords
// and is gitignored, so it never leaves this machine — a fresh clone or CI has
// no key.properties and falls back to the debug keys below rather than failing.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.lokinter.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.15729638" // newest NDK installed locally, and above the 28.2 that integration_test asks for — pinned so the build never fetches one

    compileOptions {
        // flutter_local_notifications v21+ is built against Java 17 and needs
        // library desugaring for its date/time APIs on older Android versions
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lokinter.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // left unconfigured when key.properties is missing; the release
            // build type checks for that and uses the debug key instead
            keystoreProperties.getProperty("storeFile")?.let { path ->
                storeFile = file(path)
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // the upload key Play Console expects; debug keys only as a fallback
            // so `flutter run --release` still works without key.properties
            signingConfig = if (keystoreProperties.getProperty("storeFile") != null) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("android/key.properties not found — signing the release build with DEBUG keys. This build cannot be uploaded to Play.")
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // the styles above extend Theme.MaterialComponents, which flutter_stripe's
    // payment sheet needs — pull the library in explicitly so it always resolves
    implementation("com.google.android.material:material:1.12.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
