#!/usr/bin/env bash
#
# Stage the iOS artifacts `AIUXExpo.podspec` consumes:
#   1. Regenerate the UniFFI Swift binding (`AIUXCore.swift` + FFI headers).
#   2. Build `AIUXCore.xcframework` (ios-arm64 + simulator + macOS slices).
#   3. Copy it into `ios/vendor/` for `s.vendored_frameworks`.
#   4. Stage the renderer + generated binding sources under ios/vendor/staged/
#      — podspec source_files must live under the pod root, so the repo-root
#      sources are copied rather than referenced via ../..
#
# Requires macOS + Xcode (run on CI or a dev Mac; `cargo` + rust ios targets).
set -euo pipefail

BRIDGE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$BRIDGE_DIR/../.." && pwd)"

bash "$REPO_ROOT/bindings/swift/generate.sh"
bash "$REPO_ROOT/bindings/swift/package-xcframework.sh"

rm -rf "$BRIDGE_DIR/ios/vendor/AIUXCore.xcframework" "$BRIDGE_DIR/ios/vendor/staged"
mkdir -p "$BRIDGE_DIR/ios/vendor/staged"
cp -R "$REPO_ROOT/bindings/swift/build/xcframework/AIUXCore.xcframework" \
  "$BRIDGE_DIR/ios/vendor/AIUXCore.xcframework"

# Renderer + generated UniFFI binding compile into the pod target.
cp -R "$REPO_ROOT/renderers/swiftui/Sources/AIUXSwiftUI" \
  "$BRIDGE_DIR/ios/vendor/staged/AIUXSwiftUI"
cp -R "$REPO_ROOT/bindings/swift/Sources/AIUXCore" \
  "$BRIDGE_DIR/ios/vendor/staged/AIUXCore"
rm -f "$BRIDGE_DIR/ios/vendor/staged/AIUXCore/Placeholder.swift"

echo "Staged AIUXCore.xcframework + renderer/binding sources → bridges/expo/ios/vendor/"
