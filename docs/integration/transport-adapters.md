# Transport Adapter Guide

Rust never owns networking (ADR 0004): wire formats live in `adapters/*`
(your backend speaks), batching/policy lives in `transports/*` (your
language). Output on every path is the same: JSON event batches →
`dispatchBatch`.

## Pieces

| Package | What it gives you |
|---------|-------------------|
| `transports/javascript` | `createEventFactory` (ids/sequence/timestamps for host-emitted events), `EventBuffer` (coalesce → `dispatchBatch` calls: size/time thresholds, `DEFAULT_FLUSH_INTERVAL_MS`), `EventBatchSource`/`EventBatchSink` types, `isTerminalEvent` |
| `adapters/sse` | `createSseAdapter({url, reconnect, ...})` — Server-Sent Events → `AsyncIterable<AiuxEvent[]>` with reconnect policy |
| `adapters/websocket` | `createWebSocketAdapter({factory, reconnect, ...})` — pluggable `WebSocketLike` factory (browser `WebSocket`, `ws`, etc.) → event batches |
| `adapters/ai-sdk` | `createAiSdkAdapter` / `mapAiSdkPart` — Vercel AI SDK stream parts → AIUX events |
| `adapters/graphql` | GraphQL subscription → events |
| `adapters/shared` | shared event construction + `testing.ts` helpers (fake servers for e2e) |

## Canonical wiring (web)

```ts
import { createSseAdapter } from "@beyond-digital/aiux-adapter-sse";
import { EventBuffer } from "@beyond-digital/aiux-transports";
import { AiuxSession, wasmCore } from "@beyond-digital/aiux-core";

const session = await AiuxSession.create(wasmCore(), { sessionId: "s1" });
const buffer = new EventBuffer((batchJson) => session.dispatchBatch(batchJson));

for await (const events of createSseAdapter({ url })) {
  buffer.pushAll(events);   // adapter already decoded wire → AiuxEvent[]
}
```

## Rules for adapter authors

- **Adapters translate, they never decide**: map wire messages to
  `AiuxEvent` objects; ordering/idempotency/validation all live in the
  core. If your wire can't give a stable `eventId`, derive one
  deterministically (e.g. `seq`-keyed) — replay safety depends on it.
- Preserve `sequence` from the producer when the wire carries it; only use
  `EventFactory` when the *host* synthesizes events (composer send, retry).
- Reconnects must re-feed the stream (last-seen seq) — dedup makes replay
  free; gaps surface as `sequenceGap` for the host to resync.
- Batch: push arrays into `EventBuffer`/`dispatchBatch`, never one FFI call
  per delta (§22).
- Errors crossing the boundary are `ProtocolError`-shaped; adapter-level
  failures (socket closed, bad wire JSON) are your error type — don't wrap
  them as `ProtocolError`.
