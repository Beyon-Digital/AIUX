import AIUXExampleApp
import AIUXSwiftUI
import Foundation

// MARK: - Headless scenario gate (Phase 3)
//
// `swift run AIUXExample` plays the mocked agent interaction end-to-end
// through the REAL UniFFI `AiuxSession` — user prompt → streaming text →
// tool lifecycle → approval → approve → markdown + artifact + surface — and
// asserts the render snapshot at each stage. Exits non-zero on failure.
//
// This is the same script the SwiftUI app plays interactively.

enum GateError: Error, CustomStringConvertible {
    case stage(name: String, reason: String)
    var description: String {
        switch self {
        case .stage(let name, let reason): return "stage '\(name)' failed: \(reason)"
        }
    }
}

var factory = DemoEventFactory(sessionId: DemoScenario.sessionId)
let decoder = JSONDecoder()

func snapshot(of backend: AIUXSessionBackend) throws -> AIUXSnapshot {
    try decoder.decode(AIUXSnapshot.self, from: Data(backend.snapshot().utf8))
}

func ingest(_ backend: AIUXSessionBackend, _ events: [String], stage: String) throws {
    _ = try backend.dispatchBatch(eventsJson: "[" + events.joined(separator: ",") + "]")
    print("  ✓ \(stage) (\(events.count) events)")
}

do {
    print("AIUX example — mocked agent gate")
    let backend = try UniFFIBackend.create(configJson: #"{"sessionId":"demo"}"#)

    // 1. session.created — context bar entities visible.
    try ingest(backend, [DemoScenario.sessionCreated(factory: &factory)], stage: "session.created")
    var snap = try snapshot(of: backend)
    guard snap.session?.title == "AIUX demo", snap.context.count == 2 else {
        throw GateError.stage(name: "session", reason: "expected session + 2 context entities")
    }

    // 2. User prompt.
    try ingest(
        backend,
        [DemoScenario.userMessage(factory: &factory, messageId: "m-user-1", text: "Publish the report")],
        stage: "user prompt"
    )

    // 3. Agent stream up to the approval request.
    try ingest(
        backend,
        DemoScenario.preApprovalEvents(turn: 1).map { factory.event($0) },
        stage: "agent stream"
    )
    snap = try snapshot(of: backend)
    guard snap.messages.count == 2,
          snap.tools.first?.status == .completed,
          snap.approvals.first?.status == .requested,
          snap.activeRunId == "r1"
    else {
        throw GateError.stage(
            name: "agent stream",
            reason: "expected streaming message, completed tool, requested approval, active run"
        )
    }

    // 4. User approves → executed → markdown + artifact + surface + complete.
    try ingest(
        backend,
        DemoScenario.postApprovalEvents(turn: 1, approved: true).map { factory.event($0) },
        stage: "approve + result"
    )
    snap = try snapshot(of: backend)
    guard snap.approvals.first?.status == .executed,
          snap.messages.last?.status == .complete,
          snap.artifacts.count == 1,
          snap.surfaces.count == 1,
          snap.activeRunId == nil
    else {
        throw GateError.stage(
            name: "approve + result",
            reason: "expected executed approval, complete message, 1 artifact, 1 surface, run done"
        )
    }
    let partKinds = snap.messages.last?.parts.map(\.kind) ?? []
    for expected in ["text", "tool", "approval", "markdown", "artifact", "surface"] {
        guard partKinds.contains(expected) else {
            throw GateError.stage(name: "parts", reason: "missing part kind '\(expected)'")
        }
    }

    // 5. Render-model resolution — views consume `AIUXRenderModel`, not the
    // raw snapshot. Every entity a part references must resolve through it
    // (headless CI can't instantiate views; this is the binding layer they
    // bind to).
    let model = AIUXRenderModel(snapshot: snap)
    for tool in snap.tools {
        guard model.tool(tool.id) != nil else {
            throw GateError.stage(name: "render model", reason: "tool '\(tool.id)' unresolved")
        }
    }
    for approval in snap.approvals {
        guard model.approval(approval.id) != nil else {
            throw GateError.stage(name: "render model", reason: "approval '\(approval.id)' unresolved")
        }
    }
    for artifact in snap.artifacts {
        guard model.artifact(artifact.id) != nil else {
            throw GateError.stage(name: "render model", reason: "artifact '\(artifact.id)' unresolved")
        }
    }
    for surface in snap.surfaces {
        guard model.surface(surface.id) != nil else {
            throw GateError.stage(name: "render model", reason: "surface '\(surface.id)' unresolved")
        }
    }
    print("  ✓ render model (\(snap.tools.count + snap.approvals.count + snap.artifacts.count + snap.surfaces.count) entities resolved)")

    // 6. Serialize/restore parity.
    let serialized = try backend.serialize()
    let restored = try UniFFIBackend.restore(serializedJson: serialized)
    guard try snapshot(of: restored) == snap else {
        throw GateError.stage(name: "restore", reason: "restored snapshot mismatch")
    }

    print("Phase 3 gate passed — mocked agent interaction reduced end-to-end.")
} catch {
    FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
    exit(1)
}
