#!/usr/bin/env bash
# Package AIUXCore.xcframework — the Apple distribution artifact.
#
#   bash bindings/swift/package-xcframework.sh
#
# Requires: macOS, Xcode (xcodebuild, lipo), Rust toolchain.
# Cross-compiles the Rust core for iOS device + iOS simulator + macOS (fat
# binaries via lipo), then bundles per-platform slices into
# build/xcframework/AIUXCore.xcframework ready for an SPM binaryTarget.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

[ "$(uname -s)" = "Darwin" ] || { echo "error: XCFramework packaging requires macOS" >&2; exit 1; }

TARGETS=(
    aarch64-apple-ios
    aarch64-apple-ios-sim
    x86_64-apple-ios
    aarch64-apple-darwin
    x86_64-apple-darwin
)
rustup target add "${TARGETS[@]}"
for t in "${TARGETS[@]}"; do
    cargo build -p aiux-uniffi --release --target "$t"
done

OUT="$HERE/build/xcframework"
rm -rf "$OUT"
mkdir -p "$OUT/lib" "$OUT/include"

# Simulator (x86_64 + arm64) and macOS (x86_64 + arm64) ship as fat archives.
lipo -create \
    "$ROOT/target/x86_64-apple-ios/release/libaiux_uniffi.a" \
    "$ROOT/target/aarch64-apple-ios-sim/release/libaiux_uniffi.a" \
    -output "$OUT/lib/libaiux_uniffi_iossim.a"
lipo -create \
    "$ROOT/target/x86_64-apple-darwin/release/libaiux_uniffi.a" \
    "$ROOT/target/aarch64-apple-darwin/release/libaiux_uniffi.a" \
    -output "$OUT/lib/libaiux_uniffi_macos.a"

# Header for every slice comes from the same codegen run.
cargo run -q -p aiux-uniffi --features cli --bin uniffi-bindgen -- \
    generate --library "$ROOT/target/aarch64-apple-darwin/release/libaiux_uniffi.dylib" \
    --language swift --config bindings/uniffi/uniffi.toml \
    --out-dir "$OUT/gen" --no-format
cp "$OUT/gen/AIUXCoreFFI.h" "$OUT/include/AIUXCoreFFI.h"

xcodebuild -create-xcframework \
    -library "$ROOT/target/aarch64-apple-ios/release/libaiux_uniffi.a" -headers "$OUT/include" \
    -library "$OUT/lib/libaiux_uniffi_iossim.a" -headers "$OUT/include" \
    -library "$OUT/lib/libaiux_uniffi_macos.a" -headers "$OUT/include" \
    -output "$OUT/AIUXCore.xcframework"

rm -rf "$OUT/gen"
echo "Wrote $OUT/AIUXCore.xcframework"
