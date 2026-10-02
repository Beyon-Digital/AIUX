# Event Lifecycle

How an event travels from your producer to pixels — and every failure mode
on the way. Terminology per `docs/protocol/specification.md`; behaviors per
`core/rust/session`.

## The pipeline

```
producer ──▶ transport/batcher ──▶ dispatch()/dispatchBatch()
                                      │ envelope parse
                                      │ protocolVersion check
                                      │ sessionId check
                                      │ eventId dedup (seen_event_ids)
                                      │ sequence ordering (reorder buffer ≤1024)
                                      │ payload schema validation
                                      │ reducer mutation
                                      ▼
                                DispatchReport {applied, duplicatesIgnored, buffered}
                                      │
                                snapshot() ──▶ renderer diff/paint
```

## Stages

1. **Envelope parse** — malformed JSON or missing required fields
   (`eventId`, `sessionId`, `sequence`, `timestamp`, `type`, `payload`)
   → `invalidEvent`. Nothing is applied.
2. **Version gate** — `protocolVersion` must be supported by this build
   (`0.1`); otherwise `unsupported`. Missing field is treated as the
   envelope's default (`0.1`) per schema.
3. **Session gate** — events for a different `sessionId` → `invalidEvent`.
4. **Dedup** — `eventId` already in `seen_event_ids` → counted in
   `duplicatesIgnored`, state untouched. This makes transport retries and
   at-least-once delivery free.
5. **Ordering** — `sequence < nextExpected` but not a known id is a
   contradictory replay → `invalidEvent`. `sequence > nextExpected` is
   parked in the reorder buffer (capacity 1024) and reported as `buffered`;
   it applies automatically when the gap fills. Gap beyond capacity →
   `sequenceGap {expected, received}` — the session stays consistent; the
   host must resync (re-replay from a durable log, or `serialize()` →
   reconcile → `restore()`).
6. **Payload validation** — per-type schema/semantic checks (surface trees
   get the full §6 validator: closed node set, ≤4096 nodes, `surface` root,
   revision monotonicity) → `invalidEvent`.
7. **Apply** — entity mutation in deterministic order; `applied` counts
   real state changes only.

`dispatchBatch` runs the same pipeline per element — it is the preferred
ingestion path (one FFI call per *batch*, §22; the JS `EventBuffer` and the
Expo `createAIUXTransport` coalesce into it automatically).

## Entity lifecycle cheat sheet

- **Message**: `message.created` → `part.added`/`part.updated`/`text.delta`
  → `message.updated` (status `complete`/`error`/`cancelled`). A `text.delta`
  for a missing/terminal part → `invalidEvent`.
- **Tool call**: `tool.started` → `tool.progress`* → `tool.completed` |
  `tool.failed`. Post-terminal events for the same `toolCallId` →
  `invalidEvent` (replays of the *same* event id are still ignored).
- **Approval**: `approval.requested` → `approval.resolved` (one terminal
  resolution: `approved`/`rejected`/`expired`/`executed`). A second
  resolution is rejected — the five-state model makes duplicate execution
  unrepresentable (§23).
- **Artifact**: `artifact.created` (rev 1) → `artifact.updated` (monotonic
  `revision`; a lower/equal revision → `invalidEvent`).
- **Surface**: `surface.created` → `surface.updated` (same rule — revision
  must increase; the replacement tree re-validates).
- **Run**: `run.started` → `run.completed` | `run.failed` | `run.cancelled`.
  `activeRunId` in the snapshot tracks the latest open run.

## Persistence across the lifecycle

`serialize()` captures *process* state too: `nextExpectedSequence`,
`seenEventIds`, and still-`bufferedEvents` — so a restore mid-stream resumes
ordering and dedup exactly (verified by the large-conversation suite:
byte-identical serialize→restore at 1,000 messages).

## Failure modes summary

| Condition | `ProtocolError` kind | Session state |
|-----------|----------------------|---------------|
| Bad JSON / missing field / wrong session / conflicting replay | `invalidEvent` | unchanged |
| Sequence hole larger than reorder buffer | `sequenceGap` | unchanged (earlier events still applied) |
| Unknown event type / unsupported `protocolVersion` / unknown required semantics | `unsupported` | unchanged |
| `restore()` given malformed/stale envelope | `corruptState` | no session |
