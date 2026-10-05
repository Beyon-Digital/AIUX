# Session contract (all platforms)

`AiuxSession` is the frozen public facade implemented by the Rust core
(`core/rust/session`) and exposed identically through every binding — UniFFI
(Swift/Kotlin), WASM (JavaScript) and the C ABI (Dart/Flutter). ADR 0001 and
ADR 0005 freeze these signatures; they change only with an ADR.

Every boundary is **JSON strings end-to-end**: no internal type ever crosses
FFI. Bindings differ only in call syntax — semantics are identical.

## Entry points

| Method | Input | Returns | Purpose |
| --- | --- | --- | --- |
| `create` | config JSON | session handle | New session. Config carries `sessionId` and an optional `protocolVersion` (checked against the supported range). Unknown fields are tolerated. |
| `restore` | `serialize()` output JSON | session handle | Resume a persisted session, including its sequence ledger and reorder buffer. |
| `dispatch` | one event envelope JSON | `DispatchReport` JSON | Reduce one event. |
| `dispatchBatch` | JSON array of event envelopes | `DispatchReport` JSON | Reduce an ordered batch — the recommended transport boundary (never dispatch per token). |
| `snapshot` | — | render snapshot JSON | Flat render projection for the current state. |
| `serialize` | — | persistence JSON | Full resumable state (superset of `snapshot`). |
| `reset` | — | — | Clear all session state. |

## Config JSON (`create`)

```json
{ "protocolVersion": "0.1", "sessionId": "s1" }
```

- `sessionId` — optional; binds the session id. If omitted, the first
  **applied** event binds the id on the envelope (`buffered` or rejected
  events do not pin it).
- `protocolVersion` — optional; checked with
  `check_protocol_version` when present.

## Event envelope (input)

```json
{
  "eventId": "evt-0-abc",
  "sessionId": "s1",
  "sequence": 0,
  "timestamp": "2026-01-01T00:00:00Z",
  "type": "message.created",
  "payload": { "protocolVersion": "0.1", "...": "…" }
}
```

| Field | Rule |
| --- | --- |
| `eventId` | Globally unique. A seen id is ignored (applied or buffered), so replays are safe. Dedup runs **before** the sequence check. |
| `sessionId` | Must equal the bound session id once bound. For `session.created`, the payload `session.id` must equal this too. |
| `sequence` | 0-based, contiguous per session. A gap buffers the event (bounded reorder buffer — `MAX_REORDER_BUFFER = 1024`); overflow is `SequenceGap`. |
| `type` | One of the 21 wire event types (see [event lifecycle](../protocol/event-lifecycle.md)). Unknown types still deserialize. |
| `payload` | Type-specific; must carry `protocolVersion` (`"0.1"` for v1). |
| `timestamp` | ISO-8601 string; informational. |

## `DispatchReport` JSON (output)

```json
{ "applied": 5, "duplicatesIgnored": 1, "buffered": 0 }
```

- `applied` — events reduced into state.
- `duplicatesIgnored` — events dropped by `eventId` dedup.
- `buffered` — events parked awaiting earlier sequences.

## `snapshot()` JSON — render projection

A **flat** projection — the only object renderers consume:

```json
{
  "protocolVersion": "0.1",
  "sessionId": "s1",
  "session": { "id": "s1", "title": "Demo", "createdAt": "…", "context": [] },
  "messages": [], "tools": [], "approvals": [], "artifacts": [],
  "surfaces": [], "context": [], "runs": []
}
```

It deliberately omits sequence bookkeeping — **do not** persist it for
resume. Use [`serialize()`](#serialize-json--persistence-envelope).

## `serialize()` JSON — persistence envelope

```json
{
  "version": 1,
  "nextExpectedSequence": 6,
  "seenEventIds": ["e0", "e1", "…"],
  "state": { "session": {…}, "messages": [...], "activeRunId": "r1", "…": "…" },
  "bufferedEvents": []
}
```

Contains everything `restore()` needs to continue an ordered stream:
`nextExpectedSequence`, the idempotency ledger (`seenEventIds`), the reduced
state, and any parked reorder-buffer events. Resume a producer at
`nextExpectedSequence` — a JS-side remount that restarts at sequence 0 will
be rejected (`InvalidEvent` on `session.created` replay is deduped only if it
also replays the same `eventId`).

## `ProtocolError`

Failures are structured, with stable variants:

| Variant | Raised when |
| --- | --- |
| `InvalidEvent` | Malformed envelope/payload, wrong `sessionId`, `session.created` payload id ≠ envelope `sessionId`, unknown semantics. |
| `SequenceGap` | An event arrives with a sequence past the reorder buffer bound, or duplicate sequence with a different `eventId`. |
| `UnsupportedVersion` | `protocolVersion` outside the supported range. |
| `CorruptState` | `restore()` input fails validation (e.g. two buffered events at one sequence). |

The error surface (message string) is JSON/stringly-typed per binding; check
`invalid event:` / `sequence gap:` prefixes when classifying programmatically —
this is what the Expo transport does for permanent-vs-transient batch policy
(see [Expo transport](expo.md#createaiuxtransport)).

## Per-binding call map

| Platform | Call shape |
| --- | --- |
| Rust | `AiuxSession::create(&str)` → `Result<AiuxSession, ProtocolError>` |
| Swift (UniFFI) | `try AiuxSession.create(configJson:)` |
| Kotlin (UniFFI) | `AiuxSession.create(configJson)` (throws `AiuxException`) |
| JS (WASM) | `AiuxSession.create(core, config, options?)` — see [js-core](js-core.md) |
| Dart (C ABI) | `AiuxCapi(libraryPath:).createSession(json)` — via `aiux_ffi` |

The native stores that wrap these calls (observable snapshots, coroutines,
`ChangeNotifier`) are documented per renderer: [web](web.md),
[expo](expo.md), [swiftui](swiftui.md), [compose](compose.md),
[flutter](flutter.md).
