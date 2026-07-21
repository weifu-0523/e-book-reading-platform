import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("app/keys/keystore.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "dev.zhiyue.zhiyue"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.zhiyue.zhiyue"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // M7: 优先用 release keystore（keys/keystore.properties 存在时），
            // 不存在时 fallback debug（开发本机或 CI 无 keystore 也能 build）。
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }

    flavorDimensions += "fgs"
    productFlavors {
        create("withFgs") {
            dimension = "fgs"
        }
        create("noFgs") {
            dimension = "fgs"
        }
    }

    sourceSets {
        getByName("withFgs") {
            manifest.srcFile("src/with-fgs/AndroidManifest.xml")
        }
        getByName("noFgs") {
            manifest.srcFile("src/no-fgs/AndroidManifest.xml")
        }
    }

    // TTS POC T1: sherpa-onnx JNI 需要解压 .so 到 /data/app/.../lib/(非压缩路径),
    // 默认 extractNativeLibs=false 走压缩会导致加载失败。
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

dependencies {
    // T6+: Robolectric re-enabled (mirrors configured in root settings.gradle.kts
    // + build.gradle.kts route through Aliyun first to make android-all.jar
    // downloadable in CN networks).
    testImplementation("org.robolectric:robolectric:4.12.2")
    testImplementation("androidx.test:core:1.6.1")
    testImplementation("androidx.test.ext:junit:1.2.1")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
    // T8: MediaSessionCompat for lock screen + bluetooth headset controls.
    implementation("androidx.media:media:1.7.0")
}

// Workaround for Gradle 9.1 + Flutter plugin ordering: the unit-test
// packaging task needs flutter assets copied first. Without this,
// `package{Flavor}DebugUnitTestForUnitTest` reports an implicit-dependency
// violation. v1.13 T14: added per-flavor variants (withFgs / noFgs).
project.afterEvaluate {
    tasks.findByName("packageWithFgsDebugUnitTestForUnitTest")?.dependsOn("copyFlutterAssetsWithFgsDebug")
    tasks.findByName("packageNoFgsDebugUnitTestForUnitTest")?.dependsOn("copyFlutterAssetsNoFgsDebug")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
