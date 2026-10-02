#!/usr/bin/env bash
#
# Stage the iOS artifacts `AIUXExpo.podspec` consumes:
#   1. Regenerate the UniFFI Swift binding (`AIUXCore.swift` + FFI headers).
#   2. Build `AIUXCore.xcframework` (ios-arm64 + simulator + macOS slices).
#   3. Copy it into `ios/vendor/` for `s.vendored_frameworks`.
#
# Requires macOS + Xcode (run on CI or a dev Mac; `cargo` + rust ios targets).
set -euo pipefail

BRIDGE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$BRIDGE_DIR/../.." && pwd)"

bash "$REPO_ROOT/bindings/swift/generate.sh"
bash "$REPO_ROOT/bindings/swift/package-xcframework.sh"

mkdir -p "$BRIDGE_DIR/ios/vendor"
rm -rf "$BRIDGE_DIR/ios/vendor/AIUXCore.xcframework"
cp -R "$REPO_ROOT/bindings/swift/build/xcframework/AIUXCore.xcframework" \
  "$BRIDGE_DIR/ios/vendor/AIUXCore.xcframework"

echo "Staged AIUXCore.xcframework → bridges/expo/ios/vendor/"
