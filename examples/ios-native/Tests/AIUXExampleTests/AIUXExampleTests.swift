import XCTest
@testable import AIUXExampleApp
import AIUXSwiftUI

/// Example E2E: the mocked scenario through the real UniFFI `AiuxSession`,
/// plus a conformance pass — every `conformance/fixtures/*.json` replayed and
/// semantically compared against `conformance/expected/*.json` through the
/// renderer's own decoders (Phase 3 gate, exercised on the macOS CI job).
final class AIUXExampleTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - Repo paths (same #filePath trick as bindings tests)

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // AIUXExampleTests.swift -> AIUXExampleTests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // ios-native/
            .deletingLastPathComponent() // examples/
            .deletingLastPathComponent() // repo root
    }

    private var fixturesDir: URL { repoRoot.appendingPathComponent("conformance/fixtures") }
    private var expectedDir: URL { repoRoot.appendingPathComponent("conformance/expected") }

    private func snapshot(of backend: AIUXSessionBackend) throws -> AIUXSnapshot {
        try decoder.decode(AIUXSnapshot.self, from: Data(backend.snapshot().utf8))
    }

    // MARK: - Mocked scenario end-to-end

    func testMockedAgentScenarioEndToEnd() throws {
        var factory = DemoEventFactory(sessionId: DemoScenario.sessionId)
        let backend = try UniFFIBackend.create(configJson: #"{"sessionId":"demo"}"#)

        _ = try backend.dispatch(eventJson: DemoScenario.sessionCreated(factory: &factory))
        _ = try backend.dispatch(eventJson: DemoScenario.userMessage(
            factory: &factory, messageId: "m-user-1", text: "Publish the report"
        ))
        _ = try backend.dispatchBatch(eventsJson:
            "[" + DemoScenario.preApprovalEvents(factory: &factory, turn: 1)
                .joined(separator: ",") + "]")

        var snap = try snapshot(of: backend)
        XCTAssertEqual(snap.messages.count, 2)
        XCTAssertEqual(snap.tools.first?.status, .completed)
        XCTAssertEqual(snap.approvals.first?.status, .requested)
        XCTAssertEqual(snap.activeRunId, "r1")
        // Streaming text accumulated via deltas.
        let textPart = snap.messages[1].parts.first { $0.kind == "text" }
        guard case .text(_, let text)? = textPart else {
            return XCTFail("assistant message lacks streamed text part")
        }
        XCTAssertEqual(text, "Searching your workspace for the report…")

        _ = try backend.dispatchBatch(eventsJson:
            "[" + DemoScenario.postApprovalEvents(factory: &factory, turn: 1, approved: true)
                .joined(separator: ",") + "]")

        snap = try snapshot(of: backend)
        XCTAssertEqual(snap.approvals.first?.status, .executed)
        XCTAssertEqual(snap.messages.last?.status, .complete)
        XCTAssertEqual(snap.artifacts.count, 1)
        XCTAssertEqual(snap.surfaces.count, 1)
        XCTAssertNil(snap.activeRunId)
        let kinds = snap.messages.last?.parts.map(\.kind) ?? []
        for kind in ["text", "tool", "approval", "markdown", "artifact", "surface"] {
            XCTAssertTrue(kinds.contains(kind), "missing part '\(kind)'")
        }
    }

    func testRejectedApprovalPath() throws {
        var factory = DemoEventFactory(sessionId: DemoScenario.sessionId)
        let backend = try UniFFIBackend.create(configJson: #"{"sessionId":"demo"}"#)
        _ = try backend.dispatch(eventJson: DemoScenario.sessionCreated(factory: &factory))
        _ = try backend.dispatchBatch(eventsJson:
            "[" + DemoScenario.preApprovalEvents(factory: &factory, turn: 1)
                .joined(separator: ",") + "]")
        _ = try backend.dispatchBatch(eventsJson:
            "[" + DemoScenario.postApprovalEvents(factory: &factory, turn: 1, approved: false)
                .joined(separator: ",") + "]")
        let snap = try snapshot(of: backend)
        XCTAssertEqual(snap.approvals.first?.status, .rejected)
        XCTAssertNil(snap.activeRunId)
    }

    func testCancelPath() throws {
        var factory = DemoEventFactory(sessionId: DemoScenario.sessionId)
        let backend = try UniFFIBackend.create(configJson: #"{"sessionId":"demo"}"#)
        _ = try backend.dispatch(eventJson: DemoScenario.sessionCreated(factory: &factory))
        // A running turn must exist before it can be cancelled.
        _ = try backend.dispatchBatch(eventsJson: "[" + [
            factory.event(type: "run.started", payload: [
                "protocolVersion": factory.pv,
                "run": ["id": "r1", "status": "running"],
            ]),
            factory.event(type: "message.created", payload: [
                "protocolVersion": factory.pv,
                "message": ["id": "m-agent-1", "role": "assistant", "status": "streaming"],
            ]),
        ].joined(separator: ",") + "]")
        _ = try backend.dispatchBatch(eventsJson:
            "[" + DemoScenario.cancelEvents(factory: &factory, turn: 1)
                .joined(separator: ",") + "]")
        let snap = try snapshot(of: backend)
        XCTAssertEqual(snap.runs.first?.status, .cancelled)
        XCTAssertEqual(snap.messages.last?.status, .cancelled)
        XCTAssertNil(snap.activeRunId)
    }

    // MARK: - Conformance replay (all fixtures, both decode paths)

    func testAllConformanceFixturesReplayAndMatchExpected() throws {
        let fixtures = try AIUXFixtureCatalog.loadAll(in: fixturesDir)
        XCTAssertFalse(fixtures.isEmpty, "no conformance fixtures found")

        var compared = 0
        var skipped: [String] = []
        for fixture in fixtures {
            let expectedURL = expectedDir.appendingPathComponent("\(fixture.name).json")
            guard FileManager.default.fileExists(atPath: expectedURL.path) else {
                skipped.append(fixture.name)
                continue
            }

            // Replay through the real session core. Fixtures all address
            // session "s1"; the session rejects events for another id.
            let backend = try UniFFIBackend.create(configJson: #"{"sessionId":"s1"}"#)
            _ = try backend.dispatchBatch(eventsJson: fixture.eventsJSON())

            // Both sides decode through the renderer's models — semantic,
            // not byte, equality.
            let actual = try snapshot(of: backend)
            let expectedEnvelope = try decoder.decode(
                AIUXPersistedEnvelope.self,
                from: Data(contentsOf: expectedURL)
            )
            XCTAssertEqual(
                actual, expectedEnvelope.snapshot,
                "snapshot mismatch for fixture '\(fixture.name)'"
            )
            compared += 1
        }
        XCTAssertGreaterThan(compared, 0, "no fixtures had expected files to compare")
        if !skipped.isEmpty {
            XCTFail("fixtures missing expected files: \(skipped.joined(separator: ", "))")
        }
    }

    // MARK: - Session store over UniFFI

    @MainActor
    func testSessionStorePublishesAfterUniFFIIngest() throws {
        let backend = try UniFFIBackend.create(configJson: #"{"sessionId":"demo"}"#)
        let store = AIUXSessionStore(backend: backend)
        var factory = DemoEventFactory(sessionId: DemoScenario.sessionId)
        _ = try store.ingest(eventJson: DemoScenario.sessionCreated(factory: &factory))
        XCTAssertEqual(store.snapshot.session?.title, "AIUX demo")
        XCTAssertEqual(store.snapshot.context.count, 2)
        XCTAssertNil(store.lastError)
    }
}
