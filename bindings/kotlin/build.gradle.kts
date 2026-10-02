import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    id("com.android.library")
    kotlin("android")
}

// UniFFI codegen + host native lib; skipped when bindings already exist
// (bindings/kotlin/generate.sh regenerates unconditionally — run it to refresh).
val uniffiGenerated = layout.buildDirectory.dir("generated/uniffi")
val generateUniffiBindings = tasks.register("generateUniffiBindings", Exec::class) {
    description = "UniFFI Kotlin bindings + native libraries via bindings/kotlin/generate.sh"
    commandLine("bash", "${rootDir}/bindings/kotlin/generate.sh")
    outputs.dir(uniffiGenerated)
    onlyIf { !uniffiGenerated.get().file("aiux/aiux.kt").asFile.exists() }
}
tasks.withType<KotlinCompile>().configureEach {
    dependsOn(generateUniffiBindings)
    compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
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
