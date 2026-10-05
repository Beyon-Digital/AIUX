# Dispatch semantics

How `dispatch`/`dispatchBatch` order, dedupe, and fail — the contract every
host relies on. Verified against `core/rust` and `bindings/wasm/js`.

## Sequences

- Every event carries `sequence` — **0-based, contiguous per session**.
- The core expects `nextExpectedSequence` and processes events in order.
- `session.created` conventionally carries `sequence: 0`.
- A **sequence gap** (event `sequence` > expected, or a skipped number) is
  *not* applied immediately — the event is parked in the reorder buffer.
- `MAX_REORDER_BUFFER = 1024` — once buffered events exceed this the dispatch
  fails rather than growing unboundedly.
- A `sequence` *below* `nextExpectedSequence` with an **already-seen
  `eventId`** is a duplicate — counted in `duplicatesIgnored`, never
  re-applied (idempotent redelivery is safe).

## `DispatchReport`

Every dispatch returns:

```json
{"applied": 3, "duplicatesIgnored": 1, "buffered": 0}
```

| Field | Meaning |
| --- | --- |
| `applied` | Events folded into state this call. |
| `duplicatesIgnored` | Events dropped as re-deliveries of seen `eventId`s. |
| `buffered` | Events parked waiting for an earlier sequence number. |

Non-obvious behavior: when the gap in the reorder buffer gets filled, the
parked events apply **in that same report's `applied` count** — batch replay
naturally drains the buffer.

## `dispatchBatch` > `dispatch`

- One FFI call per JSON array instead of one per event — the benchmark batch
  is 100 events; JS-side flush windows live at 16–50 ms
  (`EventBufferPolicy.flushIntervalMs` default 32, `streamToBatches` default
  25).
- Events inside one batch apply in array order.
- A malformed batch fails the whole call — no partial application across
  bindings (the JS `AIUXTransport` treats rejections prefix-matched
  `invalid event:` / `sequence gap:` as **permanent**: drop, don't retry;
  anything else is **transient**: the head batch is kept and retried
  forever, `maxBatchRetries` counts batches, not events — default 8 per
  batch before the transport closes).

## Errors — `ProtocolErrorKind`

`AiuxProtocolError` / `ProtocolError`:

| `kind` | Raised when |
| --- | --- |
| `"invalidEvent"` | Malformed envelope/payload — bad types, missing required fields, unknown event type. |
| `"sequenceGap"` | An unrecoverable ordering violation (buffer overflow, or a regression that isn't a known duplicate). |
| `"unsupported"` | `protocolVersion` the core doesn't understand. |
| `"corruptState"` | `restore()`/`serialize()` state fails validation. |

All kinds also carry `message`. The JS `AiuxProtocolError` additionally has
`code: "AIUX_PROTOCOL_ERROR"`. Web's `MalformedCoreOutputError` is separate —
it fires when a backend returns structurally-invalid JSON output (a contract
violation by the backend, not by your events).

## Ordering guarantees per binding

- **Rust/Swift/Kotlin/Dart**: calls are synchronous (suspend/blocking); the
  caller serializes.
- **`AIUXSessionStore` (Compose)**: mutex — batches apply in call order.
- **`AIUXSessionStore` (Swift)**: `@MainActor` publish; `ingest*` calls
  dispatch through the backend in order.
- **JS `AiuxSession`**: synchronous on the wasm module — dispatch ordering is
  the call ordering in JS.
- **`EventBuffer`** (JS): coalesces sync dispatches into timed batches; flush
  by size (`maxEvents`/`maxBytes`) or timer (`flushIntervalMs`).
- **`AIUXTransport`** (Expo): async queue with a single inflight batch —
  preserves push order across network latency.

## Restore & resume

`serialize()` persists `nextExpectedSequence`, `seenEventIds`, `state`, and
`bufferedEvents` — so a restored session keeps deduplicating and buffering
exactly where it left off. To continue an event stream after restore, resume
sequence numbers ≥ `nextExpectedSequence` (see
[persistence](persistence.md)).
