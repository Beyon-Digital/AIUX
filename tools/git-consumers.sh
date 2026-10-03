#!/usr/bin/env bash
# Git clients need no registry credentials. Run on GitHub CI, never build
# Rust delivery artifacts on the operator's machine.
set -euo pipefail
kind="$1"
ref="${GITHUB_SHA:?exact pushed commit required}"
repo="https://github.com/Beyon-Digital/AIUX"
consumer="$(mktemp -d)"
if [ "$kind" = rust ]; then
  cargo init --name aiux-consumer --bin "$consumer"
  (cd "$consumer" && cargo add aiux-session --git "$repo" --rev "$ref" && cargo check)
elif [ "$kind" = flutter ]; then
  cat > "$consumer/pubspec.yaml" <<YAML
name: aiux_consumer
publish_to: none
environment:
  sdk: '>=3.4.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  beyond_aiux:
    git:
      url: $repo
      ref: $ref
      path: renderers/flutter
dependency_overrides:
  aiux_ffi:
    git:
      url: $repo
      ref: $ref
      path: bindings/dart
dev_dependencies:
  flutter_test:
    sdk: flutter
YAML
  mkdir -p "$consumer/test"
  cat > "$consumer/test/consumer_test.dart" <<'DART'
import 'package:flutter_test/flutter_test.dart';
import 'package:beyond_aiux/beyond_aiux.dart';
import 'package:aiux_ffi/aiux_ffi.dart';
void main() {
  test('published Git clients use a real native session', () {
    expect(aiuxProtocolVersion, '0.1');
    final session = AiuxSession.create();
    expect(session.snapshot(), contains('messages'));
    final restored = AiuxSession.restore(session.serialize());
    restored.close(); session.reset(); session.close();
  });
}
DART
  (cd "$consumer" && flutter pub get && flutter test)
else
  echo "Unsupported consumer: $kind" >&2; exit 1
fi
