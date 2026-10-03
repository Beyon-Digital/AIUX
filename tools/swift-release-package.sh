#!/usr/bin/env bash
# Run after Apple generation on CI. No unsafe linker flags or repo-relative paths.
set -euo pipefail
out="${1:-dist/swift-package}"
mkdir -p "$out/Sources"
cp -R bindings/swift/build/xcframework/AIUXCore.xcframework "$out/"
cp -R bindings/swift/build/xcframework/Sources/AIUXCore "$out/Sources/"
cp -R renderers/swiftui/Sources/AIUXSwiftUI "$out/Sources/"
cp LICENSE "$out/"
node tools/third-party-notices.mjs
cp -R dist/third-party "$out/LICENSES"
cat > "$out/Package.swift" <<'SWIFT'
// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "AIUX",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "AIUXCore", targets: ["AIUXCore"]),
        .library(name: "AIUXSwiftUI", targets: ["AIUXSwiftUI"]),
    ],
    targets: [
        .binaryTarget(name: "AIUXCoreFFI", path: "AIUXCore.xcframework"),
        .target(name: "AIUXCore", dependencies: ["AIUXCoreFFI"]),
        .target(name: "AIUXSwiftUI"),
    ]
)
SWIFT
# Validate distribution from outside the source package directories.
(cd "$out" && swift build)
# Compile/link/run an external consumer of the distribution, not a workspace
# package using the development manifest or unsafe -L linker settings.
package_path="$(cd "$out" && pwd)"
consumer="$(mktemp -d)"
mkdir -p "$consumer/Sources/Consumer"
cat > "$consumer/Package.swift" <<SWIFT
// swift-tools-version:5.9
import PackageDescription
let package = Package(
  name: "Consumer", platforms: [.macOS(.v13)],
  dependencies: [.package(path: "$package_path")],
  targets: [.executableTarget(name: "Consumer", dependencies: [
    .product(name: "AIUXCore", package: "swift-package"),
    .product(name: "AIUXSwiftUI", package: "swift-package"),
  ])]
)
SWIFT
cat > "$consumer/Sources/Consumer/main.swift" <<'SWIFT'
import AIUXCore
import AIUXSwiftUI
let session = try AiuxSession.create(configJson: "{}")
let snapshot = try session.snapshot()
precondition(snapshot.contains("messages"))
let restored = try AiuxSession.restore(serializedJson: session.serialize())
let restoredSnapshot = try restored.snapshot()
precondition(restoredSnapshot == snapshot)
session.reset()
print("Standalone Swift distribution consumer linked and executed real Rust session")
SWIFT
swift run --package-path "$consumer" Consumer
tar --exclude=.build --exclude=.swiftpm -czf dist/aiux-swift-package.tar.gz -C "$out" .
