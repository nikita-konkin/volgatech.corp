import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key, from android/key.properties (kept locally, written by
// the Release workflow from repository secrets; never committed). Every
// published APK must carry the same key, or Android refuses to update the
// installed app ("package conflicts with an existing package"). A storeFile
// starting with ~/ is in the home folder, so one key.properties serves both
// the Mac and Windows.
val releaseKey = Properties().apply {
    rootProject.file("key.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}

android {
    namespace = "net.volgatech.volgatech_pro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    val dartDefines = providers.gradleProperty("dart-defines").orNull.orEmpty()
    if (dartDefines.split(',').any {
            String(Base64.getDecoder().decode(it), Charsets.UTF_8) == "STORE=rustore"
        }) {
        buildTypes.configureEach {
            sourceSets.maybeCreate(name).manifest.srcFile("src/rustore/AndroidManifest.xml")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications schedules with java.time, which
        // Android before 8 lacks.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "net.volgatech.volgatech_pro"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Old-device reach: minSdk stays at Flutter's default (24 = Android 7.0,
        // 2016) — Flutter's "Upgrading build.gradle.kts" migration resets a
        // hardcoded value on every build, and 24 already covers ~all live
        // devices. (flutter_secure_storage's encrypted prefs need >= 23 anyway.)
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!releaseKey.isEmpty) {
            create("release") {
                storeFile = file(releaseKey.getProperty("storeFile").let {
                    if (it.startsWith("~/")) System.getProperty("user.home") + it.substring(1) else it
                })
                storePassword = releaseKey.getProperty("storePassword")
                keyAlias = releaseKey.getProperty("keyAlias")
                keyPassword = releaseKey.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Without key.properties (CI checks, other machines) fall back to
            // the local debug key: fine for testing, never for a release.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
