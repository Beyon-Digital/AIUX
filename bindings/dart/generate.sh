#!/usr/bin/env bash
# Build the aiux-capi shared library used by the Dart FFI wrapper.
#
#   bash bindings/dart/generate.sh
#
# Produces:
#   target/release/libaiux_capi.<ext>   used by apps and release tests
#   target/debug/libaiux_capi.<ext>     used by `dart test` / `flutter test`
#
# The Dart loader resolves the repo root by walking ancestors of the cwd
# for a Cargo.toml, then target/{release,debug}; AIUX_CAPI_PATH overrides.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

cargo build -p aiux-capi
cargo build -p aiux-capi --release

case "$(uname -s)" in
  Darwin) ext=dylib ;;
  MINGW*|MSYS*|CYGWIN*) ext=dll ;;
  *) ext=so ;;
esac
echo "aiux-capi → target/{debug,release}/libaiux_capi.$ext"
