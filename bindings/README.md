# bindings

FFI boundaries — UniFFI (swift, kotlin), WASM (wasm), C ABI (dart). ADR 0005.

## UniFFI (pinned)

`uniffi = "=0.29.5"` in `bindings/uniffi/Cargo.toml`. UniFFI is pre-1.0
(plan §5): the version is pinned exactly — do not bump without compatibility
CI. The codegen CLI is the same pinned build, run via the crate itself:

```bash
cargo run -p aiux-uniffi --features cli --bin uniffi-bindgen -- <args>
```

FFI surface: one object, `AiuxSession` — `create(configJson)`,
`restore(serializedJson)`, `dispatch(eventJson)`, `dispatchBatch(eventsJson)`,
`snapshot()`, `serialize()`, `reset()`. JSON strings in/out only;
`ProtocolError` maps to `AiuxException`/`AiuxError` per language.

## Kotlin (`bindings/kotlin`)

- `bash bindings/kotlin/generate.sh` — builds the crate, emits
  `aiux/aiux.kt` into `build/generated/uniffi/` (generated, gitignored), and
  cross-compiles Android `.so`s into `build/generated/jniLibs/` when an NDK +
  `cargo-ndk` (`^4`) are available (CI runners have one; the Linux dev box
  skips with a notice). Host `target/debug/libaiux_uniffi.so` feeds the JVM
  unit tests via `jna.library.path`.
- Gradle module is `com.android.library` (AGP 8.13.0, Kotlin 2.0.20 —
  declared in the root `build.gradle.kts`). Generated sources land in
  `build/`; the `generateUniffiBindings` task regenerates them on demand so
  `./gradlew build` works on a clean checkout.
- AAR: `./gradlew :bindings:kotlin:assembleRelease` →
  `bindings/kotlin/build/outputs/aar/kotlin-release.aar`.
- JUnit smoke test (`AiuxSessionTest`) runs on desktop JVM:
  create → dispatchBatch(fixture) → snapshot → serialize → restore → reset.

## Swift (`bindings/swift`)

- `bash bindings/swift/generate.sh` — emits `AIUXCore.swift` + FFI
  header/modulemap under `Sources/` and stages `libaiux_uniffi.a` at
  `Sources/AIUXCoreFFI/lib/` (all gitignored). Runs on the macOS
  `swift-bindings` CI job before `swift build && swift test`.
- `Package.swift` compiles generated bindings + links the static archive
  for local/CI use (`-LSources/AIUXCoreFFI/lib` resolves relative to the
  package dir).
- Distribution path: `bash bindings/swift/package-xcframework.sh` on macOS —
  cross-compiles ios-device + ios-sim(fat) + macos(fat) slices and produces
  `build/xcframework/AIUXCore.xcframework` for an SPM `binaryTarget` in
  consumer packages:

  ```swift
  .binaryTarget(name: "AIUXCoreFFI", path: "AIUXCore.xcframework")
  ```
- Smoke test (`AiuxSessionTests`) mirrors the Kotlin one; verified on the
  macOS CI job (no Swift toolchain on the Linux dev box).

## Regenerate

```bash
bash bindings/kotlin/generate.sh   # Linux/macOS
bash bindings/swift/generate.sh    # macOS (Swift consumers)
```
