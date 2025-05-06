plugins {
    id("com.android.application")
    id("kotlin-android")
    // El plugin de Flutter debe ir al final
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.front"
    compileSdk = flutter.compileSdkVersion

    // Forzamos la NDK que piden los plugins
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.front"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."  // ruta al módulo Flutter
}
