# AIUX core benchmark baseline — v0.1.0 (pre-tag)

Recorded 2026-10-02 on a Devin Linux box (x86_64, shared-CPU class),
rustc 1.97 stable, `cargo bench` release profile, criterion 0.5
(`--warm-up-time 2 --measurement-time 4 --sample-size 30`).

These numbers define "the machine class" for baseline comparison — CI
runners will differ; compare trends, not absolutes (see benches/README.md).

| Benchmark | Workload | Mean | Throughput |
|---|---|---|---|
| `first_render` | create → 20-event lifecycle → `snapshot()` | ~56 µs | — |
| `restore/messages/500` | restore serialized 500-msg session | ~544 µs | ~920K msg/s |
| `restore/messages/1000` | restore serialized 1,000-msg session (§22 target) | ~1.17 ms | ~857K msg/s |
| `stream/text_delta_batch` | `dispatch_batch` of 2,000 deltas | ~2.84 ms | ~703K events/s |
| `stream/text_delta_each` | 2,000 individual `dispatch` calls | ~2.48 ms | ~808K events/s |
| `dispatch_batch/100_events` | 100-event mixed flush | ~217 µs | ~460K events/s |
| `surface/snapshot_large_tree` | snapshot with ~3.9k-node surface (cap 4,096) | ~2.29 ms | — |
| `surface/validate_and_apply_update` | `surface.updated`, ~780-node root | ~1.13 ms | — |
| `serialize_1000_messages` | canonical `serialize()` of 1,000-msg session | ~2.14 ms | — |

## Memory probe (`cargo run -p aiux-benches --release --bin memory`)

Cumulative sessions held simultaneously (worst case: host keeps them all):

| Turns | Messages | Events | Serialized | Δ peak RSS |
|---|---|---|---|---|
| 250 | 500 | 1,001 | 138 KiB | ~3.6 MiB |
| 500 | 1,000 | 2,001 | 278 KiB | ~7.1 MiB |
| 1,250 | 2,500 | 5,001 | 699 KiB | ~16.6 MiB |

→ ~14 KiB of resident state per conversation turn (2 messages); serialized
state grows linearly (~560 B/message). No asymptotic blow-up: `OrderedMap`
is B-tree-backed and `seen_event_ids`/`reorder_buffer` stay bounded.

## Notes for reading these

- `text_delta_each` ≈ `text_delta_batch` inside the Rust boundary: batching's
  real benefit is FFI round-trip count (per-call UniFFI/wasm/JNA overhead is
  not measurable here), which is why transports must still batch.
- All dispatch numbers are for the *JSON facade* — identical to what Swift,
  Kotlin, Dart and wasm pay per event, minus their per-call boundary cost.
