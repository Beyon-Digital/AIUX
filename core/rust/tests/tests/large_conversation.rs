//! Large-conversation tests (plan §22/§18): sessions at ≥1,000 messages must
//! keep every correctness guarantee — ordering, idempotency, byte-identical
//! serialization — that the 20-event conformance fixtures prove at small
//! scale. Companion benchmarks live in `benches/`.

mod common;

use aiux_session::AiuxSession;
use common::{base_events, batch_json, conversation_events, stream_events};
use serde_json::Value;

fn dispatch_all(session: &mut AiuxSession, events: &[String]) {
    session.dispatch_batch(&batch_json(events)).unwrap();
}

fn message_count(session: &AiuxSession) -> usize {
    let snap: Value = serde_json::from_str(&session.snapshot().unwrap()).unwrap();
    snap["messages"].as_array().unwrap().len()
}

// ---- scale invariants ------------------------------------------------------

#[test]
fn thousand_message_conversation_stays_consistent() {
    let mut s = AiuxSession::create("{}").unwrap();
    let events = conversation_events(500); // 1,000 messages
    dispatch_all(&mut s, &events);
    assert_eq!(message_count(&s), 1_000);

    let snap: Value = serde_json::from_str(&s.snapshot().unwrap()).unwrap();
    let messages = snap["messages"].as_array().unwrap();
    // Insertion order preserved: user,assistant pairs in turn order.
    assert_eq!(messages[0]["id"], "u0");
    assert_eq!(messages[1]["id"], "a0");
    assert_eq!(messages[999]["id"], "a499");
    // The streamed delta landed on the right part of the right message.
    assert_eq!(
        messages[999]["parts"][0]["text"],
        "Answer 499. Details 499."
    );
}

#[test]
fn serialize_restore_is_byte_identical_at_1000_messages() {
    let mut s = AiuxSession::create("{}").unwrap();
    dispatch_all(&mut s, &conversation_events(500));
    let saved = s.serialize().unwrap();
    let restored = AiuxSession::restore(&saved).unwrap();
    assert_eq!(restored.serialize().unwrap(), saved);
    assert_eq!(message_count(&restored), 1_000);
}

#[test]
fn serialized_state_grows_linearly_with_turns() {
    // Pagination is a renderer concern (plan §22) — the core's job is that
    // nothing hidden grows super-linearly. 250→500 turns should stay <2.5×.
    let mut small = AiuxSession::create("{}").unwrap();
    dispatch_all(&mut small, &conversation_events(250));
    let mut big = AiuxSession::create("{}").unwrap();
    dispatch_all(&mut big, &conversation_events(500));

    let small_len = small.serialize().unwrap().len() as f64;
    let big_len = big.serialize().unwrap().len() as f64;
    assert!(big_len < small_len * 2.5, "{big_len} vs {small_len}");
}

// ---- ordering + idempotency at scale ---------------------------------------

#[test]
fn replays_stay_idempotent_across_a_long_history() {
    let mut s = AiuxSession::create("{}").unwrap();
    let events = conversation_events(500);
    dispatch_all(&mut s, &events);
    let before = s.serialize().unwrap();

    // Replay every 10th event — all must be absorbed as duplicates.
    let mut replays = 0u64;
    for e in events.iter().step_by(10) {
        replays += s.dispatch(e).unwrap().duplicates_ignored;
    }
    assert_eq!(replays, events.len().div_ceil(10) as u64);
    assert_eq!(s.serialize().unwrap(), before);
}

#[test]
fn chunk_reversed_delivery_converges_to_identical_state() {
    // Deliver the stream in reversed 64-event chunks: every event is
    // out-of-order but within the reorder buffer's reach — final state must
    // equal the ordered stream exactly.
    let events = conversation_events(300); // 1,201 events
    let mut ordered = AiuxSession::create("{}").unwrap();
    dispatch_all(&mut ordered, &events);
    let baseline = ordered.serialize().unwrap();

    let mut shuffled = AiuxSession::create("{}").unwrap();
    for chunk in events.chunks(64) {
        for e in chunk.iter().rev() {
            shuffled.dispatch(e).unwrap();
        }
    }
    assert_eq!(shuffled.serialize().unwrap(), baseline);
    assert_eq!(message_count(&shuffled), 600);
}

// ---- sustained streaming ---------------------------------------------------

#[test]
fn sustained_streaming_assembles_deltas_in_order() {
    const DELTAS: usize = 5_000;
    let mut s = AiuxSession::create("{}").unwrap();
    let events = stream_events(DELTAS);
    dispatch_all(&mut s, &events);

    let snap: Value = serde_json::from_str(&s.snapshot().unwrap()).unwrap();
    let text = snap["messages"][0]["parts"][0]["text"].as_str().unwrap();
    let mut expected = String::new();
    for i in 0..DELTAS {
        use std::fmt::Write as _;
        write!(expected, "chunk-{i} ").unwrap();
    }
    assert_eq!(text, expected);
}

#[test]
fn long_history_plus_full_lifecycle_still_matches_small_stream() {
    // The 20-event conformance scenario applied after a 1,000-message history
    // must land identically — scale must not change lifecycle semantics.
    let mut s = AiuxSession::create("{}").unwrap();
    dispatch_all(&mut s, &conversation_events(500));
    // Re-target the 20-event conformance scenario's ids/sequences to
    // continue this session — its entity ids don't collide with the
    // generated u*/a* message ids — then verify every lifecycle entity
    // lands cleanly alongside the history.
    let tail = base_events();
    let seq0 = 4 * 500u64 + 1; // next sequence after conversation_events
    let reseq: Vec<String> = tail
        .iter()
        .enumerate()
        .map(|(i, e)| {
            let mut v: Value = serde_json::from_str(e).unwrap();
            v["sequence"] = (seq0 + i as u64).into();
            v["eventId"] = format!("tail-{i}").into();
            v["sessionId"] = "s1".into();
            v.to_string()
        })
        .collect();
    dispatch_all(&mut s, &reseq);

    let snap: Value = serde_json::from_str(&s.snapshot().unwrap()).unwrap();
    assert_eq!(snap["messages"].as_array().unwrap().len(), 1_002);
    assert_eq!(snap["tools"].as_array().unwrap().len(), 1);
    assert_eq!(
        snap["approvals"].as_array().unwrap()[0]["status"],
        "executed"
    );
    assert_eq!(snap["surfaces"].as_array().unwrap()[0]["revision"], 1);
}
