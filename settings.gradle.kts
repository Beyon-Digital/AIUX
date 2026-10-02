rootProject.name = "aiux"

dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}

include("renderers:compose", "examples:android-native", "bindings:kotlin")
