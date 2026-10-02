# aiux_ffi (Dart bindings)

Dart FFI wrapper over the AIUX C ABI (`aiux-capi`). Mirrors the frozen session
facade (PLAN §4): `create` / `restore` / `dispatch` / `dispatchBatch` /
`snapshot` / `serialize` / `reset` — JSON strings in and out, no internal type
crossing the boundary. This is the layer `beyond_aiux`'s session backend plugs
into (PLAN §13).

## Bridge tooling decision (PLAN §5, ADR 0005)

**Handwritten `dart:ffi` over the narrow C ABI — not `flutter_rust_bridge`.**

ADR 0005 pins the C-compatible ABI as the stable boundary "regardless of
tooling" and rules out a fake UniFFI-Dart generator. Evaluating the two real
options for this lane:

- **flutter_rust_bridge** generates Dart ↔ Rust glue from annotated Rust. It
  excels when many typed APIs cross the boundary, but here the facade is
  deliberately seven functions moving opaque JSON strings — generation would
  add a codegen toolchain, version pin, and FFI-indirect layer without buying
  anything. Its default threading/async model (poor-man's futures over a
  Rust-side executor) also fights the facade's synchronous call contract.
- **handwritten `dart:ffi`** is ~250 LOC, matches the facade one-to-one, keeps
  the ownership contract explicit (returned strings freed via
  `aiux_string_free`, errors via `aiux_take_last_error`), and keeps the C ABI
  as the sole contract — the same boundary a future C++/Qt or embedded host
  would bind.

If the ABI later grows typed/many-method surfaces, `flutter_rust_bridge` can be
re-evaluated on top of this crate — the C ABI itself does not change.

## Layout

- `capi/` — the `aiux-capi` Rust crate (`staticlib` + `cdylib` + `rlib`).
  `extern "C"` facade mirroring `AiuxSession`; thread-local last-error
  (`aiux_take_last_error`); caller-owned strings (`aiux_string_free`); panics
  isolated via `catch_unwind`. Public header: `capi/aiux_capi.h`.
- `lib/` — `package:aiux_ffi`. `AiuxSession` (create/restore, dispatch,
  snapshot/serialize, reset, close) + `AiuxCapi` (resolved exports) +
  `AiuxException`.
- `test/` — smoke tests plus the conformance replay:
  `test/conformance_test.dart` replays every `conformance/fixtures/*.json`
  through `dispatch()` and byte-compares `serialize()` to
  `conformance/expected/` — the Phase 7 state-conformance gate through the C
  ABI.
- `generate.sh` — builds `target/{debug,release}/libaiux_capi.<ext>`.

## Usage

```bash
bash bindings/dart/generate.sh        # build libaiux_capi
cd bindings/dart && dart pub get
dart test                             # FFI smoke + fixture conformance
dart analyze
```

```dart
import 'package:aiux_ffi/aiux_ffi.dart';

final session = AiuxSession.create(configJson: '{}');
session.dispatch(eventJson);              // → {applied, duplicatesIgnored, buffered}
final snapshot = session.snapshot();      // canonical render JSON
final persisted = session.serialize();    // restore with AiuxSession.restore(persisted)
session.close();
```

Library resolution (`AiuxCapi()`): `AIUX_CAPI_PATH` env or explicit
`libraryPath` → `<repo>/target/{release,debug}/libaiux_capi.<ext>` (walking
ancestors for `Cargo.toml`) → platform loader search. Errors throw
`AiuxException` carrying the native `aiux_take_last_error` detail.

Handles are not thread-safe — serialize calls per session (single-isolate
Flutter apps get this for free).
