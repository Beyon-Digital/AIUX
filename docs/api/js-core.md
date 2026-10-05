# JavaScript core — `@beyond-digital/aiux-core`

The WASM binding of the Rust core plus a typed JS wrapper. It is the runtime
under `@beyond-digital/aiux-web` and the reference for Node-side tooling.
Source: [`bindings/wasm/js`](../../bindings/wasm/js).

## Setup

```ts
import init, * as wasm from '@beyond-digital/aiux-core/wasm';
import wasmUrl from '@beyond-digital/aiux-core/wasm/aiux_wasm_bg.wasm?url';
import { AiuxSession, wasmCore } from '@beyond-digital/aiux-core';

await init({ module_or_path: wasmUrl });     // once per process/page
const core = wasmCore(wasm);
```

The package vendors the compiled `aiux-wasm` module — consumers need no Rust
toolchain. The `?url` import is the Vite pattern; on other bundlers pass the
`.wasm` file path/URL your bundler emits to `init()`.

`wasmCore(wasmModule)` adapts the raw wasm-bindgen exports to the `AiuxCore`
interface (`createSession/restoreSession/dispatch/dispatchBatch/snapshot/
serialize/reset`, opaque `SessionHandle`).

## `AiuxSession`

Mirrors the [session contract](session-contract.md) exactly, adding only JS
ergonomics: typed JSON parsing, listener observation and disposal guards.

```ts
// Create / restore
const session = AiuxSession.create(core, { protocolVersion: '0.1', sessionId: 's1' });
const resumed = AiuxSession.restore(core, serializedJson);

// Dispatch — accepts an event object, a JSON string, or (batch) an array/JSON string
session.dispatch({ eventId: 'e1', sessionId: 's1', sequence: 0, timestamp, type, payload });
session.dispatchBatch([eventA, eventB]);
const report = session.dispatchBatch(jsonArrayString);   // → DispatchReport (parsed)

// Read
const snap: SessionSnapshot = session.snapshot();        // parsed render projection
const persisted: string = session.serialize();           // JSON — persist verbatim
session.reset();

// Observe — fires after every successful mutation; returns an unsubscribe fn
const off = session.subscribe((snapshot) => render(snapshot));

// Teardown — afterwards every method throws SessionDisposedError
session.dispose();
```

| Signature | Notes |
| --- | --- |
| `AiuxSession.create(core, config, options?)` | `config`: `SessionConfig` object **or** JSON string |
| `AiuxSession.restore(core, serializedJson, options?)` | takes the exact `serialize()` output |
| `dispatch(event: AiuxEvent \| JsonString): DispatchReport` | parsed report |
| `dispatchBatch(events: readonly AiuxEvent[] \| JsonString): DispatchReport` | preferred boundary |
| `snapshot(): SessionSnapshot` | parsed; render projection |
| `serialize(): string` | JSON envelope for `restore` |
| `subscribe(listener: SnapshotListener): () => void` | `SessionSnapshot` per mutation |
| `dispose(): void` | idempotent |

`AiuxSessionOptions`:

| Option | Type | Purpose |
| --- | --- | --- |
| `onListenerError` | `(error, listener) => void` | Sink for exceptions thrown by snapshot listeners. Default: rethrow asynchronously — a renderer bug can never corrupt dispatch. |

## `EventBuffer`

Coalesces a token-rate event stream into bounded `dispatchBatch` payloads —
the unit that should cross FFI. Used by `createEventDriver` (web) and
`createAIUXTransport` (expo).

```ts
import { EventBuffer } from '@beyond-digital/aiux-core';

const buffer = new EventBuffer((batchJson: string) => {
  session.dispatchBatch(batchJson);
}, { flushIntervalMs: 32, maxEvents: 64, maxBytes: 64 * 1024 });

buffer.push(event);            // object or JSON string
buffer.flush();                // force a flush now
await buffer.close();          // flush + stop accepting
buffer.pending;                // queued event count
buffer.closed;
```

`EventBufferPolicy`:

| Field | Default | Bounds / notes |
| --- | --- | --- |
| `flushIntervalMs` | `32` (`DEFAULT_FLUSH_INTERVAL_MS`) | clamped to 16–50 ms (`MIN`/`MAX_FLUSH_INTERVAL_MS`) — the plan §10 window |
| `maxEvents` | `64` | flush immediately at this queue depth |
| `maxBytes` | `64 * 1024` | serialized UTF-8 JSON bytes |
| `onFlushError` | rethrow async | only for *timer-triggered* flushes; sync flushes propagate to the caller. Failed events stay queued and retry next window |

Flushes fire on whichever comes first: the time window since the first queued
event, `maxEvents`, or `maxBytes`. Serialization happens once at `push()`.

## `MockCore`

In-memory `AiuxCore` for tests — implements the whole facade and records
calls:

```ts
const core = new MockCore();
const session = AiuxSession.create(core, { sessionId: 't1' });
session.dispatch(event);
expect(core.calls.dispatch).toBe(1);
```

`core.calls` (`MockCoreCalls`) counts `createSession`, `restoreSession`,
`dispatch`, `dispatchBatch`, `snapshot`, `serialize`, `reset` and
`freeSession` invocations — useful for asserting batching (no per-token
`dispatch` calls).

## Errors

| Export | Meaning |
| --- | --- |
| `AiuxProtocolError` | Core rejections, carrying `kind: ProtocolErrorKind` (`"invalidEvent"`, `"sequenceGap"`, `"unsupported"`, `"corruptState"`) plus the parsed payload (`detail`, `expected`…) |
| `SessionDisposedError` | Any call after `dispose()` |
| `MalformedCoreOutputError` | The core returned non-JSON or a shape the wrapper can't parse (a core bug — not user input) |
| `parseCoreJson` / `toCoreError` / `translateCoreErrors` | Helpers the adapters/transports reuse to classify errors |

## Types

`AiuxEvent`, `DispatchReport` (`{applied, duplicatesIgnored, buffered}`),
`SessionSnapshot` (the flat render projection), `SessionConfig`,
`JsonObject`/`JsonString`, `ProtocolErrorKind`, `ProtocolErrorPayload`,
`AiuxCore`, `SessionHandle`, `SessionLifecycle` (`"active" | "disposed"`),
`SnapshotListener`, `AiuxSessionOptions`, `EventBufferPolicy`,
`ResolvedEventBufferPolicy`, `AiuxWasmModule`, `MockCoreCalls`.

Protocol entity types (`Message`, `Tool`, `Approval`, `Artifact`, `Surface`,
`Run`, `ContextEntity`, parts…) live in
`@beyond-digital/aiux-protocol-types` — generated from
[`protocol/schemas`](../../protocol/schemas).
