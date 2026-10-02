//! Workload builders shared by the criterion benches and the memory probe.
//! Everything is built as event-envelope JSON strings — the same JSON the
//! `AiuxSession` facade takes over every FFI boundary (ADR 0005).

use serde_json::{json, Value};

pub const SID: &str = "bench-session";
pub const PV: &str = "0.1";

/// Merge `protocolVersion` into a payload object (required by the reducer).
fn pv(mut v: Value) -> Value {
    v.as_object_mut()
        .expect("payload must be an object")
        .insert("protocolVersion".into(), json!(PV));
    v
}

/// Canonical event envelope.
pub fn event(seq: u64, kind: &str, payload: Value) -> String {
    json!({
        "eventId": format!("ev-{seq}"),
        "sessionId": SID,
        "sequence": seq,
        "timestamp": "2026-01-01T00:00:00Z",
        "type": kind,
        "protocolVersion": PV,
        "payload": payload,
    })
    .to_string()
}

/// The ~20-event scenario covering every lifecycle kind (mirrors the
/// conformance base fixture): session → run → user/assistant messages →
/// streaming deltas → tool → approval → artifact → surface → run end.
pub fn base_events() -> Vec<String> {
    vec![
        event(
            0,
            "session.created",
            pv(json!({
                "session": {"id": SID, "title": "Bench base",
                    "createdAt": "2026-01-01T00:00:00Z",
                    "capabilities": [{"id": "tools.execute"}],
                    "context": [{"id": "ctx-1", "kind": "file", "label": "main.rs"}],
                }
            })),
        ),
        event(
            1,
            "run.started",
            pv(json!({"run": {"id": "r1", "status": "running",
                "startedAt": "2026-01-01T00:00:01Z"}})),
        ),
        event(
            2,
            "message.created",
            pv(json!({"message": {"id": "m-user", "role": "user",
                "parts": [{"type": "text", "id": "p0", "text": "Summarise"}]}})),
        ),
        event(
            3,
            "message.created",
            pv(json!({"message": {"id": "m1", "role": "assistant",
                "status": "streaming"}})),
        ),
        event(
            4,
            "part.added",
            pv(json!({"messageId": "m1",
                "part": {"type": "text", "id": "p1", "text": "Hello"}})),
        ),
        event(
            5,
            "text.delta",
            pv(json!({"messageId": "m1", "partId": "p1", "delta": ", "})),
        ),
        event(
            6,
            "text.delta",
            pv(json!({"messageId": "m1", "partId": "p1", "delta": "world"})),
        ),
        event(
            7,
            "tool.started",
            pv(
                json!({"tool": {"id": "t1", "name": "search", "status": "running",
                "input": {"q": "aiux"}}}),
            ),
        ),
        event(
            8,
            "tool.progress",
            pv(json!({"toolId": "t1",
                "progress": {"current": 1, "total": 2, "label": "fetching"}})),
        ),
        event(
            9,
            "tool.completed",
            pv(json!({"toolId": "t1", "result": {"hits": 3}})),
        ),
        event(
            10,
            "part.added",
            pv(json!({"messageId": "m1",
                "part": {"type": "tool", "id": "p2", "toolId": "t1"}})),
        ),
        event(
            11,
            "approval.requested",
            pv(json!({"approval": {"id": "a1", "prompt": "Apply changes?",
                "status": "requested"}})),
        ),
        event(
            12,
            "approval.resolved",
            pv(json!({"approvalId": "a1",
                "resolution": {"decision": "approved", "resolvedBy": "user"}})),
        ),
        event(
            13,
            "approval.resolved",
            pv(json!({"approvalId": "a1",
                "resolution": {"decision": "executed", "resolvedBy": "host"}})),
        ),
        event(
            14,
            "artifact.created",
            pv(json!({"artifact": {"id": "art-1", "kind": "code",
                "title": "main.rs", "revision": 0, "content": "fn main() {}"}})),
        ),
        event(
            15,
            "artifact.updated",
            pv(json!({"artifactId": "art-1",
                "content": "fn main() { println!(\"hi\"); }"})),
        ),
        event(
            16,
            "surface.created",
            pv(json!({"surface": {"id": "sf-1", "revision": 0,
                "root": {"type": "surface", "children": [
                    {"type": "heading", "level": 1, "text": "Summary"},
                    {"type": "text", "text": "v1 body"}]}}})),
        ),
        event(
            17,
            "surface.updated",
            pv(json!({"surfaceId": "sf-1",
                "root": {"type": "surface", "children": [
                    {"type": "text", "text": "v2 body"}]}})),
        ),
        event(
            18,
            "message.updated",
            pv(json!({"messageId": "m1", "status": "complete"})),
        ),
        event(
            19,
            "run.completed",
            pv(json!({"runId": "r1", "result": {"ok": true}})),
        ),
    ]
}

/// Convenience: `"[e1,e2,…]"` — the `dispatch_batch` wire shape.
pub fn batch_json(events: &[String]) -> String {
    format!("[{}]", events.join(","))
}

/// A long conversation: `turns` user+assistant exchanges → `2*turns` messages,
/// `1 + 4*turns` events total. Each assistant message gets one text part and
/// one streamed delta; each user message one inline part.
pub fn conversation_events(turns: usize) -> Vec<String> {
    let mut events = Vec::with_capacity(4 * turns + 1);
    let mut push = |kind: &str, payload: Value| {
        let seq = events.len() as u64;
        events.push(event(seq, kind, payload));
    };
    push(
        "session.created",
        pv(json!({"session": {"id": SID, "title": "Long conversation",
            "createdAt": "2026-01-01T00:00:00Z"}})),
    );
    for i in 0..turns {
        push(
            "message.created",
            pv(json!({"message": {"id": format!("u{i}"), "role": "user",
                "parts": [{"type": "text", "id": format!("u{i}-p0"),
                    "text": format!("Question {i}: tell me about topic {i}")}]}})),
        );
        push(
            "message.created",
            pv(
                json!({"message": {"id": format!("a{i}"), "role": "assistant",
                "status": "streaming"}}),
            ),
        );
        push(
            "part.added",
            pv(json!({"messageId": format!("a{i}"),
                "part": {"type": "text", "id": format!("a{i}-p0"),
                    "text": format!("Answer {i}.")}})),
        );
        push(
            "text.delta",
            pv(json!({"messageId": format!("a{i}"),
                "partId": format!("a{i}-p0"),
                "delta": format!(" Details about topic {i} follow here.")})),
        );
    }
    events
}

/// A streaming-heavy workload: one assistant message receiving `deltas`
/// `text.delta` events (the hot path every transport is tuned for, plan §22).
pub fn stream_events(deltas: usize) -> Vec<String> {
    let mut events = Vec::with_capacity(deltas + 4);
    let mut push = |kind: &str, payload: Value| {
        let seq = events.len() as u64;
        events.push(event(seq, kind, payload));
    };
    push("session.created", pv(json!({"session": {"id": SID}})));
    push(
        "run.started",
        pv(json!({"run": {"id": "r1", "status": "running"}})),
    );
    push(
        "message.created",
        pv(json!({"message": {"id": "m1", "role": "assistant",
            "status": "streaming"}})),
    );
    push(
        "part.added",
        pv(json!({"messageId": "m1",
            "part": {"type": "text", "id": "p1", "text": ""}})),
    );
    for i in 0..deltas {
        push(
            "text.delta",
            pv(json!({"messageId": "m1", "partId": "p1",
                "delta": format!("chunk-{i} ")})),
        );
    }
    events
}

/// A wide+deep surface tree as a `surface` root node (the schema requires
/// root type `surface`; children are nested `stack`/`text` nodes).
pub fn surface_tree(fanout: usize, depth: usize) -> Value {
    fn node(fanout: usize, depth: usize, path: String) -> Value {
        if depth == 0 {
            json!({"type": "text", "text": format!("leaf {path}")})
        } else {
            let children: Vec<Value> = (0..fanout)
                .map(|i| node(fanout, depth - 1, format!("{path}.{i}")))
                .collect();
            json!({"type": "stack", "gap": "sm", "children": children})
        }
    }
    json!({"type": "surface", "children": [node(fanout, depth, "root".to_string())]})
}
