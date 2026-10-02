# Large conversations — stress profile & renderer notes

§22 requires the core to stay correct and bounded at real conversation
sizes. `core/rust/tests/tests/large_conversation.rs` + `benches/` are the
automated side; this file records what each renderer does with the load and
what a host should expect.

## What the core guarantees (tested)

`core/rust/tests/tests/large_conversation.rs` (all in CI):

- **1,000-message session stays consistent** — 500 turns ×
  (created + 2 messages + part + delta); snapshot/serialize shapes hold.
- **`serialize()` → `restore()` is byte-identical** at 1,000 messages —
  resume is lossless, including `seenEventIds` and buffered events.
- **Serialized state grows linearly** with turns (no quadratic bookkeeping).
- **Replays stay idempotent across long history** — re-dispatching the full
  stream reports `duplicatesIgnored`, zero `applied`.
- **Reversed-chunk delivery converges** — 64-event out-of-order chunks
  buffered then applied in order yield identical state.
- **5,000 streaming deltas assemble in order** through `dispatchBatch`.
- **Long history + full lifecycle** still ends in the same state as a small
  stream.

Measured numbers live in `benches/BASELINE.md` (criterion + a
`/proc`-backed memory-growth table).

## Renderer stress notes

The stress surface is the **stream**, not the core: 1k messages → a DOM /
view tree problem per platform.

| Renderer | Mechanism & guidance |
|----------|----------------------|
| Web | Messages render in one scroll container; React keys are stable message ids so deltas don't remount history. At ~1k messages the DOM is heavy — hosts should window/paginate: feed `snapshot()` the tail (drop older `messages` before constructing the session stub or virtualize with your list library). AIUX core intentionally keeps full history — pagination is a *host render* choice, not a state limit (§22 "paginated history" is preferred when needed). |
| SwiftUI | `List`/`LazyVStack` in `AIConversation` is lazy by platform default — 1k rows is within normal range; test on-device for DoD. Keep `id` stable (message id) — already the case. |
| Compose | `LazyColumn` with `key = message.id` — lazy by default. Avoid `snapshot.messages` being recomposed wholesale: the store publishes an immutable snapshot; Compose skips unchanged items via stable keys. |
| Flutter | `ListView.builder` — lazy. The store notifies per snapshot; item widgets keyed by message id. |
| Expo | Same natives as above; `onSnapshot` is throttled (~150 ms) so a burst of deltas doesn't cross the bridge per-delta. |

## What to watch (regression smells)

- **Bridge-per-delta**: if a platform moves to per-event JS callbacks instead
  of batched `dispatchBatch`, streaming throughput collapses (§22 rule:
  never one FFI call per character).
- **Whole-tree rerender**: a renderer that rebuilds the message list from
  `snapshot()` without stable keys will jank long before 1k messages.
- **Unbounded growth**: core keeps full history by design (restore
  correctness); memory after long conversations is tracked in
  `benches/src/bin/memory.rs` — hosts wanting a cap must truncate history
  *upstream* (or accept the linear growth), never by mutating the snapshot.
