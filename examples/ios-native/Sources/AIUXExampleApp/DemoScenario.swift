import AIUXSwiftUI
import Foundation

// MARK: - Mocked agent scenario (Phase 3 gate)
//
// `DemoScenario` authors protocol events for the scripted interaction:
//   user prompt → streaming assistant text → tool start → tool progress →
//   tool finish → approval request → (user approve) → approval executed →
//   markdown + artifact + surface results.
//
// Events are ordinary protocol JSON envelopes, fabricated client-side with
// monotonically increasing `sequence` — exactly what a remote agent stream
// would send.

/// Builds protocol event envelopes for the demo session.
public struct DemoEventFactory {
    public let sessionId: String
    private var sequence = 0

    public init(sessionId: String) {
        self.sessionId = sessionId
    }

    /// The next event envelope as compact JSON.
    public mutating func event(type: String, payload: [String: Any]) -> String {
        defer { sequence += 1 }
        let envelope: [String: Any] = [
            "eventId": "demo-\(sequence)",
            "sessionId": sessionId,
            "sequence": sequence,
            "timestamp": ISO8601DateFormatter().string(
                from: Date(timeIntervalSince1970: 1_767_225_600 + Double(sequence))
            ),
            "type": type,
            "protocolVersion": AIUXSwiftUI.protocolVersion,
            "payload": payload,
        ]
        // Payloads/events are always JSON-serializable dictionaries.
        let data = try! JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    /// The protocol version stamped on payloads (fixtures carry one too).
    public var pv: String { AIUXSwiftUI.protocolVersion }
}

/// The scripted agent interaction.
public enum DemoScenario {
    public static let sessionId = "demo"

    /// `session.created` — establishes the session + context entities so the
    /// context bar renders from the first frame.
    public static func sessionCreated(factory: inout DemoEventFactory) -> String {
        factory.event(type: "session.created", payload: [
            "protocolVersion": factory.pv,
            "session": [
                "id": sessionId,
                "title": "AIUX demo",
                "createdAt": "2026-01-02T00:00:00Z",
                "context": [
                    ["id": "ctx-file", "kind": "file", "label": "report-draft.md",
                     "uri": "aiux://files/report-draft"],
                    ["id": "ctx-doc", "kind": "url", "label": "AIUX spec",
                     "uri": "https://docs.beyondigital.in/aiux"],
                ],
            ],
        ])
    }

    /// The user message echo for a prompt.
    public static func userMessage(factory: inout DemoEventFactory, messageId: String, text: String) -> String {
        factory.event(type: "message.created", payload: [
            "protocolVersion": factory.pv,
            "message": [
                "id": messageId,
                "role": "user",
                "parts": [["id": "\(messageId)-p0", "type": "text", "text": text]],
            ],
        ])
    }

    /// Events the agent streams *before* the approval request — run start,
    /// streaming text, tool lifecycle, then the `approval.requested` with its
    /// in-message `approval` part.
    public static func preApprovalEvents(factory: inout DemoEventFactory, turn: Int) -> [String] {
        let runId = "r\(turn)"
        let messageId = "m-agent-\(turn)"
        let toolId = "t\(turn)"
        let approvalId = "a\(turn)"
        var events: [String] = []

        events.append(factory.event(type: "run.started", payload: [
            "protocolVersion": factory.pv,
            "run": ["id": runId, "status": "running", "startedAt": "2026-01-02T00:00:01Z"],
        ]))
        events.append(factory.event(type: "message.created", payload: [
            "protocolVersion": factory.pv,
            "message": ["id": messageId, "role": "assistant", "status": "streaming"],
        ]))
        events.append(factory.event(type: "part.added", payload: [
            "protocolVersion": factory.pv,
            "messageId": messageId,
            "part": ["id": "\(messageId)-text", "type": "text", "text": ""],
        ]))
        for chunk in ["Searching ", "your workspace ", "for the ", "report…"] {
            events.append(factory.event(type: "text.delta", payload: [
                "protocolVersion": factory.pv,
                "messageId": messageId,
                "partId": "\(messageId)-text",
                "delta": chunk,
            ]))
        }
        events.append(factory.event(type: "part.added", payload: [
            "protocolVersion": factory.pv,
            "messageId": messageId,
            "part": ["id": "\(messageId)-tool", "type": "tool", "toolId": toolId],
        ]))
        events.append(factory.event(type: "tool.started", payload: [
            "protocolVersion": factory.pv,
            "tool": ["id": toolId, "name": "search", "status": "running",
                     "input": ["q": "quarterly report"]],
        ]))
        events.append(factory.event(type: "tool.progress", payload: [
            "protocolVersion": factory.pv, "toolId": toolId,
            "progress": ["current": 1, "total": 3, "label": "querying"],
        ]))
        events.append(factory.event(type: "tool.progress", payload: [
            "protocolVersion": factory.pv, "toolId": toolId,
            "progress": ["current": 3, "total": 3, "label": "ranking"],
        ]))
        events.append(factory.event(type: "tool.completed", payload: [
            "protocolVersion": factory.pv, "toolId": toolId,
            "result": ["hits": 3],
        ]))
        events.append(factory.event(type: "part.added", payload: [
            "protocolVersion": factory.pv,
            "messageId": messageId,
            "part": ["id": "\(messageId)-approval", "type": "approval", "approvalId": approvalId],
        ]))
        events.append(factory.event(type: "approval.requested", payload: [
            "protocolVersion": factory.pv,
            "approval": [
                "id": approvalId,
                "prompt": "Publish the quarterly report?",
                "description": "Creates the report artifact and posts the summary card.",
                "status": "requested",
                "expiresAt": "2026-01-02T01:00:00Z",
                "action": ["id": "report.publish", "payload": ["reportId": "rpt-\(turn)"]],
            ],
        ]))
        return events
    }

    /// Events after the approval resolves — branches on the decision:
    /// approved → executed → markdown + artifact + surface result;
    /// rejected → rejected status + polite wrap-up.
    public static func postApprovalEvents(
        factory: inout DemoEventFactory,
        turn: Int,
        approved: Bool
    ) -> [String] {
        let runId = "r\(turn)"
        let messageId = "m-agent-\(turn)"
        let approvalId = "a\(turn)"
        var events: [String] = []

        events.append(factory.event(type: "approval.resolved", payload: [
            "protocolVersion": factory.pv,
            "approvalId": approvalId,
            "resolution": [
                "decision": approved ? "approved" : "rejected",
                "resolvedBy": "user",
                "resolvedAt": "2026-01-02T00:00:20Z",
            ],
        ]))

        if !approved {
            events.append(factory.event(type: "part.added", payload: [
                "protocolVersion": factory.pv,
                "messageId": messageId,
                "part": ["id": "\(messageId)-note", "type": "status",
                         "text": "Publication cancelled.", "level": "warning"],
            ]))
            events.append(factory.event(type: "message.updated", payload: [
                "protocolVersion": factory.pv, "messageId": messageId, "status": "complete",
            ]))
            events.append(factory.event(type: "run.completed", payload: [
                "protocolVersion": factory.pv, "runId": runId,
            ]))
            return events
        }

        events.append(factory.event(type: "approval.resolved", payload: [
            "protocolVersion": factory.pv,
            "approvalId": approvalId,
            "resolution": [
                "decision": "executed",
                "resolvedBy": "host",
                "resolvedAt": "2026-01-02T00:00:25Z",
            ],
        ]))
        events.append(factory.event(type: "part.added", payload: [
            "protocolVersion": factory.pv,
            "messageId": messageId,
            "part": ["id": "\(messageId)-result", "type": "markdown",
                     "markdown": "**Report published.** Summary card below."],
        ]))
        events.append(factory.event(type: "artifact.created", payload: [
            "protocolVersion": factory.pv,
            "artifact": [
                "id": "art-\(turn)", "kind": "document",
                "title": "quarterly-report.md", "revision": 0,
                "content": "# Quarterly report\n\n- Revenue: $420.00\n- Status: published\n",
            ],
        ]))
        events.append(factory.event(type: "part.added", payload: [
            "protocolVersion": factory.pv,
            "messageId": messageId,
            "part": ["id": "\(messageId)-artifact", "type": "artifact", "artifactId": "art-\(turn)"],
        ]))
        events.append(factory.event(type: "surface.created", payload: [
            "protocolVersion": factory.pv,
            "surface": [
                "id": "sf-\(turn)", "name": "report-card", "revision": 0,
                "root": [
                    "type": "surface", "gap": "sm",
                    "children": [
                        ["type": "heading", "text": "Quarterly report", "level": 2],
                        ["type": "keyValue", "items": [
                            ["key": "Total", "value": "$420.00"],
                            ["key": "Status", "value": "published"],
                        ]],
                        ["type": "status", "text": "Published to workspace", "tone": "success"],
                        ["type": "actions", "children": [
                            ["type": "button", "label": "Open report", "variant": "primary",
                             "action": ["id": "report.open", "payload": ["reportId": "rpt-\(turn)"]]],
                            ["type": "button", "label": "Share", "variant": "secondary",
                             "action": ["id": "report.share", "payload": ["reportId": "rpt-\(turn)"]]],
                        ]],
                    ],
                ],
            ],
        ]))
        events.append(factory.event(type: "part.added", payload: [
            "protocolVersion": factory.pv,
            "messageId": messageId,
            "part": ["id": "\(messageId)-surface", "type": "surface", "surfaceId": "sf-\(turn)"],
        ]))
        events.append(factory.event(type: "message.updated", payload: [
            "protocolVersion": factory.pv, "messageId": messageId, "status": "complete",
        ]))
        events.append(factory.event(type: "run.completed", payload: [
            "protocolVersion": factory.pv,
            "runId": runId,
            "result": ["published": true],
        ]))
        return events
    }

    /// Cancellation events when the user stops a running turn.
    public static func cancelEvents(factory: inout DemoEventFactory, turn: Int) -> [String] {
        let runId = "r\(turn)"
        let messageId = "m-agent-\(turn)"
        return [
            factory.event(type: "run.cancelled", payload: [
                "protocolVersion": factory.pv, "runId": runId, "reason": "user pressed stop",
            ]),
            factory.event(type: "message.updated", payload: [
                "protocolVersion": factory.pv, "messageId": messageId, "status": "cancelled",
            ]),
        ]
    }
}
