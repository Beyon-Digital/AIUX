import XCTest
@testable import AIUXSwiftUI

/// Store tests drive `AIUXSessionStore` through a fake `AIUXSessionBackend`
/// (same JSON-string boundary as UniFFI `AiuxSession`) so the mapping from
/// dispatch → snapshot → render model is covered without the Rust toolchain.
final class AIUXSessionStoreTests: XCTestCase {

    /// Records calls and returns canned JSON — the test's substitute engine.
    final class FakeBackend: AIUXSessionBackend {
        var snapshotJson: String = #"{"sessionId":"fake","messages":[]}"#
        var dispatchCalls: [String] = []
        var batchCalls: [String] = []
        var nextReport: String = #"{"applied":1,"duplicatesIgnored":0,"buffered":0}"#
        var failure: Error?

        func dispatch(eventJson: String) throws -> String {
            if let failure { throw failure }
            dispatchCalls.append(eventJson)
            return nextReport
        }
        func dispatchBatch(eventsJson: String) throws -> String {
            if let failure { throw failure }
            batchCalls.append(eventsJson)
            return nextReport
        }
        func snapshot() throws -> String { snapshotJson }
        func serialize() throws -> String { #"{"protocolVersion":"0.1","sessionId":"fake","state":{}}"# }
        func reset() throws { snapshotJson = #"{"sessionId":"fake","messages":[]}"# }
    }

    enum FakeError: Error { case boom }

    @MainActor
    func testIngestPublishesDecodedSnapshot() throws {
        let backend = FakeBackend()
        backend.snapshotJson = """
        {"sessionId":"s-1","messages":[
          {"id":"m-1","role":"assistant",
           "parts":[{"type":"text","id":"p","text":"hello"}]}
        ]}
        """
        let store = AIUXSessionStore(backend: backend)
        let report = try store.ingest(eventJson: #"{"type":"text.delta"}"#)
        XCTAssertEqual(report.applied, 1)
        XCTAssertEqual(backend.dispatchCalls.count, 1)
        XCTAssertEqual(store.snapshot.messages.count, 1)
        XCTAssertEqual(store.snapshot.messages[0].role, .assistant)
        XCTAssertNil(store.lastError)
    }

    @MainActor
    func testBatchIngestCallsDispatchBatch() throws {
        let backend = FakeBackend()
        let store = AIUXSessionStore(backend: backend)
        _ = try store.ingest(eventsJson: #"[{"a":1},{"b":2}]"#)
        XCTAssertEqual(backend.batchCalls.count, 1)
        XCTAssertEqual(backend.batchCalls[0], #"[{"a":1},{"b":2}]"#)
    }

    @MainActor
    func testRenderModelIndexesEntities() {
        let backend = FakeBackend()
        backend.snapshotJson = """
        {"sessionId":"s-1",
         "tools":[{"id":"t-1","name":"search","status":"completed"}],
         "approvals":[{"id":"a-1","prompt":"ok?","status":"rejected"}],
         "artifacts":[{"id":"ar-1","kind":"code"}],
         "surfaces":[{"id":"sf-1","root":{"type":"surface","children":[]}}]}
        """
        let store = AIUXSessionStore(backend: backend)
        XCTAssertEqual(store.renderModel.tool("t-1")?.name, "search")
        XCTAssertEqual(store.renderModel.approval("a-1")?.status, .rejected)
        XCTAssertEqual(store.renderModel.artifact("ar-1")?.kind, "code")
        XCTAssertEqual(store.renderModel.surface("sf-1")?.id, "sf-1")
        XCTAssertNil(store.renderModel.tool("missing"))
    }

    @MainActor
    func testBackendFailureSetsLastError() {
        let backend = FakeBackend()
        backend.failure = FakeError.boom
        let store = AIUXSessionStore(backend: backend)
        XCTAssertThrowsError(try store.ingest(eventJson: "{}"))
        guard case .backend = store.lastError else {
            return XCTFail("expected .backend error, got \(String(describing: store.lastError))")
        }
    }

    @MainActor
    func testCorruptSnapshotSetsLastError() {
        let backend = FakeBackend()
        backend.snapshotJson = "not json"
        let store = AIUXSessionStore(backend: backend)
        guard case .corruptSnapshot = store.lastError else {
            return XCTFail("expected .corruptSnapshot, got \(String(describing: store.lastError))")
        }
    }

    @MainActor
    func testResetClearsSession() throws {
        let backend = FakeBackend()
        backend.snapshotJson = #"{"sessionId":"s-1","messages":[{"id":"m","role":"user","parts":[]}]}"#
        let store = AIUXSessionStore(backend: backend)
        XCTAssertEqual(store.snapshot.messages.count, 1)
        store.resetSession()
        XCTAssertTrue(store.snapshot.messages.isEmpty)
    }

    // MARK: Fixture decoding

    func testFixtureParsesEventArray() throws {
        let json = """
        {"name":"demo","protocolVersion":"0.1","events":[
          {"eventId":"e-1","sessionId":"s","sequence":0,"timestamp":"t",
           "type":"session.created","protocolVersion":"0.1","payload":{}},
          {"eventId":"e-2","sessionId":"s","sequence":1,"timestamp":"t",
           "type":"run.started","protocolVersion":"0.1","payload":{}}
        ]}
        """
        let fixture = try AIUXFixture(json: json)
        XCTAssertEqual(fixture.name, "demo")
        XCTAssertEqual(fixture.events.count, 2)
        // eventsJSON re-serializes as a dispatchBatch-compatible array.
        let events = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(fixture.eventsJSON().utf8)) as? [Any]
        )
        XCTAssertEqual(events.count, 2)
    }

    func testFixtureRejectsNonFixtureJSON() {
        XCTAssertThrowsError(try AIUXFixture(json: #"{"no":"events"}"#)) { error in
            XCTAssertEqual(error as? AIUXFixtureError, .missingEvents)
        }
    }

    // MARK: Canonical action ids

    func testCanonicalActionIdsAreNamespaced() {
        let ids = [
            AIUXAction.composerSend, AIUXAction.composerCancel,
            AIUXAction.composerAttach, AIUXAction.approvalResolve,
            AIUXAction.errorRetry, AIUXAction.citationOpen,
            AIUXAction.attachmentOpen, AIUXAction.contextRemove,
            AIUXAction.contextAdd, AIUXAction.fieldChange,
            AIUXAction.artifactOpen,
        ]
        for id in ids {
            XCTAssertTrue(id.hasPrefix("aiux."), "\(id) must be aiux-namespaced")
        }
    }
}
