#!/usr/bin/env python3
"""Generate conformance/fixtures/*.json for Phase 1.

One-shot authoring tool: emits canonical fixture files per plan §17.
Run from the repo root:  python3 tools/gen_fixtures.py
Then:  cargo run -p aiux-conformance -- bless conformance/fixtures conformance/expected
"""

import json
import os
import copy

FIXTURES = os.path.join(os.path.dirname(__file__), "..", "conformance", "fixtures")
SID = "s1"


def payload(p):
    return {"protocolVersion": "0.1", **p}


def ev(seq, kind, p, name):
    return {
        "eventId": f"{name}-{seq}",
        "sessionId": SID,
        "sequence": seq,
        "timestamp": f"2026-01-01T00:{seq // 60:02d}:{seq % 60:02d}Z",
        "type": kind,
        "protocolVersion": "0.1",
        "payload": payload(p),
    }


def session_created(title):
    return ("session.created", {
        "session": {"id": SID, "title": title, "createdAt": "2026-01-01T00:00:00Z"}
    })


def run_started(run_id="r1", extra=None):
    run = {"id": run_id, "status": "running", "startedAt": "2026-01-01T00:00:01Z"}
    if extra:
        run.update(extra)
    return ("run.started", {"run": run})


def user_msg(msg_id="m-user", text="Hi"):
    return ("message.created", {
        "message": {"id": msg_id, "role": "user",
                    "parts": [{"type": "text", "id": f"{msg_id}-p0", "text": text}]}
    })


def assistant_msg(msg_id="m1"):
    return ("message.created", {
        "message": {"id": msg_id, "role": "assistant", "status": "streaming"}
    })


def write(name, events):
    doc = {"name": name, "protocolVersion": "0.1", "events": events}
    path = os.path.join(FIXTURES, f"{name}.json")
    with open(path, "w") as f:
        json.dump(doc, f, indent=2, sort_keys=True)
        f.write("\n")
    print(f"wrote {name}.json ({len(events)} events)")


def build_all():
    name = "basic-response"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate([
        session_created("Basic response"),
        run_started(),
        user_msg(text="What is the answer?"),
        assistant_msg(),
        ("part.added", {"messageId": "m1",
                        "part": {"type": "text", "id": "p1",
                                 "text": "The answer is 42."}}),
        ("message.updated", {"messageId": "m1", "status": "complete"}),
        ("run.completed", {"runId": "r1", "result": {"ok": True}}),
    ])])

    name = "streaming-response"
    deltas = ["Hello, ", "stream", "ing ", "world", "!"]
    kinds = [
        session_created("Streaming response"),
        run_started(),
        assistant_msg(),
        ("part.added", {"messageId": "m1",
                        "part": {"type": "text", "id": "p1", "text": ""}}),
    ]
    kinds += [("text.delta", {"messageId": "m1", "partId": "p1", "delta": d})
              for d in deltas]
    kinds += [
        ("message.updated", {"messageId": "m1", "status": "complete"}),
        ("run.completed", {"runId": "r1"}),
    ]
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate(kinds)])

    name = "markdown-code"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate([
        session_created("Markdown + code"),
        run_started(),
        assistant_msg(),
        ("part.added", {"messageId": "m1",
                        "part": {"type": "markdown", "id": "p1",
                                 "markdown": "# Result\n\nHere is "}}),
        ("text.delta", {"messageId": "m1", "partId": "p1",
                        "delta": "the snippet:"}),
        ("part.added", {"messageId": "m1",
                        "part": {"type": "code", "id": "p2",
                                 "language": "rust",
                                 "code": "fn main() {}"}}),
        ("part.updated", {"messageId": "m1", "partId": "p2",
                          "part": {"type": "code", "id": "p2",
                                   "language": "rust",
                                   "code": "fn main() { println!(\"hi\"); }"}}),
        ("message.updated", {"messageId": "m1", "status": "complete"}),
        ("run.completed", {"runId": "r1"}),
    ])])

    tool_started = ("tool.started", {"tool": {"id": "t1", "name": "search",
                                              "status": "running",
                                              "input": {"q": "aiux spec"}}})
    progress1 = ("tool.progress", {"toolId": "t1", "progress": {
        "current": 1, "total": 4, "label": "querying"}})
    progress2 = ("tool.progress", {"toolId": "t1", "progress": {
        "current": 3, "total": 4, "label": "ranking"}})

    name = "tool-started"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate(
        [session_created("Tool started"), run_started(),
         tool_started])])

    name = "tool-progress"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate(
        [session_created("Tool progress"), run_started(),
         tool_started, progress1, progress2])])

    name = "tool-success"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate(
        [session_created("Tool success"), run_started(),
         tool_started, progress1, progress2,
         ("tool.completed", {"toolId": "t1",
                             "result": {"hits": 3},
                             }),
         ("run.completed", {"runId": "r1"})])])

    name = "tool-failure"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate(
        [session_created("Tool failure"), run_started(),
         tool_started, progress1,
         ("tool.failed", {"toolId": "t1", "error": {
             "code": "TIMEOUT",
             "message": "search backend timed out after 30s",
             "retryable": True}}),
         ("run.failed", {"runId": "r1", "error": {
             "code": "TOOL_FAILURE", "message": "search failed"}})])])

    approval_requested = ("approval.requested", {"approval": {
        "id": "a1",
        "prompt": "Delete 12 stale branches?",
        "description": "Git cleanup action",
        "status": "requested",
        "action": {"id": "git.prune", "payload": {"count": 12}},
        "expiresAt": "2026-01-01T01:00:00Z"}})

    name = "approval-requested"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate(
        [session_created("Approval requested"), run_started(),
         approval_requested])])

    name = "approval-rejected"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate(
        [session_created("Approval rejected"), run_started(),
         approval_requested,
         ("approval.resolved", {"approvalId": "a1", "resolution": {
             "decision": "rejected", "resolvedBy": "user",
             "note": "too risky",
             "resolvedAt": "2026-01-01T00:10:00Z"}}),
         ("run.completed", {"runId": "r1", "result": {"applied": False}})])])

    name = "approval-accepted"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate(
        [session_created("Approval accepted"), run_started(),
         approval_requested,
         ("approval.resolved", {"approvalId": "a1", "resolution": {
             "decision": "approved", "resolvedBy": "user",
             "resolvedAt": "2026-01-01T00:09:00Z"}}),
         ("approval.resolved", {"approvalId": "a1", "resolution": {
             "decision": "executed", "resolvedBy": "host",
             "resolvedAt": "2026-01-01T00:09:30Z"}}),
         ("run.completed", {"runId": "r1", "result": {"pruned": 12}})])])

    name = "artifact-update"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate([
        session_created("Artifact update"),
        run_started(),
        ("artifact.created", {"artifact": {
            "id": "art-1", "kind": "code", "title": "lib.rs",
            "revision": 0, "content": "pub fn a() {}"}}),
        ("artifact.updated", {"artifactId": "art-1",
                              "content": "pub fn a() {}\npub fn b() {}"}),
        ("artifact.updated", {"artifactId": "art-1",
                              "title": "lib.rs (v2)",
                              "metadata": {"format": "rustfmt"}}),
        ("run.completed", {"runId": "r1"}),
    ])])

    name = "attachment"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate([
        session_created("Attachment"),
        run_started(),
        ("message.created", {"message": {
            "id": "m-u", "role": "user",
            "parts": [
                {"type": "text", "id": "p0", "text": "See the spec:"},
                {"type": "attachment", "id": "p1", "attachment": {
                    "id": "file-1", "name": "aiux-spec.pdf",
                    "mimeType": "application/pdf",
                    "uri": "aiux://files/file-1",
                    "sizeBytes": 20480}},
            ]}}),
        ("run.completed", {"runId": "r1"}),
    ])])

    name = "citation"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate([
        session_created("Citation"),
        run_started(),
        assistant_msg(),
        ("part.added", {"messageId": "m1",
                        "part": {"type": "text", "id": "p1",
                                 "text": "Per the plan, Phase 1 ships the core."}}),
        ("part.added", {"messageId": "m1",
                        "part": {"type": "citation", "id": "p2", "citation": {
                            "id": "c1", "title": "AIUX Plan §1",
                            "uri": "https://docs.beyondigital.in/aiux/plan",
                            "snippet": "Protocol v1 + Rust core",
                            "source": "docs-index"}}}),
        ("message.updated", {"messageId": "m1", "status": "complete"}),
        ("run.completed", {"runId": "r1"}),
    ])])

    name = "context-injection"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate([
        ("session.created", {"session": {
            "id": SID, "title": "Context injection",
            "context": [
                {"id": "ctx-1", "kind": "file", "label": "Cargo.toml",
                 "uri": "aiux://files/cargo-toml"},
                {"id": "ctx-2", "kind": "issue", "label": "AIUX-7",
                 "data": {"priority": "high"}},
            ]}}),
        ("run.started", {"run": {"id": "r1", "status": "running"},
                         "context": [
                             {"id": "ctx-3", "kind": "url",
                              "label": "Design doc",
                              "uri": "https://docs.beyondigital.in/aiux"}]}),
        ("run.completed", {"runId": "r1"}),
    ])])

    name = "retry"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate([
        session_created("Retry"),
        run_started("r1"),
        ("run.failed", {"runId": "r1", "error": {
            "code": "UPSTREAM_503", "message": "backend unavailable",
            "retryable": True}}),
        ("run.started", {"run": {
            "id": "r2", "status": "running", "retryOf": "r1",
            "startedAt": "2026-01-01T00:00:30Z"}}),
        assistant_msg(),
        ("part.added", {"messageId": "m1",
                        "part": {"type": "text", "id": "p1",
                                 "text": "Retry succeeded."}}),
        ("message.updated", {"messageId": "m1", "status": "complete"}),
        ("run.completed", {"runId": "r2", "result": {"attempt": 2}}),
    ])])

    name = "cancel"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate([
        session_created("Cancel"),
        run_started(),
        assistant_msg(),
        ("part.added", {"messageId": "m1",
                        "part": {"type": "text", "id": "p1",
                                 "text": "Partial answ"}}),
        ("run.cancelled", {"runId": "r1", "reason": "user pressed stop"}),
        ("message.updated", {"messageId": "m1", "status": "cancelled"}),
    ])])

    # Network reconnect: stream stalls, reconnect replays the last acked event
    # (duplicate eventId), then delivers queued events out of order.
    name = "network-reconnect"
    kinds = [
        session_created("Network reconnect"),
        run_started(),
        assistant_msg(),
        ("text.delta", {"messageId": "m1", "partId": "p1", "delta": "Hel"}),
        ("part.added", {"messageId": "m1",
                        "part": {"type": "text", "id": "p1", "text": ""}}),
        ("text.delta", {"messageId": "m1", "partId": "p1", "delta": "lo"}),
        ("message.updated", {"messageId": "m1", "status": "complete"}),
        ("run.completed", {"runId": "r1"}),
    ]
    # NOTE seq order validity: part.added (seq 4) must precede its deltas
    # (seqs 3, 5) in sequence order — swap so seq application order is legal.
    kinds[3], kinds[4] = kinds[4], kinds[3]
    events = [ev(i, k, p, name) for i, (k, p) in enumerate(kinds)]
    # Delivery order after reconnect: 0,1,2, dup(2), 5, 4, 3, 6, 7
    order = [0, 1, 2, 2, 5, 4, 3, 6, 7]
    write(name, [copy.deepcopy(events[i]) for i in order])

    # Duplicate events: literal replays inline.
    name = "duplicate-events"
    kinds = [
        session_created("Duplicate events"),
        run_started(),
        assistant_msg(),
        ("part.added", {"messageId": "m1",
                        "part": {"type": "text", "id": "p1", "text": "Hi"}}),
        ("message.updated", {"messageId": "m1", "status": "complete"}),
        ("run.completed", {"runId": "r1"}),
    ]
    events = [ev(i, k, p, name) for i, (k, p) in enumerate(kinds)]
    order = [0, 1, 1, 2, 3, 2, 3, 4, 5, 0, 4, 5]
    write(name, [copy.deepcopy(events[i]) for i in order])

    # Out-of-order delivery — shuffled delivery order, unique sequences.
    name = "out-of-order-events"
    kinds = [
        session_created("Out of order"),
        run_started(),
        assistant_msg(),
        ("part.added", {"messageId": "m1",
                        "part": {"type": "text", "id": "p1", "text": "Hel"}}),
        ("text.delta", {"messageId": "m1", "partId": "p1", "delta": "lo"}),
        ("tool.started", {"tool": {"id": "t1", "name": "lookup",
                                   "status": "running"}}),
        ("tool.completed", {"toolId": "t1", "result": {"found": True}}),
        ("run.completed", {"runId": "r1"}),
    ]
    events = [ev(i, k, p, name) for i, (k, p) in enumerate(kinds)]
    order = [2, 0, 5, 1, 4, 3, 7, 6]
    write(name, [events[i] for i in order])

    # Large history: 201 messages (alternating user/assistant) — ≥200 per spec.
    name = "large-history"
    kinds = [session_created("Large history"), run_started()]
    for i in range(100):
        kinds.append(("message.created", {"message": {
            "id": f"m-u{i}", "role": "user",
            "parts": [{"type": "text", "id": f"p-u{i}",
                       "text": f"Question {i}"}]}}))
        kinds.append(("message.created", {"message": {
            "id": f"m-a{i}", "role": "assistant", "status": "complete",
            "parts": [{"type": "text", "id": f"p-a{i}",
                       "text": f"Answer {i}"}]}}))
    kinds.append(("run.completed", {"runId": "r1"}))
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate(kinds)])

    surface_root = {"type": "surface", "children": [
        {"type": "heading", "level": 1, "text": "Invoice summary"},
        {"type": "stack", "direction": "vertical", "gap": "sm",
         "children": [
             {"type": "keyValue", "items": [
                 {"key": "Total", "value": "$420.00"},
                 {"key": "Status", "value": "pending"}]},
             {"type": "badge", "text": "Due soon", "tone": "warning"},
         ]},
        {"type": "actions", "children": [
            {"type": "button", "label": "Approve",
             "action": {"id": "invoice.approve", "payload": {"id": "inv-9"}},
             "variant": "primary"},
            {"type": "button", "label": "Decline",
             "action": {"id": "invoice.decline", "payload": {"id": "inv-9"}},
             "variant": "secondary"},
        ]},
    ]}

    name = "surface-created"
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate([
        session_created("Surface created"),
        run_started(),
        ("message.created", {"message": {
            "id": "m1", "role": "assistant", "status": "complete"}}),
        ("surface.created", {"surface": {
            "id": "sf-1", "name": "invoice-card",
            "revision": 0, "root": surface_root}}),
        ("part.added", {"messageId": "m1", "part": {
            "type": "surface", "id": "p1", "surfaceId": "sf-1"}}),
        ("run.completed", {"runId": "r1"}),
    ])])

    name = "surface-updated"
    updated_root = {"type": "surface", "children": [
        {"type": "heading", "level": 1, "text": "Invoice summary"},
        {"type": "status", "text": "Approved", "tone": "success"},
    ]}
    write(name, [ev(i, k, p, name) for i, (k, p) in enumerate([
        session_created("Surface updated"),
        run_started(),
        ("surface.created", {"surface": {
            "id": "sf-1", "name": "invoice-card",
            "revision": 0, "root": surface_root}}),
        ("surface.updated", {"surfaceId": "sf-1", "root": updated_root}),
        ("run.completed", {"runId": "r1"}),
    ])])


if __name__ == "__main__":
    os.makedirs(FIXTURES, exist_ok=True)
    build_all()
