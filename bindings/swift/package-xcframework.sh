#!/usr/bin/env bash
# Package AIUXCore.xcframework — the Apple distribution artifact.
#
#   bash bindings/swift/package-xcframework.sh
#
# Requires: macOS, Xcode (xcodebuild, lipo), Rust toolchain.
# Cross-compiles the Rust core for iOS device + iOS simulator + macOS (fat
# binaries via lipo), then bundles per-platform slices into
# build/xcframework/AIUXCore.xcframework ready for an SPM binaryTarget.
#
# The xcframework only carries the FFI library + C shim — the generated
# Swift API (`AiuxSession` & co.) is staged next to it at
# build/xcframework/Sources/AIUXCore/AIUXCore.swift for the consumer to
# compile into its app/framework target (see bindings/swift/README.md).
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
# CocoaPods requires every slice to share the same library filename — keep
# libaiux_uniffi.a under per-slice dirs instead of suffixing the name.
mkdir -p "$OUT/lib/iossim" "$OUT/lib/macos"
lipo -create \
    "$ROOT/target/x86_64-apple-ios/release/libaiux_uniffi.a" \
    "$ROOT/target/aarch64-apple-ios-sim/release/libaiux_uniffi.a" \
    -output "$OUT/lib/iossim/libaiux_uniffi.a"
lipo -create \
    "$ROOT/target/x86_64-apple-darwin/release/libaiux_uniffi.a" \
    "$ROOT/target/aarch64-apple-darwin/release/libaiux_uniffi.a" \
    -output "$OUT/lib/macos/libaiux_uniffi.a"

# Header for every slice comes from the same codegen run.
cargo run -q -p aiux-uniffi --features cli --bin uniffi-bindgen -- \
    generate --library "$ROOT/target/aarch64-apple-darwin/release/libaiux_uniffi.dylib" \
    --language swift --config bindings/uniffi/uniffi.toml \
    --out-dir "$OUT/gen" --no-format
cp "$OUT/gen/AIUXCoreFFI.h" "$OUT/include/AIUXCoreFFI.h"
# Consumers importing the clang module (pods, plain Xcode targets) need the
# FFI modulemap inside the xcframework headers dir.
cp "$OUT/gen/AIUXCoreFFI.modulemap" "$OUT/include/module.modulemap" 2>/dev/null || \
    cp "$HERE/Sources/AIUXCoreFFI/include/module.modulemap" "$OUT/include/module.modulemap"

xcodebuild -create-xcframework \
    -library "$ROOT/target/aarch64-apple-ios/release/libaiux_uniffi.a" -headers "$OUT/include" \
    -library "$OUT/lib/iossim/libaiux_uniffi.a" -headers "$OUT/include" \
    -library "$OUT/lib/macos/libaiux_uniffi.a" -headers "$OUT/include" \
    -output "$OUT/AIUXCore.xcframework"

# An xcframework can't carry Swift sources — stage the generated Swift API
# beside it so consumers can compile `AiuxSession` into their own target.
mkdir -p "$OUT/Sources/AIUXCore"
mv "$OUT/gen/AIUXCore.swift" "$OUT/Sources/AIUXCore/AIUXCore.swift"

rm -rf "$OUT/gen"
echo "Wrote $OUT/AIUXCore.xcframework"
echo "Swift API → $OUT/Sources/AIUXCore/AIUXCore.swift (add to the consumer target)"
