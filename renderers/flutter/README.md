# beyond_aiux — Flutter renderer for AIUX

The Flutter renderer for the AIUX platform (docs/PLAN.md §13). Semantic
parity with the SwiftUI reference (`renderers/swiftui`): protocol state is
owned by the Rust core; this package decodes, lays out, and renders it with
Material widgets — no platform views embedding SwiftUI/Compose anywhere in
the default path.

## Architecture

```
Rust core (frozen session facade)
  └─ aiux-capi (C ABI, bindings/dart/capi)
      └─ aiux_ffi (dart:ffi wrapper, bindings/dart)
          └─ AiuxFfiBackend ─ AiuxSessionBackend ─┐
AiuxSessionStore (ChangeNotifier) ── publishes ──▶ AiuxRenderModel
AIConversation (fullscreen / embedded)
  └─ AIMessage → AIPartView → 13 part kinds
     AISurface → AiuxNodeView → 26 §6 primitives
     AIApproval, AIToolStatus, AIArtifactPreview,
     AIContextBar, AIComposer
```

- **`AiuxSessionBackend`** — the JSON-string boundary matching the frozen
  facade (`dispatch`, `dispatchBatch`, `snapshot`, `serialize`, `reset`).
  `AiuxFfiBackend` conforms `aiux_ffi.AiuxSession` to it; tests and fixture
  playback can drive a store with any conforming backend.
- **`AiuxSessionStore`** — owns a backend, ingests events, publishes the
  decoded `AiuxRenderModel` (snapshot + by-id entity index) to the views.
- **`AiuxScope`** — the inherited scope carrying the entity index plus the
  host's action emitter. Views emit semantic `AiuxAction`s upward; they
  never execute (PLAN §1, §23).
- **`AiuxThemeData`** — the §7 role contract: 12 color roles (light + dark),
  typography scale, spacing/radius tokens, motion, density. Every visual
  resolves through `AiuxTheme.of(context)`.

## Usage

```dart
final backend = AiuxFfiBackend.create(configJson: '{}');
final store = AiuxSessionStore(backend: backend);

AiuxScope(
  model: store.renderModel,
  emit: (action) => myHost.handle(action),
  child: AIConversation(store: store),
);
```

Feed events with `store.ingestEvent(json)` / `store.ingestBatch(json)`;
inspect with `store.snapshot` / `store.serializedSession()`;
`store.resetSession()` clears state.

For a complete mocked-agent scenario see `examples/flutter`.

## Tests

`flutter test` covers model decode (all conformance expected files),
the widget layer over the real FFI backend, action emission, and the
degradation contract. State conformance is proven in `bindings/dart`
(`dart test` replays every `conformance/fixtures/*.json` through the C ABI
and byte-compares `serialize()` against `conformance/expected/`).

Building the native library for the FFI backend: `bindings/dart/generate.sh`
(or let the loader auto-discover `target/{debug,release}/libaiux_capi.*`
from the nearest Cargo.toml ancestor — see `aiux_ffi`'s loader docs).
