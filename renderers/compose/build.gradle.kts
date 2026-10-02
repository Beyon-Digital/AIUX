plugins {
    id("com.android.library")
    kotlin("android")
    kotlin("plugin.serialization")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "aiux.compose"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
        unitTests.all {
            it.useJUnitPlatform()
            // JNA resolves libaiux_uniffi.so from these dirs on desktop JVM
            // (same pattern as bindings/kotlin).
            it.systemProperty(
                "jna.library.path",
                listOf("${rootDir}/target/debug", "${rootDir}/target/release")
                    .joinToString(File.pathSeparator),
            )
        }
    }
}

dependencies {
    implementation(project(":bindings:kotlin"))

    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    testImplementation(kotlin("test"))
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
    // Desktop JVM needs the JNA jar (with libjnidispatch) — the AAR variant
    // that bindings:kotlin exposes transitively only carries Android natives.
    testImplementation("net.java.dev.jna:jna:5.18.0")
}
