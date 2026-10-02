// swift-tools-version:5.9
import PackageDescription

// Local-dev package: `bash bindings/swift/generate.sh` produces the UniFFI
// sources + headers under Sources/ and the Rust static archive at
// Sources/AIUXCoreFFI/lib/libaiux_uniffi.a (gitignored — regenerated, never
// committed). The -L flag resolves relative to this package directory, so run
// `swift build`/`swift test` from bindings/swift (CI does).
//
// Distribution: `bash bindings/swift/package-xcframework.sh` produces
// AIUXCore.xcframework — vendor it via a binaryTarget in consumer packages
// (see bindings/swift/README.md) instead of this source layout.
let package = Package(
    name: "AIUXCore",
    products: [
        .library(name: "AIUXCore", targets: ["AIUXCore"])
    ],
    targets: [
        .target(
            name: "AIUXCoreFFI",
            path: "Sources/AIUXCoreFFI",
            exclude: ["lib"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "AIUXCore",
            dependencies: ["AIUXCoreFFI"],
            path: "Sources/AIUXCore",
            linkerSettings: [
                .unsafeFlags(["-LSources/AIUXCoreFFI/lib", "-laiux_uniffi"])
            ]
        ),
        .testTarget(
            name: "AIUXCoreTests",
            dependencies: ["AIUXCore"],
            path: "Tests/AIUXCoreTests"
        ),
    ]
)
