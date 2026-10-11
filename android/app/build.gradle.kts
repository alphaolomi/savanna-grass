import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing lives outside the repo: android/key.properties (gitignored)
// points at a keystore kept on the maintainer's machine. Without it — CI, a
// fresh clone — release builds fall back to the debug key.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

android {
    namespace = "com.savannatime.savanna_grass"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications schedules with java.time, desugared for
        // the Android 7 floor (minSdk 24).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.savannatime.savanna_grass"
        minSdk = 24 // flutter_gemma (MediaPipe LLM inference)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    // flutter_gemma bundles native libraries for every feature it offers. Savanna
    // Grass runs a MediaPipe `.task` model only (libllm_inference_engine_jni), so
    // the LiteRT-LM (.litertlm), vision, image-generation, embedding and RAG
    // chunking libraries are dead weight — ~150 MB of an APK. Each is loaded only
    // by its own feature (checked in the plugin source), never at startup.
    packaging {
        jniLibs {
            excludes += listOf(
                // 64-bit ARM only: every phone that can run a 1B model on-device
                // is arm64. (Flutter's plugin overrides ndk.abiFilters.)
                "lib/x86/**",
                "lib/x86_64/**",
                "lib/armeabi-v7a/**",
                "**/liblitertlm_jni.so",
                "**/libgecko_embedding_model_jni.so",
                "**/libgemma_embedding_model_jni.so",
                "**/libmediapipe_tasks_vision_jni.so",
                "**/libmediapipe_tasks_vision_image_generator_jni.so",
                "**/libimagegenerator_gpu.so",
                "**/libtext_chunker_jni.so",
            )
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
