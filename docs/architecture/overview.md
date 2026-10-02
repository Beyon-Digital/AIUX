# Architecture Overview

AIUX is a framework-independent AI interaction platform: one canonical
behavior engine in Rust, thin language bindings, and first-class native
renderers (SwiftUI, Jetpack Compose, React/web, Flutter, Expo/RN bridge).
This document is the map; `docs/PLAN.md` is the contract (§1 non-negotiables,
ADRs 0001–0007).

## Layered structure

```
producer (your agent/backend)          host application
        │ wire events                       │
        ▼                                   ▼
   transports/* ── AiuxEvent[] ──▶   AiuxSession (JSON facade)
   adapters/*   ◀── AIUXAction ──        │
        │                                │ serialize()/snapshot()
        ▼                                ▼
                              core/rust (the ONE state engine)
                              protocol · session · persistence · surfaces
                                             │
                        UniFFI · wasm-bindgen · C-ABI · dart:ffi
                                             │
          ┌──────────────┬──────────┬────────┴───┬──────────────┐
          ▼              ▼          ▼            ▼              ▼
     SwiftUI        Compose    web (React)   Flutter    Expo bridge
     (iOS/macOS)   (Android)   (wasm core)  (dart:ffi) (JS → native views)
```

## The frozen contract — `AiuxSession`

Every binding surface, every renderer, and every conformance run speaks to
exactly one facade (`core/rust/session`):

```text
create(configJson)        -> session
restore(serializedJson)   -> session            # resume persisted state
dispatch(eventJson)       -> DispatchReport     # {applied, duplicatesIgnored, buffered}
dispatchBatch(eventsJson) -> DispatchReport
snapshot()                -> flat render projection JSON
serialize()               -> persistence envelope JSON
reset()
```

**Strings of JSON cross every FFI boundary.** No generated structs, no
fine-grained calls — one coarse boundary keeps UniFFI/wasm/dart:ffi cheap and
keeps behavior implementations in exactly one place (ADR 0001, 0005).

## What the Rust core owns

- **Protocol** (`core/rust/protocol`): event envelope, 20 event types,
  entity schemas (message/part/tool/approval/artifact/surface/context/run),
  `ProtocolError` taxonomy, `protocolVersion` checks.
- **Session** (`core/rust/session`): the reducer. Ordered delivery
  (sequence buffer, max 1024), idempotent replay (`seen_event_ids`),
  entity lifecycle, streaming assembly (`text.delta` → parts), run state.
- **Persistence** (`core/rust/persistence`): `serialize()`/`restore()`
  envelope — `{protocolVersion, sessionId, state, nextExpectedSequence,
  seenEventIds, bufferedEvents}`.
- **Surfaces** (`core/rust/surfaces`): the §6 Surface DSL — validate
  (closed primitive set, ≤4096 nodes, root must be `surface`), apply updates
  by revision, sanitize unknown fields out before render.

What the core does **not** own: networking, storage backends, clocks
(timestamps are host-supplied on every event), navigation, or action
execution.

## Renderers are first-class, not ports

Each renderer consumes the same `snapshot()` projection and the same
conformance fixtures, then renders with that platform's idioms — a Compose
button looks Android-native, a SwiftUI button Apple-native; semantic
equivalence, not pixel identity (§17). No message UI is rebuilt in JS/RN:
the Expo bridge mounts the real SwiftUI/Compose renderers behind a native
view (§1, ADR 0002).

## Actions flow one way

Surface buttons, approvals, composer send — everything interactive emits
`AIUXAction { id, payload }` upward. Renderers never execute; the host maps
each action through its own policy (§23). Approvals render all five states
(requested/approved/rejected/expired/executed) and duplicate execution is
impossible by construction — replayed events are ignored by `seen_event_ids`.

## Conformance

`conformance/fixtures/*.json` (27 fixtures) are replayed by the Rust runner
**and** by each renderer's test harness; `expected/*.json` is the canonical
`serialize()` output. State conformance is exact, behavior conformance
equivalent, visual conformance semantic (§17).

## Where things live

| Path | Contents |
|------|----------|
| `protocol/` | JSON Schemas (draft-07) generated from the Rust types — the wire contract |
| `core/rust/` | protocol, session, persistence, surfaces, uniffi, wasm, capi crates |
| `bindings/` | swift (UniFFI), kotlin (UniFFI+NDK), wasm (JS/TS wrapper), dart (C-ABI) |
| `renderers/` | swiftui, compose, web (React), flutter |
| `bridges/` | expo (SDK 57 module + native views), react-native (plan §11, future) |
| `transports/` | javascript event factory + batching helpers |
| `adapters/` | ai-sdk, sse, websocket, graphql wire-format adapters |
| `conformance/` | fixtures + expected outputs + runners |
| `examples/` | one fake-assistant demo app per platform |
| `benches/` | criterion benchmarks + checked-in baseline (§22) |
| `tools/` | release-notes generator, conformance tooling |
