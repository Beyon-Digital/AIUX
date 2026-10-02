#!/usr/bin/env bash
# Generate UniFFI Swift bindings + stage the Rust static archive.
#
#   bash bindings/swift/generate.sh
#
# Produces (all gitignored — regenerated, never committed):
#   Sources/AIUXCore/AIUXCore.swift            generated Swift API
#   Sources/AIUXCoreFFI/include/AIUXCoreFFI.h  generated C shim header
#   Sources/AIUXCoreFFI/include/module.modulemap
#   Sources/AIUXCoreFFI/lib/libaiux_uniffi.a   host-arch static archive
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

cargo build -p aiux-uniffi --release

# uniffi-bindgen reads contract metadata from the cdylib (per-platform name).
CDYLIB="$ROOT/target/release/libaiux_uniffi.dylib"
[ -f "$CDYLIB" ] || CDYLIB="$ROOT/target/release/libaiux_uniffi.so"
[ -f "$CDYLIB" ] || { echo "error: aiux-uniffi cdylib not found under target/release" >&2; exit 1; }

TMP="$HERE/Sources/.uniffi-gen"
rm -rf "$TMP"
mkdir -p "$TMP" "$HERE/Sources/AIUXCore" "$HERE/Sources/AIUXCoreFFI/include" "$HERE/Sources/AIUXCoreFFI/lib"

cargo run -q -p aiux-uniffi --features cli --bin uniffi-bindgen -- \
    generate --library "$CDYLIB" --language swift \
    --config bindings/uniffi/uniffi.toml \
    --out-dir "$TMP" --no-format

mv "$TMP/AIUXCore.swift" "$HERE/Sources/AIUXCore/AIUXCore.swift"
mv "$TMP/AIUXCoreFFI.h" "$HERE/Sources/AIUXCoreFFI/include/AIUXCoreFFI.h"
mv "$TMP/AIUXCoreFFI.modulemap" "$HERE/Sources/AIUXCoreFFI/include/module.modulemap"
cp "$ROOT/target/release/libaiux_uniffi.a" "$HERE/Sources/AIUXCoreFFI/lib/libaiux_uniffi.a"
rm -rf "$TMP"

echo "Swift bindings → bindings/swift/Sources/AIUXCore"
echo "FFI header + module map → bindings/swift/Sources/AIUXCoreFFI/include"
echo "Static archive → bindings/swift/Sources/AIUXCoreFFI/lib/libaiux_uniffi.a"
