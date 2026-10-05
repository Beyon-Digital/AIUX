# Connecting a model

Your agent/model never talks to renderers — it produces **events**, and the
host dispatches them. The pipeline:

```
model stream → your controller → AiuxEvent[] → dispatchBatch → snapshot → UI
```

Two integration shapes:

1. **Direct minting** — build envelopes yourself (or via
   `createEventFactory`) per model chunk. Simplest; what the Expo example
   does.
2. **Wire adapters** — feed a provider stream (SSE/WebSocket/AI SDK) through
   `createWireNormalizer`/adapter so unknown wire shapes become envelopes.
   Best for proxying an existing endpoint.

## The run shape every prompt follows

```
session.created          (once per session)
run.started              {run, context}
message.created          {message}      ← your echo of the user's prompt
message.created          {message}      ← assistant, status "streaming"
part.added               {messageId, part: text}
text.delta               ×N             ← the token stream
  (optional) tool.started → tool.progress → tool.completed|failed
  (optional) approval.requested → approval.resolved
  (optional) artifact.created|updated / surface.created|updated
message.updated          {status: "completed"}
run.completed|failed|cancelled
```

The worked reference: [`examples/expo/src/DemoController.ts`](../../examples/expo/src/DemoController.ts)
— `scriptedPrompt` (mock), `livePrompt` (real OpenRouter), cancel/retry.

## Live OpenRouter in ~50 lines (excerpted from the example)

```ts
// examples/expo/src/openrouter.ts streams SSE over XMLHttpRequest —
// React Native's fetch can't read a streaming body on Android.
streamChatCompletion(key, model, history, tools, {
  onDelta: (d)  => send(agent.textDelta(messageId, "p1", d)),
  onToolCalls:  (calls) => liveToolTurn(run, messageId, calls), // → approval gate
  onDone: ()    => { send(agent.messageComplete(messageId));
                     send(agent.runCompleted(runId)); },
  onError: (c,m)=> { send(agent.errorPart(messageId, "p2", c, m, /*retryable*/true));
                     send(agent.messageComplete(messageId));
                     send(agent.runFailed(runId, c, m)); },
});
```

Patterns worth copying:

- **Supersede on new prompt** — abort the in-flight handle and emit terminal
  events (`toolFailed(CANCELLED)`, `approvalResolved(rejected)`,
  `messageComplete`, `runCancelled`) so nothing stays `requested`.
- **Identity-guarded `onDone`** — a superseded stream's callbacks must not
  complete the *newer* run; compare the live handle before finishing.
- **Retryable error part** — `part.added {type:"error", retryable:true}`
  renders the retry affordance; `aiux.error.retry` re-runs `liveRetry`.
- **Tool calls → approvals** — model `tool_call` ⇒ `tool.started` +
  `approval.requested`; the Approve/Reject action resolves it, then you
  execute the tool, emit `tool.completed`, and feed the result back as a
  follow-up turn.

## Wire adapters — `@beyond-digital/aiux-adapter-*`

When your backend already streams a wire format:

```ts
const sse = createSseAdapter({
  url: "https://api.example.com/stream", sessionId: "s1",
  target: {runId, messageId, partId},
});
await streamToBatches(sse, (json) => session.dispatchBatch(json));
```

- **SSE** (`adapter-sse`): fetch-based, `Last-Event-ID` resume, server
  `retry:` honored, infinite reconnect by default.
- **WebSocket** (`adapter-websocket`): same normalizer + reconnect policy;
  `send()` for bidirectional channels.
- **AI SDK** (`adapter-ai-sdk`): maps `UIMessageChunk`s (`text-delta`,
  `tool-input-*`, `finish`, `error`) — no `ai` dependency.
- All adapters stop reconnecting after a terminal event
  (`run.completed/failed/cancelled`) and report unmapped items via
  `onIssue({kind, reason, raw})`.

For custom wires, write your own `WireNormalizer` — a function
`(item) => AiuxEvent[]` + `finish()` — or mint directly with
`createEventFactory` inside your endpoint handler.

## Event hygiene

- **Sequence**: events must be 0-based contiguous *per session*. Use one
  `createEventFactory` per producer so ids/sequences stay coherent; a second
  producer resumes with `observeSequence`.
- **Batch at ≥50 Hz**: don't FFI per token — `EventBuffer` (16–50 ms) or
  `streamToBatches` (25 ms/100 events) or the Expo `AIUXTransport` queue.
- **Errors**: emit `part.added` error + `run.failed` — never throw into the
  renderer. Permanent vs transient transport failures:
  [dispatch semantics](dispatch-semantics.md).
- **Cancel**: honor `aiux.composer.cancel` by emitting `run.cancelled` —
  the UI keys the send/cancel circle off run state.
- **Attachments**: attachments live in `context`/message metadata — the
  composer `attach` action is yours to fulfill (picker → `run.started`
  context on next send).
