# AIUX benchmarks

Criterion benches for the Rust core (plan §22), plus a memory probe for the
"long conversation" case. Everything goes through the frozen `AiuxSession`
JSON facade — the same path every binding (UniFFI, wasm, C ABI) and transport
drives, so numbers reflect the real boundary cost minus per-call FFI overhead.

## Layout

```
benches/
├── Cargo.toml          # aiux-benches (publish = false)
├── src/lib.rs          # workload builders: base/conversation/stream/surface events
├── src/bin/memory.rs   # RSS probe for long conversations
├── benches/session.rs  # criterion benches
├── BASELINE.md         # checked-in numbers + how to compare
└── README.md
```

## Run

```bash
cargo bench -p aiux-benches                       # all benches (slow first time)
cargo bench -p aiux-benches --bench session -- restore   # one group (regex filter)
cargo run -p aiux-benches --release --bin memory         # memory probe
cargo run -p aiux-benches --release --bin memory -- 500 1250 2500
```

## What each bench covers (plan §22)

| Bench | Plan item | What it measures |
|---|---|---|
| `first_render` | first render | create → full lifecycle → first `snapshot()` |
| `restore/messages/*` | 1,000-message restore | `AiuxSession::restore` on serialized state |
| `stream/*` | stream throughput | `text.delta` ingest — batched vs per-call |
| `dispatch_batch/100_events` | 100 events/batch | the transport flush-size class |
| `surface/*` | surface rendering | snapshot projection + validate/apply on big trees |
| `serialize_1000_messages` | (persistence cost) | canonical serialization of the 1k-message state |
| `memory` bin | memory after long conversations | peak RSS + serialized bytes per turn |

## Baselines & regression gates

`BASELINE.md` is checked in with numbers from a Linux x86_64 dev box. Criterion
numbers are machine-relative — when a PR claims a perf change, re-run on the
same class of machine and update the file in that PR.

Per plan §22 ("performance regression thresholds can later become CI gates"),
CI currently builds benches (`cargo bench --no-run` in the `rust` job's
`cargo build --workspace`) but does not gate on them. To gate later: run
`cargo bench -- --save-baseline main` on `main`, then `--baseline main` on the
PR and fail above a chosen % — wire this when thresholds are decided.

## Renderer-side perf

These benches measure the core only. Renderer-side large-conversation notes
(virtualization, per-platform profiling) live in
`docs/renderers/large-conversations.md`.
