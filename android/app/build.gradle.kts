import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.ariabod.dastyar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ariabod.dastyar"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                val rawPath = keystoreProperties.getProperty("storeFile") ?: ""
                val candidate = File(rawPath)
                storeFile = if (candidate.isAbsolute) candidate else rootProject.file(rawPath)
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // نسخهٔ انتشار بی‌صدا با کلید debug امضا نمی‌شود. اگر کلید نباشد،
            // ساخت release باید بشکند. فقط ساخت آزمایشی صریحاً اجازهٔ کلید
            // debug دارد (ورودی allow_debug_signing در build.yml → همین متغیر).
            val wantsRelease = gradle.startParameter.taskNames.any {
                it.contains("release", ignoreCase = true)
            }
            val allowDebug = System.getenv("ALLOW_DEBUG_SIGNING") == "true"
            signingConfig = when {
                keystorePropertiesFile.exists() -> signingConfigs.getByName("release")
                wantsRelease && !allowDebug -> throw GradleException(
                    "key.properties پیدا نشد؛ برای نسخهٔ انتشار کلید امضا لازم است " +
                        "(tools/setup_release_signing.py) یا ALLOW_DEBUG_SIGNING=true."
                )
                else -> signingConfigs.getByName("debug")
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
