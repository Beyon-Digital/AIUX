# Persistence & resume

A session is fully serializable — `serialize()` returns everything needed to
reconstitute exact state, including dedup and buffering bookkeeping.

## What `serialize()` persists

```jsonc
{
  "protocolVersion": "0.1",
  "sessionId": "s1",
  "nextExpectedSequence": 42,     // ordering cursor
  "seenEventIds": ["evt-0", …],   // dedup set
  "state": { … },                 // entities, runs, surfaces
  "bufferedEvents": [ … ]         // in-flight reorder buffer
}
```

So a restored session keeps deduplicating redelivered events and draining
partial sequence gaps exactly where it left off.

## Per-binding calls

| Binding | Persist | Restore |
| --- | --- | --- |
| Rust | `session.serialize()` | `AiuxSession::restore(serialized)` |
| JS `@beyond-digital/aiux-core` | `session.serialize()` → string | `AiuxSession.restore(core, serialized)` |
| Web renderer | same (session is the JS core object) | same |
| Expo | `serializeAIUXSession(sessionId)` → string | `restoreAIUXSession(sessionId, serialized)` |
| SwiftUI | `store.serializedSession()` → JSON | `UniFFIBackend.restore(serializedJson:)` |
| Compose | `store.serialize()` → `Result<String>` | `AIUXSessionStore.restore(serializedJson)` |
| Flutter | `store.serialize()` | `store.restore(serialized)` |

## Recommended pattern

```ts
// JS core — persist on a debounce after batches:
const json = session.serialize();
localStorage.setItem(`aiux:${sessionId}`, json);

// boot:
const saved = localStorage.getItem(`aiux:${sessionId}`);
const session = saved
  ? AiuxSession.restore(core, saved)
  : AiuxSession.create(core, {protocolVersion: "0.1", sessionId});
```

Native: call `serializedSession()`/`serialize()` on a state-change signal or
app lifecycle events (background/terminate), stash in UserDefaults /
SharedPreferences / Keychain-adjacent storage.

## Resuming an event stream

- New events after restore must carry `sequence ≥ nextExpectedSequence` —
  older sequences are treated as duplicates-by-id or invalid.
- A producer that streams its own sequence (e.g. `createEventFactory` /
  `AIUXTransport`) should be restarted with `startSequence` /
  `observeSequence` aligned to `nextExpectedSequence`.
- `restore` with corrupt JSON throws the binding's error
  (`corruptState`/`AIUXStoreError`/`AiuxProtocolError`) — wrap restores in
  try/catch and fall back to `create`.

## What NOT to persist

- **Don't** persist `snapshot()` — it's a render projection, not durable
  state (no sequence/dedup info). Only `serialize()` output round-trips.
- **Don't** persist event logs and replay them on every boot as the
  persistence mechanism — replay is fine for tests but O(n) on startup;
  `serialize()` is the checkpoint.
- **Don't** persist per-field form values — those live in your host's field
  map (`aiux.surface.*.change` actions), not in the core.
