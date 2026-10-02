#!/usr/bin/env bash
# Generate UniFFI Kotlin bindings + native libraries.
#
#   bash bindings/kotlin/generate.sh
#
# Produces (all under build/generated — regenerated, never committed):
#   build/generated/uniffi/aiux/aiux.kt   generated Kotlin API (package aiux)
#   build/generated/jniLibs/<abi>/*.so    Android native libs, when an NDK +
#                                         cargo-ndk are available (CI/release)
#   target/debug/libaiux_uniffi.{so,dylib} host lib used by JVM unit tests
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

# Debug host .so: JNA loads this in desktop JVM unit tests (jna.library.path).
cargo build -p aiux-uniffi
# Release: feed bindgen metadata + AAR packaging.
cargo build -p aiux-uniffi --release

OUT="$HERE/build/generated/uniffi"
rm -rf "$OUT"
mkdir -p "$OUT"

# Host lib extension differs per platform (.dylib on macOS, .so elsewhere).
case "$(uname -s)" in
    Darwin) LIB_EXT="dylib" ;;
    *) LIB_EXT="so" ;;
esac

cargo run -q -p aiux-uniffi --features cli --bin uniffi-bindgen -- \
    generate --library "$ROOT/target/release/libaiux_uniffi.$LIB_EXT" \
    --language kotlin \
    --config bindings/uniffi/uniffi.toml \
    --out-dir "$OUT" --no-format

echo "Kotlin bindings → bindings/kotlin/build/generated/uniffi/aiux/aiux.kt"

# Android ABI slices (arm64-v8a, armeabi-v7a, x86_64). Requires an NDK +
# cargo-ndk; skipped on hosts without one (e.g. the dev box — Android slices
# build on CI, which ships ANDROID_NDK_*).
NDK_HOME="${ANDROID_NDK_HOME:-${ANDROID_NDK_LATEST_HOME:-${ANDROID_NDK_ROOT:-}}}"
if [ -z "$NDK_HOME" ] && [ -d "${ANDROID_HOME:-}/ndk" ]; then
    NDK_HOME="$(ls -d "$ANDROID_HOME"/ndk/* 2>/dev/null | sort -V | tail -1 || true)"
fi

if [ -n "$NDK_HOME" ]; then
    command -v cargo-ndk >/dev/null 2>&1 || cargo install cargo-ndk --version "^4"
    rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
    export ANDROID_NDK_HOME="$NDK_HOME"
    cargo ndk \
        -t arm64-v8a -t armeabi-v7a -t x86_64 \
        -o "$HERE/build/generated/jniLibs" \
        build -p aiux-uniffi --release
    echo "Android JNI libs → bindings/kotlin/build/generated/jniLibs/{arm64-v8a,armeabi-v7a,x86_64}"
else
    echo "note: no Android NDK found — skipping Android .so slices (host .so built; tests still run)"
fi
