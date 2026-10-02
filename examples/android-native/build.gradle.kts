plugins {
    id("com.android.application")
    kotlin("android")
    kotlin("plugin.serialization")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "aiux.example"
    compileSdk = 36

    defaultConfig {
        applicationId = "aiux.example"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "0.1"
    }

    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }

    // Ship the shared conformance catalog as app assets for the fixture browser.
    val copyConformanceFixtures = tasks.register<Copy>("copyConformanceFixtures") {
        from("${rootDir}/conformance/fixtures") { include("*.json") }
        into(layout.buildDirectory.dir("generated/assets/fixtures"))
    }
    sourceSets["main"].assets.srcDir(layout.buildDirectory.dir("generated/assets"))
    tasks.named("preBuild") { dependsOn(copyConformanceFixtures) }
}

dependencies {
    implementation(project(":renderers:compose"))
    implementation(project(":bindings:kotlin"))
    implementation(platform("androidx.compose:compose-bom:2024.12.01"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    testImplementation(kotlin("test"))
}
