# Transports & adapters

The seam between "wherever AIUX envelopes live on the wire" and a session's
`dispatchBatch`. Three layers:

```
wire bytes → WireNormalizer → AiuxEvent[] → streamToBatches → EventBatchSink
```

- `@beyond-digital/aiux-transports` — factory, batcher, normalizer
  ([`transports/javascript`](../../transports/javascript)).
- `@beyond-digital/aiux-adapter-sse` — SSE endpoints (fetch-based).
- `@beyond-digital/aiux-adapter-websocket` — WebSocket endpoints.
- `@beyond-digital/aiux-adapter-ai-sdk` — Vercel AI SDK `UIMessageChunk`
  streams (no `ai` dependency — anything shaped like a part is accepted).

## `createEventFactory(sessionId, options?)`

Mints valid envelopes with a monotonically increasing per-factory sequence —
the canonical way to author events without hand-rolling ids/sequences.

```ts
const factory = createEventFactory("s1", {
  now: () => new Date().toISOString(),   // clock override (tests)
  eventId: (seq) => `evt-${seq}`,        // id minting override
  startSequence: 0,                      // resume mid-stream
});

factory.emit("my.type", { protocolVersion: "0.1", … })  // generic mint
factory.sessionCreated(session)
factory.runStarted(run, context?)
factory.runCancelled(runId, reason?)
factory.runCompleted(runId, result?)
factory.runFailed(runId, error)
factory.messageCreated(message)
factory.messageUpdated(messageId, {status?, role?, metadata?})
factory.partAdded(messageId, part)
factory.partUpdated(messageId, partId, part)
factory.textDelta(messageId, partId, delta)
factory.toolStarted(tool)
factory.toolProgress(toolId, progress)
factory.toolCompleted(toolId, result?)
factory.toolFailed(toolId, error)
factory.approvalRequested(approval)
factory.approvalResolved(approvalId, resolution)
factory.artifactCreated(artifact)
factory.artifactUpdated(artifactId, {title?, content?, uri?, metadata?})
factory.surfaceCreated(surface)
factory.surfaceUpdated(surfaceId, root)

factory.peekSequence()          // next sequence number
factory.observeSequence(n)      // lift sequence past externally-observed n
```

Each mint sets `protocolVersion: "0.1"` on both envelope and payload;
default event ids are `evt-<seq36>-<rand>`.

## `streamToBatches(source, sink, options?)`

Pumps an `AsyncIterable<AiuxEvent[]>` source into a sink as JSON batches.

```ts
await streamToBatches(adapter, (eventsJson) => transport.push(eventsJson), {
  maxBatchSize: 100,      // flush at this many events
  flushIntervalMs: 25,    // flush a partial batch this often; 0 = size/EOF only
  onError: (err, ctx) => …, // ctx: "sink" | "source"
  signal,                 // abort early — buffer flushes first
});
// → { batches, events }
```

- `EventBatchSink = (eventsJson: string) => Promise<void> | void` — the same
  signature `AiuxSession.dispatchBatch` / `AIUXTransport.push` satisfy.
- A sink failure rethrows (the sink owns delivery policy); a source failure
  propagates after `onError`.

## `createWireNormalizer(options)`

Default wire → `AiuxEvent[]` mapping used by the SSE/WebSocket adapters.
Accepts the documented wire shapes (envelopes, `{type, data}` frames, batch
arrays, common vendor keys like `choices[0].delta.content`); reports anything
unmapped via `onIssue` and never throws mid-stream.

```ts
const normalize = createWireNormalizer({
  factory,
  target: { runId: "r1", messageId: "m1", partId: "p1" },
  onIssue: (issue) => console.warn(issue.kind, issue.reason),
});
```

`NormalizeTarget` supplies the ids lifecycle/delta events point at when the
wire doesn't carry them. `normalize.finish()` seals cross-item state
(buffered tool calls) — transports call it at EOF, and you must too when
driving a normalizer by hand.

`AdapterIssue {kind: "malformed"|"unhandled"|"transport", reason, raw?}` —
non-fatal observations; `raw` is the offending item (never logged by
default).

## `createSseAdapter(options)`

```ts
const sse = createSseAdapter({
  url: "https://api.example.com/stream",
  init: {method: "POST", headers, body},  // RequestInit incl. POST-style SSE
  fetchFn,                                 // default globalThis.fetch
  sessionId: "s1",
  target: {runId, messageId, partId},
  factory,        // optional — resumes sequence
  normalize,      // optional — custom wire mapping
  reconnect: {maxRetries: Infinity, initialDelayMs: 500,
              maxDelayMs: 30_000, honorServerRetry: true},
  signal,
  onIssue,
});
```

- Sends `Accept: text/event-stream`; parses `data:`/`event:`/`id:`/`retry:`.
- `sse.lastEventId` / `lastEventIdHeader` — most recent `id:` field, sent as
  `Last-Event-ID` on reconnect.
- Stops reconnecting after a terminal event.

## `createWebSocketAdapter(options)`

```ts
const ws = createWebSocketAdapter({
  url: "wss://api.example.com/stream",
  protocols,                // handshake subprotocols
  webSocketFactory,         // default global WebSocket (browser/Node 22+/RN);
                            // pass `ws` on older Node
  sessionId, target, factory, normalize, signal, onIssue,
  reconnect: {maxRetries: Infinity, initialDelayMs: 500, maxDelayMs: 30_000},
});

ws.send(json);              // send on the live socket
ws.connections;             // (re)connect count — diagnostics
```

## `createAiSdkAdapter(stream, options)`

Maps Vercel AI SDK `UIMessageChunk`s (`text-delta`, `tool-input-*`,
`tool-output-*`, `finish`, `error`) to AIUX events:

```ts
const adapter = createAiSdkAdapter(stream, {
  sessionId: "s1",
  target: {runId: "r1", messageId: "m1", partId: "p1"},
  factory, onIssue,
});
```

`mapAiSdkPart(part, ctx)` is also exported for one-off mapping. Unmapped
parts (`start`, `reasoning-*`, `source-*`, `data-*`, …) are reported via
`onIssue` — they're lifecycle-free on the AIUX wire.

## Terminal events

`TERMINAL_EVENT_TYPES = {"run.completed","run.failed","run.cancelled"}` and
`isTerminalEvent(event)` — adapters stop reconnecting after emitting one;
use it in your own loops to know when a run is over.
