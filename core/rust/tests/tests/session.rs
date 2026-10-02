//! Integration tests for `AiuxSession` dispatch semantics (plan §4):
//! idempotency, sequence ordering, error surfaces, persistence, batching.

mod common;

use aiux_protocol::ProtocolError;
use aiux_session::{AiuxSession, MAX_REORDER_BUFFER};
use common::{base_events, event, pv, SID};
use serde_json::json;

fn dispatch_all(session: &mut AiuxSession, events: &[String]) {
    for e in events {
        session.dispatch(e).unwrap();
    }
}

fn fresh() -> AiuxSession {
    AiuxSession::create("{}").unwrap()
}

// ---- idempotency -----------------------------------------------------------

#[test]
fn replayed_event_id_is_ignored() {
    let mut s = fresh();
    let events = base_events();
    s.dispatch(&events[0]).unwrap();
    let before = s.serialize().unwrap();

    let report = s.dispatch(&events[0]).unwrap();
    assert_eq!(report.applied, 0);
    assert_eq!(report.duplicates_ignored, 1);
    assert_eq!(s.serialize().unwrap(), before);
}

#[test]
fn replayed_event_id_late_in_stream_is_ignored() {
    let mut s = fresh();
    let events = base_events();
    dispatch_all(&mut s, &events);
    let before = s.serialize().unwrap();

    // Replayed mid-stream event (already applied, id known).
    let report = s.dispatch(&events[5]).unwrap();
    assert_eq!(report.duplicates_ignored, 1);
    assert_eq!(s.serialize().unwrap(), before);
}

#[test]
fn approval_replayed_resolution_never_reexecutes() {
    let mut s = fresh();
    let events = base_events();
    // Through approval executed (seq 13).
    dispatch_all(&mut s, &events[..14]);
    let state_before = serde_json::from_str::<serde_json::Value>(&s.serialize().unwrap()).unwrap()
        ["state"]
        .clone();

    // A NEW event id attempting a conflicting resolution on the executed
    // approval is accepted (counted applied) but must not flip state.
    let conflict = event(
        14,
        "approval.resolved",
        pv(json!({
            "approvalId": "a1",
            "resolution": {"decision": "rejected"}
        })),
    );
    s.dispatch(&conflict).unwrap();
    let persisted: serde_json::Value = serde_json::from_str(&s.serialize().unwrap()).unwrap();
    assert_eq!(state_before, persisted["state"]);
    let approval = &persisted["state"]["approvals"][0];
    assert_eq!(approval["status"], "executed");
    assert_eq!(approval["resolution"]["decision"], "executed");
}

// ---- ordering --------------------------------------------------------------

#[test]
fn out_of_order_events_buffer_and_drain_in_sequence() {
    let mut ordered = fresh();
    let events = base_events();
    dispatch_all(&mut ordered, &events);
    let baseline = ordered.serialize().unwrap();

    let mut s = fresh();
    s.dispatch(&events[0]).unwrap();
    // Deliver seq 2 before seq 1.
    let report = s.dispatch(&events[2]).unwrap();
    assert_eq!(report.buffered, 1);
    let report = s.dispatch(&events[1]).unwrap();
    assert_eq!(report.applied, 2); // seq 1 applied + buffered seq 2 drained
    dispatch_all(&mut s, &events[3..]);
    assert_eq!(s.serialize().unwrap(), baseline);
}

#[test]
fn replayed_id_that_was_buffered_is_ignored() {
    let mut s = fresh();
    let events = base_events();
    s.dispatch(&events[0]).unwrap();
    s.dispatch(&events[2]).unwrap(); // buffered; id already seen
    let report = s.dispatch(&events[2]).unwrap();
    assert_eq!(report.duplicates_ignored, 1);
}

#[test]
fn sequence_below_expected_is_sequence_gap() {
    let mut s = fresh();
    let events = base_events();
    s.dispatch(&events[0]).unwrap();
    s.dispatch(&events[1]).unwrap();
    // A never-seen event with sequence 0: the slot already passed.
    let stale = json!({
        "eventId": "ev-stale",
        "sessionId": SID,
        "sequence": 0,
        "timestamp": "2026-01-01T00:00:00Z",
        "type": "run.started",
        "payload": pv(json!({"run": {"id": "r2", "status": "running"}})),
    })
    .to_string();
    let err = s.dispatch(&stale).unwrap_err();
    assert!(matches!(
        err,
        ProtocolError::SequenceGap {
            expected: 2,
            received: 0
        }
    ));
}

#[test]
fn reorder_buffer_overflow_is_sequence_gap() {
    let mut s = fresh();
    let events = base_events();
    s.dispatch(&events[0]).unwrap(); // seq 0 applied; next_expected = 1

    // Park MAX_REORDER_BUFFER events (seqs 2..=1025; seq 1 left missing).
    for seq in 2..(2 + MAX_REORDER_BUFFER as u64) {
        let filler = json!({
            "eventId": format!("ev-{seq}"),
            "sessionId": SID,
            "sequence": seq,
            "timestamp": "2026-01-01T00:00:00Z",
            "type": "text.delta",
            "payload": pv(json!({"messageId": "m1", "partId": "p1", "delta": "x"})),
        })
        .to_string();
        s.dispatch(&filler).unwrap();
    }
    // One more out-of-order event overflows the bounded buffer.
    let overflow = json!({
        "eventId": "ev-overflow",
        "sessionId": SID,
        "sequence": 9999,
        "timestamp": "2026-01-01T00:00:00Z",
        "type": "text.delta",
        "payload": pv(json!({"messageId": "m1", "partId": "p1", "delta": "x"})),
    })
    .to_string();
    assert!(matches!(
        s.dispatch(&overflow),
        Err(ProtocolError::SequenceGap {
            expected: 1,
            received: 9999
        })
    ));
}

// ---- error surfaces --------------------------------------------------------

#[test]
fn unknown_event_type_is_unsupported() {
    let mut s = fresh();
    s.dispatch(&base_events()[0]).unwrap();
    let e = json!({
        "eventId": "ev-9",
        "sessionId": SID,
        "sequence": 1,
        "timestamp": "2026-01-01T00:00:00Z",
        "type": "message.deleted",
        "payload": {"protocolVersion": "0.1"},
    })
    .to_string();
    assert!(matches!(
        s.dispatch(&e),
        Err(ProtocolError::Unsupported { .. })
    ));
}

#[test]
fn mismatched_protocol_versions_are_unsupported() {
    // Config-level.
    assert!(matches!(
        AiuxSession::create(r#"{"protocolVersion": "9.9"}"#),
        Err(ProtocolError::Unsupported { .. })
    ));

    let mut s = fresh();
    // Envelope-level.
    let e = json!({
        "eventId": "ev-0",
        "sessionId": SID,
        "sequence": 0,
        "timestamp": "2026-01-01T00:00:00Z",
        "type": "session.created",
        "protocolVersion": "9.9",
        "payload": pv(json!({"session": {"id": SID}})),
    })
    .to_string();
    assert!(matches!(
        s.dispatch(&e),
        Err(ProtocolError::Unsupported { .. })
    ));

    // Payload-level.
    let mut s = fresh();
    let e = json!({
        "eventId": "ev-0",
        "sessionId": SID,
        "sequence": 0,
        "timestamp": "2026-01-01T00:00:00Z",
        "type": "session.created",
        "payload": {"protocolVersion": "9.9", "session": {"id": SID}},
    })
    .to_string();
    assert!(matches!(
        s.dispatch(&e),
        Err(ProtocolError::Unsupported { .. })
    ));
}

#[test]
fn malformed_json_and_envelopes_are_invalid() {
    let mut s = fresh();
    assert!(matches!(
        s.dispatch("{"),
        Err(ProtocolError::InvalidEvent { .. })
    ));
    assert!(matches!(
        s.dispatch(r#"{"eventId": "e"}"#),
        Err(ProtocolError::InvalidEvent { .. })
    ));
    assert!(matches!(
        s.dispatch_batch("[{]"),
        Err(ProtocolError::InvalidEvent { .. })
    ));
    assert!(matches!(
        s.dispatch_batch("{}"),
        Err(ProtocolError::InvalidEvent { .. })
    ));
}

#[test]
fn foreign_session_events_are_rejected() {
    let mut s = fresh();
    let events = base_events();
    s.dispatch(&events[0]).unwrap();
    let foreign = json!({
        "eventId": "ev-x",
        "sessionId": "other-session",
        "sequence": 1,
        "timestamp": "2026-01-01T00:00:00Z",
        "type": "run.started",
        "payload": pv(json!({"run": {"id": "r9", "status": "running"}})),
    })
    .to_string();
    assert!(matches!(
        s.dispatch(&foreign),
        Err(ProtocolError::InvalidEvent { .. })
    ));
}

#[test]
fn empty_identifiers_are_rejected() {
    let mut s = fresh();
    let no_id = json!({
        "eventId": "",
        "sessionId": SID,
        "sequence": 0,
        "timestamp": "t",
        "type": "session.created",
        "payload": pv(json!({"session": {"id": SID}})),
    })
    .to_string();
    assert!(matches!(
        s.dispatch(&no_id),
        Err(ProtocolError::InvalidEvent { .. })
    ));
    let no_session = json!({
        "eventId": "e0",
        "sessionId": "",
        "sequence": 0,
        "timestamp": "t",
        "type": "session.created",
        "payload": pv(json!({"session": {"id": SID}})),
    })
    .to_string();
    assert!(matches!(
        s.dispatch(&no_session),
        Err(ProtocolError::InvalidEvent { .. })
    ));
}

// ---- batch -----------------------------------------------------------------

#[test]
fn batch_is_equivalent_to_sequential_dispatch() {
    let events = base_events();
    let mut a = fresh();
    dispatch_all(&mut a, &events);

    let mut b = fresh();
    let report = b
        .dispatch_batch(&format!("[{}]", events.join(",")))
        .unwrap();
    assert_eq!(report.applied as usize, events.len());
    assert_eq!(a.serialize().unwrap(), b.serialize().unwrap());
}

#[test]
fn batch_with_malformed_element_applies_nothing() {
    let events = base_events();
    let mut batch: Vec<String> = events[..3].to_vec();
    batch.push("{not json".to_string());
    batch.extend_from_slice(&events[3..]);

    let mut s = fresh();
    assert!(matches!(
        s.dispatch_batch(&format!("[{}]", batch.join(","))),
        Err(ProtocolError::InvalidEvent { .. })
    ));
    assert_eq!(s.serialize().unwrap(), fresh().serialize().unwrap());
}

#[test]
fn batch_hard_error_stops_but_keeps_applied() {
    let events = base_events();
    // seq 3 replaced with an invalid payload (message.created missing message).
    let mut batch: Vec<String> = events[..5].to_vec();
    batch[3] = event(3, "message.created", pv(json!({"notMessage": true})));

    let mut s = fresh();
    assert!(matches!(
        s.dispatch_batch(&format!("[{}]", batch.join(","))),
        Err(ProtocolError::InvalidEvent { .. })
    ));
    // seqs 0-2 applied; the stream is parked at next_expected 3 — a later
    // event buffers rather than corrupting.
    let report = s.dispatch(&events[5]).unwrap();
    assert_eq!(report.buffered, 1);
}

// ---- persistence -----------------------------------------------------------

#[test]
fn serialize_restore_serialize_is_byte_identical() {
    let mut s = fresh();
    dispatch_all(&mut s, &base_events());
    let saved = s.serialize().unwrap();
    let restored = AiuxSession::restore(&saved).unwrap();
    assert_eq!(restored.serialize().unwrap(), saved);
}

#[test]
fn restore_resumes_sequence_and_idempotency() {
    let mut s = fresh();
    let events = base_events();
    // Apply part, buffer seq 5, then persist mid-stream.
    dispatch_all(&mut s, &events[..4]);
    s.dispatch(&events[5]).unwrap(); // buffered (seq 5 > expected 4)
    let saved = s.serialize().unwrap();

    let mut restored = AiuxSession::restore(&saved).unwrap();
    // Replayed buffered id still counts as duplicate after restore.
    let report = restored.dispatch(&events[5]).unwrap();
    assert_eq!(report.duplicates_ignored, 1);
    // Fill the gap; the buffered event drains.
    let report = restored.dispatch(&events[4]).unwrap();
    assert_eq!(report.applied, 2);
    dispatch_all(&mut restored, &events[6..]);

    let mut uninterrupted = fresh();
    dispatch_all(&mut uninterrupted, &events);
    assert_eq!(
        restored.serialize().unwrap(),
        uninterrupted.serialize().unwrap()
    );
}

#[test]
fn restore_rejects_corrupt_and_wrong_version() {
    assert!(matches!(
        AiuxSession::restore("{"),
        Err(ProtocolError::CorruptState { .. })
    ));
    let wrong = json!({
        "protocolVersion": "9.9",
        "sessionId": SID,
        "state": {},
        "nextExpectedSequence": 0,
        "seenEventIds": [],
        "bufferedEvents": [],
    })
    .to_string();
    assert!(matches!(
        AiuxSession::restore(&wrong),
        Err(ProtocolError::Unsupported { .. })
    ));
}

#[test]
fn reset_clears_all_state() {
    let mut s = fresh();
    dispatch_all(&mut s, &base_events());
    s.reset();
    assert_eq!(s.serialize().unwrap(), fresh().serialize().unwrap());
    // And dispatch resumes from sequence 0.
    s.dispatch(&base_events()[0]).unwrap();
}

// ---- snapshot --------------------------------------------------------------

#[test]
fn snapshot_projects_render_state_without_bookkeeping() {
    let mut s = fresh();
    dispatch_all(&mut s, &base_events());
    let snap: serde_json::Value = serde_json::from_str(&s.snapshot().unwrap()).unwrap();
    assert_eq!(snap["sessionId"], SID);
    assert_eq!(snap["protocolVersion"], "0.1");
    assert!(snap["seenEventIds"].is_null());
    assert!(snap["nextExpectedSequence"].is_null());
    assert_eq!(snap["messages"].as_array().unwrap().len(), 2);
    assert_eq!(snap["tools"].as_array().unwrap().len(), 1);
    assert_eq!(snap["surfaces"].as_array().unwrap()[0]["revision"], 1);
}

#[test]
fn serialization_is_byte_stable_across_identical_streams() {
    let mut a = fresh();
    let mut b = fresh();
    let events = base_events();
    dispatch_all(&mut a, &events);
    dispatch_all(&mut b, &events);
    assert_eq!(a.serialize().unwrap(), b.serialize().unwrap());
}
