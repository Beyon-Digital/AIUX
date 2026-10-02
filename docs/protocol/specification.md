# Protocol Specification — AIUX Protocol 0.1

Normative source: `protocol/schemas/v1/**` (draft-07 JSON Schemas generated
from `core/rust/protocol`). This document explains the model; the schemas are
the contract. Version policy: `docs/integration/compatibility-policy.md`.

## Event envelope

Every event is one JSON object (`event.json`):

```json
{
  "eventId": "ev-7",
  "sessionId": "s1",
  "sequence": 7,
  "timestamp": "2026-01-01T00:00:07Z",
  "type": "message.created",
  "protocolVersion": "0.1",
  "payload": { "...": "type-specific" }
}
```

| Field | Rule |
|-------|------|
| `eventId` | Unique per event. Replays of a known id are ignored (idempotency). |
| `sessionId` | Owning session; dispatch rejects events for other sessions. |
| `sequence` | Monotonic per session, **0-based**, no gaps allowed in steady state. |
| `timestamp` | ISO-8601, **host-supplied** — the core never invents time. |
| `type` | One of the 20 types below. Unknown types fail `ProtocolError.Unsupported`. |
| `protocolVersion` | Merged in at dispatch; unsupported values fail `Unsupported`. |
| `payload` | Per-type object; `additionalProperties: true` — unknown optional fields MUST NOT break older readers (§21). |

`dispatch` returns `DispatchReport { applied, duplicatesIgnored, buffered }`
(`dispatchReport.json`).

## Event types (20)

| Type | Payload | Semantics |
|------|---------|-----------|
| `session.created` | `session.created.json` | First event (seq 0). Seeds session entity (title, context, capabilities). |
| `message.created` | `message.created.json` | New message (role user/assistant/system, parts may be empty at first). |
| `message.updated` | `message.updated.json` | Patch message fields (status, metadata). |
| `part.added` | `part.added.json` | Append a typed part to a message. |
| `part.updated` | `part.updated.json` | Replace a part's content by id. |
| `text.delta` | `text.delta.json` | Streaming append to a `text`/`markdown` part (by `partId`). |
| `tool.started` | `tool.started.json` | Tool call begins (`toolCallId`, name, input). |
| `tool.progress` | `tool.progress.json` | Progress update (0–1 or label). |
| `tool.completed` | `tool.completed.json` | Tool finished with result. |
| `tool.failed` | `tool.failed.json` | Tool finished with `AiuxError`. |
| `approval.requested` | `approval.requested.json` | Host decision needed — prompt, description, action, optional expiry. |
| `approval.resolved` | `approval.resolved.json` | Terminal state: approved/rejected/expired/executed. |
| `artifact.created` | `artifact.created.json` | Named artifact (code/report/file/…) at revision 1. |
| `artifact.updated` | `artifact.updated.json` | New revision of an existing artifact. |
| `surface.created` | `surface.created.json` | New UI surface tree (validated against the closed DSL). |
| `surface.updated` | `surface.updated.json` | Replacement tree at a higher `revision`. |
| `run.started` | `run.started.json` | Assistant turn/run begins. |
| `run.completed` | `run.completed.json` | Run finished normally. |
| `run.failed` | `run.failed.json` | Run finished with `AiuxError`. |
| `run.cancelled` | `run.cancelled.json` | Run cancelled (user or host). |

## Entities

Schemas under `protocol/schemas/v1/`:

- **Message** (`message.json`) — id, role, parts, status (`streaming`,
  `complete`, `error`, `cancelled`).
- **Part** (`part.json`) — internally tagged `{"type": <kind>}`; 13 kinds:
  `text`, `markdown`, `code`, `image`, `attachment`, `citation`, `tool`,
  `approval`, `artifact`, `status`, `progress`, `surface`, `error`.
- **Tool / Approval / Artifact / Surface / ContextEntity / Capability /
  Run** — `tool.json`, `approval.json`, `artifact.json`, `surface.json`,
  `contextEntity.json`, `capability.json`, plus shared `action.json`,
  `attachment.json`, `citation.json`, `error.json`.
- **Session** (`session.json`) — id, title, context entities, capabilities.

## Errors

- **Wire-level** (`AiuxError`, `error.json`): `{code, message, retryable?,
  detail?}` carried by `tool.failed`, `run.failed`, `error` parts.
- **Boundary-level** (`ProtocolError`, `protocolError.json`): internally
  tagged `{kind: invalidEvent | sequenceGap | unsupported | corruptState}` —
  the only error shape that ever crosses `dispatch`/`restore` (see
  `docs/protocol/event-lifecycle.md` for when each fires).

## Ordering & replay guarantees

- Sequences are per-session; the core buffers out-of-order events (max
  1024) and applies them once the gap fills — `buffered` in the report.
- A gap beyond the buffer fails `sequenceGap { expected, received }` →
  resync via `serialize()`/`restore()` or reset; never silent corruption.
- `eventId` replay is always safe (`duplicatesIgnored`), including across
  `serialize()`/`restore()` — seen ids persist in the envelope.

## Snapshot vs serialized envelope

`snapshot()` is the flat render projection (what renderers consume):
`{protocolVersion, sessionId, session?, messages[], tools[], approvals[],
artifacts[], surfaces[], context[], runs[], activeRunId?}`.

`serialize()` is the durable envelope: `{protocolVersion, sessionId,
state{...same projection...}, nextExpectedSequence, seenEventIds[],
bufferedEvents[]}` — enough to resume ordering + idempotency exactly.
