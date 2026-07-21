plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

android {
    namespace = "com.tuantuan.go.tuantuan_go_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("tuantuan") {
            keyAlias = localProperties.getProperty("tuantuan.keyAlias")
            keyPassword = localProperties.getProperty("tuantuan.keyPassword")
            storePassword = localProperties.getProperty("tuantuan.storePassword")
            localProperties.getProperty("tuantuan.storeFile")?.let {
                storeFile = file(it)
            }
        }
    }

    defaultConfig {
        applicationId = "tuantuan.UNI75D75BA"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("tuantuan")
        }
        release {
            signingConfig = signingConfigs.getByName("tuantuan")
        }
    }
}

flutter {
    source = "../.."
}
