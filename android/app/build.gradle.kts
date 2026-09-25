plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "jp.neoenox.michiake"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "jp.neoenox.michiake"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val uploadSigning = listOf(
        "MICHIAKE_UPLOAD_STORE_FILE",
        "MICHIAKE_UPLOAD_STORE_PASSWORD",
        "MICHIAKE_UPLOAD_KEY_ALIAS",
        "MICHIAKE_UPLOAD_KEY_PASSWORD",
    ).associateWith { System.getenv(it) }
    val hasUploadSigning = uploadSigning.values.all { it != null }
    require(hasUploadSigning || uploadSigning.values.all { it == null }) {
        "Configure all MICHIAKE_UPLOAD_* release signing variables or leave all unset."
    }
    if (hasUploadSigning) {
        signingConfigs {
            create("release") {
                storeFile = file(uploadSigning.getValue("MICHIAKE_UPLOAD_STORE_FILE")!!)
                storePassword = uploadSigning.getValue("MICHIAKE_UPLOAD_STORE_PASSWORD")
                keyAlias = uploadSigning.getValue("MICHIAKE_UPLOAD_KEY_ALIAS")
                keyPassword = uploadSigning.getValue("MICHIAKE_UPLOAD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            if (hasUploadSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

