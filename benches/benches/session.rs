//! AIUX core benchmarks (plan §22) — all driven through the frozen
//! `AiuxSession` JSON facade so numbers reflect what every binding pays.
//!
//!   cargo bench -p aiux-benches
//!
//! Baseline numbers live in `benches/BASELINE.md`; re-record on hardware of
//! the same class when checking in a deliberately changed workload.

use aiux_benches::{
    base_events, batch_json, conversation_events, stream_events, surface_tree, SID,
};
use aiux_session::AiuxSession;
use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion, Throughput};
use serde_json::json;

fn build_session(events: &[String]) -> AiuxSession {
    let mut s = AiuxSession::create("{}").unwrap();
    s.dispatch_batch(&batch_json(events)).unwrap();
    s
}

/// Cold path to the first renderable snapshot: create → dispatch the
/// lifecycle scenario → snapshot().
fn first_render(c: &mut Criterion) {
    let events = base_events();
    c.bench_function("first_render", |b| {
        b.iter(|| {
            let mut s = AiuxSession::create("{}").unwrap();
            for e in &events {
                s.dispatch(e).unwrap();
            }
            black_box(s.snapshot().unwrap())
        })
    });
}

/// `AiuxSession::restore` of a serialized long conversation — the 500-turn
/// arm is the plan's 1,000-message case.
fn restore_1000_messages(c: &mut Criterion) {
    let mut group = c.benchmark_group("restore");
    for &turns in &[250usize, 500] {
        let saved = build_session(&conversation_events(turns))
            .serialize()
            .unwrap();
        group.throughput(Throughput::Elements(2 * turns as u64));
        group.bench_with_input(
            BenchmarkId::new("messages", 2 * turns),
            &saved,
            |b, saved| b.iter(|| AiuxSession::restore(black_box(saved)).unwrap()),
        );
    }
    group.finish();
}

/// `text.delta` ingest rate — batched (what transports flush) vs one FFI
/// call per event (what plan §22 forbids across the boundary).
fn stream_throughput(c: &mut Criterion) {
    const DELTAS: usize = 2_000;
    let events = stream_events(DELTAS);
    let delta_batch = batch_json(&events[4..]);
    let mut group = c.benchmark_group("stream");
    group.throughput(Throughput::Elements(DELTAS as u64));
    group.bench_function("text_delta_batch", |b| {
        b.iter_batched(
            || build_session(&events[..4]),
            |mut s| s.dispatch_batch(black_box(&delta_batch)).unwrap(),
            criterion::BatchSize::SmallInput,
        )
    });
    group.bench_function("text_delta_each", |b| {
        b.iter_batched(
            || build_session(&events[..4]),
            |mut s| {
                for e in &events[4..] {
                    s.dispatch(black_box(e)).unwrap();
                }
            },
            criterion::BatchSize::SmallInput,
        )
    });
    group.finish();
}

/// A 100-event mixed batch (25 conversation turns) — the flush-size class
/// transports target (plan §10: 16–50 ms or size-threshold coalescing).
fn dispatch_batch_100(c: &mut Criterion) {
    let events = conversation_events(25);
    let tail = batch_json(&events[1..]); // 100 events after session.created
    let mut group = c.benchmark_group("dispatch_batch");
    group.throughput(Throughput::Elements(100));
    group.bench_function("100_events", |b| {
        b.iter_batched(
            || build_session(&events[..1]),
            |mut s| s.dispatch_batch(black_box(&tail)).unwrap(),
            criterion::BatchSize::SmallInput,
        )
    });
    group.finish();
}

/// Surface work: snapshot projection over a large tree, and the
/// validate+apply cost of a `surface.updated` with a mid-size tree.
fn surface_render(c: &mut Criterion) {
    let created = json!({
        "eventId": "ev-0", "sessionId": SID, "sequence": 0,
        "timestamp": "2026-01-01T00:00:00Z", "type": "session.created",
        "protocolVersion": "0.1",
        "payload": {"protocolVersion": "0.1", "session": {"id": SID}},
    })
    .to_string();
    let surface = json!({
        "eventId": "ev-1", "sessionId": SID, "sequence": 1,
        "timestamp": "2026-01-01T00:00:00Z", "type": "surface.created",
        "protocolVersion": "0.1",
        "payload": {"protocolVersion": "0.1", "surface": {
            "id": "sf-big", "revision": 0, "root": surface_tree(5, 5)}},
    })
    .to_string();
    let update = json!({
        "eventId": "ev-2", "sessionId": SID, "sequence": 2,
        "timestamp": "2026-01-01T00:00:00Z", "type": "surface.updated",
        "protocolVersion": "0.1",
        "payload": {"protocolVersion": "0.1", "surfaceId": "sf-big",
            "root": surface_tree(5, 4)},
    })
    .to_string();

    let seeded = || {
        let mut s = AiuxSession::create("{}").unwrap();
        s.dispatch(&created).unwrap();
        s.dispatch(&surface).unwrap(); // ~3.9k-node tree (validator cap: 4096)
        s
    };

    let mut group = c.benchmark_group("surface");
    let session = seeded();
    group.bench_function("snapshot_large_tree", |b| {
        b.iter(|| black_box(session.snapshot().unwrap()))
    });
    group.bench_function("validate_and_apply_update", |b| {
        b.iter_batched(
            seeded,
            |mut s| s.dispatch(black_box(&update)).unwrap(),
            criterion::BatchSize::SmallInput,
        )
    });
    group.finish();
}

/// Canonical serialization of the 1,000-message session — what persistence
/// and every `serialize()` FFI call pays.
fn serialize_1000_messages(c: &mut Criterion) {
    let session = build_session(&conversation_events(500));
    c.bench_function("serialize_1000_messages", |b| {
        b.iter(|| black_box(session.serialize().unwrap()))
    });
}

criterion_group!(
    benches,
    first_render,
    restore_1000_messages,
    stream_throughput,
    dispatch_batch_100,
    surface_render,
    serialize_1000_messages,
);
criterion_main!(benches);
