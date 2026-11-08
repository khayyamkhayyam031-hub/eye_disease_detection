plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.khayyam.eyedisease"
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
        applicationId = "com.khayyam.eyedisease"
        // PRD: Android 7.0 (API 24) and above.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        // Store native libs compressed inside the APK (20 MB APK budget).
        // They are extracted once at install time.
        jniLibs {
            useLegacyPackaging = true
        }
    }

    androidResources {
        // Keep the model uncompressed (faster load).
        noCompress += "tflite"
    }

    buildTypes {
        release {
            // TODO: replace with your own release signing config before publishing.
            signingConfig = signingConfigs.getByName("debug")
            // R8 + resource shrinking (20 MB APK budget).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // LiteRT (TensorFlow Lite) CPU runtime with built-in XNNPACK. No GPU delegate (size).
    implementation("com.google.ai.edge.litert:litert:1.4.0")
}

flutter {
    source = "../.."
}
