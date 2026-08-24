import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.shunshi.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.shunshi.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    val isReleaseBuild = gradle.startParameter.taskNames.any {
        it.lowercase().contains("release")
    }
    val allowDebugReleaseSigning =
        System.getenv("ALLOW_DEBUG_RELEASE_SIGNING") == "true"
    val codemagicKeystorePath = System.getenv("CM_KEYSTORE_PATH")
    val hasCodemagicSigning = listOf(
        "CM_KEYSTORE_PATH",
        "CM_KEYSTORE_PASSWORD",
        "CM_KEY_ALIAS",
        "CM_KEY_PASSWORD",
    ).all { !System.getenv(it).isNullOrBlank() }
    if (keystorePropertiesFile.exists()) {
        // 以 UTF-8 读取（Properties.load(InputStream) 默认 ISO-8859-1，会损坏中文路径）
        keystorePropertiesFile.bufferedReader(Charsets.UTF_8).use { keystoreProperties.load(it) }
    } else if (isReleaseBuild && !hasCodemagicSigning && !allowDebugReleaseSigning) {
        throw GradleException(
            "Release keystore is required. Add android/key.properties, configure " +
                "Codemagic signing, or set ALLOW_DEBUG_RELEASE_SIGNING=true " +
                "for CI smoke builds only."
        )
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            } else if (hasCodemagicSigning) {
                storeFile = file(codemagicKeystorePath!!)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists() || hasCodemagicSigning) {
                signingConfigs.getByName("release")
            } else if (allowDebugReleaseSigning) {
                signingConfigs.getByName("debug")
            } else {
                null
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
