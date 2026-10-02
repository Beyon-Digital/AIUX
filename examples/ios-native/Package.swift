// swift-tools-version: 5.9
import PackageDescription

// The iOS example: a SwiftUI app over AIUXSwiftUI + the real UniFFI core
// (AIUXCore), plus a headless executable that runs the mocked agent scenario
// end-to-end — the Phase 3 gate (docs/PLAN.md §16).
//
// Layout:
//   AIUXExampleApp   — library: UniFFI backend adapter, demo controller,
//                      SwiftUI root view + fixture catalog player, and the
//                      `AIUXExampleApp` App struct an .xcodeproj hosts.
//   AIUXExample      — executable: `swift run AIUXExample` plays the mocked
//                      scenario headlessly and asserts each stage.
//   AIUXExampleTests — XCTest: scenario assertions + conformance replay of
//                      every fixture through UniFFI, compared semantically
//                      against conformance/expected/*.json.
//
// Building the bindings targets requires `bash bindings/swift/generate.sh`
// first (it produces the gitignored UniFFI sources + static archive; CI does
// this before `swift build`).
let package = Package(
    name: "AIUXExample",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "AIUXExampleApp", targets: ["AIUXExampleApp"]),
        .executable(name: "AIUXExample", targets: ["AIUXExample"]),
    ],
    dependencies: [
        .package(path: "../../renderers/swiftui"),
        .package(path: "../../bindings/swift"),
    ],
    targets: [
        .target(
            name: "AIUXExampleApp",
            dependencies: [
                .product(name: "AIUXSwiftUI", package: "swiftui"),
                .product(name: "AIUXCore", package: "swift"),
            ]
        ),
        .executableTarget(
            name: "AIUXExample",
            dependencies: ["AIUXExampleApp"],
            // Belt-and-suspenders: the bindings package declares its own -L,
            // but its relative path anchors to its own directory; this one
            // anchors to this package. At least one resolves correctly.
            linkerSettings: [
                .unsafeFlags(["-L../../bindings/swift/Sources/AIUXCoreFFI/lib"])
            ]
        ),
        .testTarget(
            name: "AIUXExampleTests",
            dependencies: ["AIUXExampleApp"],
            linkerSettings: [
                .unsafeFlags(["-L../../bindings/swift/Sources/AIUXCoreFFI/lib"])
            ]
        ),
    ]
)
