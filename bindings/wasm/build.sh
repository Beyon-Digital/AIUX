#!/usr/bin/env bash
# Build the aiux-wasm artifact into bindings/wasm/pkg/.
#
# Requires: `rustup target add wasm32-unknown-unknown` and
# `cargo install wasm-bindgen-cli` (the CLI version must match the
# wasm-bindgen crate version in Cargo.lock — wasm-bindgen refuses mismatches).
#
# The release profile is tuned here (not in Cargo.toml) because cargo only
# honours [profile] tables in the workspace root, which is shared with the
# native crates -- passing --config keeps wasm size tuning scoped to this build.
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ../..)"

cargo build -p aiux-wasm --release --target wasm32-unknown-unknown \
  --config 'profile.release.opt-level="z"' \
  --config 'profile.release.lto=true' \
  --config 'profile.release.codegen-units=1'

wasm-bindgen \
  --target web \
  --out-dir pkg \
  --out-name aiux_wasm \
  "$ROOT/target/wasm32-unknown-unknown/release/aiux_wasm.wasm"

echo "pkg/ written: $(ls -1 pkg | tr '\n' ' ')"
