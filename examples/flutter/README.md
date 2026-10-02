# examples/flutter — AIUX demo app

Flutter app playing the scripted mocked-agent interaction (port of the iOS
`AIUXExample`) over a real `aiux-capi` session: prompt → streaming → tool
status → approval gate → markdown/artifact/surface result, plus an agent-log
sheet and a conformance fixture gallery (`AIFixturePlayer`).

## Prerequisites

- Flutter stable SDK on PATH (`flutter doctor` green).
- The native core library, once per checkout:

  ```sh
  bash ../../bindings/dart/generate.sh   # cargo build -p aiux-capi
  ```

  `AiuxCapi.load()` auto-discovers `target/{debug,release}/libaiux_capi.*`
  from the nearest `Cargo.toml` ancestor, or set `AIUX_CAPI_PATH`.

- `flutter pub get`

## Run

`dart:ffi` rules out web — only native targets work. The `linux/` scaffold is
committed so this runs out of the box:

```sh
flutter run -d linux
```

For other platforms run `flutter create --platforms android,ios,macos .` once
to add their folders (untested — the capi crate then also needs a build for
that target's ABI).

## Test

```sh
flutter test   # controller + e2e scripted-scenario tests (fake clock)
```

Notes: the composer is multiline (Enter = newline; send via the arrow button).
Dark mode follows the platform brightness sampled at startup.
