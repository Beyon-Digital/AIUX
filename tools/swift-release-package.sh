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
tar --exclude=.build --exclude=.swiftpm -czf dist/aiux-swift-package.tar.gz -C "$out" .
