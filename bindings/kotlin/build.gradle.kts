import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    id("com.android.library")
    kotlin("android")
}

// UniFFI codegen + host native lib; up-to-date-checked on its Rust/script
// inputs so changed sources regenerate (bindings/kotlin/generate.sh
// regenerates unconditionally when it runs).
val uniffiGenerated = layout.buildDirectory.dir("generated/uniffi")
val uniffiJniLibs = layout.buildDirectory.dir("generated/jniLibs")
val generateUniffiBindings = tasks.register("generateUniffiBindings", Exec::class) {
    description = "UniFFI Kotlin bindings + native libraries via bindings/kotlin/generate.sh"
    commandLine("bash", "${rootDir}/bindings/kotlin/generate.sh")
    inputs.files(
        "${rootDir}/bindings/kotlin/generate.sh",
        "${rootDir}/bindings/uniffi/uniffi.toml",
        "${rootDir}/Cargo.toml",
        "${rootDir}/Cargo.lock",
    )
    inputs.dir("${rootDir}/core/rust")
    inputs.dir("${rootDir}/bindings/uniffi")
    outputs.dir(uniffiGenerated)
    outputs.dir(uniffiJniLibs)
}
tasks.withType<KotlinCompile>().configureEach {
    dependsOn(generateUniffiBindings)
    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
}
// AAR packaging consumes generated jniLibs — ordering must not depend on
// Kotlin compilation alone or a clean release can ship bindings without .so.
tasks.matching { it.name.endsWith("JniLibFolders") }.configureEach {
    dependsOn(generateUniffiBindings)
}

android {
    namespace = "aiux"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDir(uniffiGenerated)
            jniLibs.srcDir(layout.buildDirectory.dir("generated/jniLibs"))
        }
    }

    lint {
        // UniFFI-generated code guards java.lang.ref.Cleaner behind a runtime
        // Class.forName check (JNA fallback pre-API 33); NewApi can't see the
        // reflection guard. Baseline pins those known-generated issues.
        baseline = file("lint-baseline.xml")
    }

    testOptions {
        unitTests.all {
            it.useJUnitPlatform()
            // JNA resolves libaiux_uniffi.so from these dirs on desktop JVM.
            it.systemProperty(
                "jna.library.path",
                listOf("${rootDir}/target/debug", "${rootDir}/target/release")
                    .joinToString(File.pathSeparator),
            )
        }
    }
}

dependencies {
    // JNA is the FFI dispatch layer used by UniFFI-generated Kotlin (0.29).
    implementation("net.java.dev.jna:jna:5.18.0@aar")
    testImplementation("net.java.dev.jna:jna:5.18.0")
    testImplementation(kotlin("test"))
    // JVM-only JSON for reading conformance fixtures in unit tests.
    testImplementation("org.json:json:20250517")
}
