import Foundation
import XCTest
@testable import AIUXCore

/// Phase 2 gate (plan §16): create session → dispatch fixture → snapshot →
/// serialize → restore. Runs on the macOS `swift-bindings` CI job — no Swift
/// toolchain on the Linux dev box.
final class AiuxSessionTests: XCTestCase {

    private func jsonObject(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
    }

    /// conformance/fixtures/basic-response.json, relative to this source file.
    private func fixtureEventsJson() throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // AIUXCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // swift
            .deletingLastPathComponent() // bindings
            .deletingLastPathComponent() // repo root
        let url = repoRoot.appendingPathComponent("conformance/fixtures/basic-response.json")
        let fixture = try jsonObject(try String(contentsOf: url, encoding: .utf8))
        let events = try XCTUnwrap(fixture["events"] as? [[String: Any]])
        let eventsData = try JSONSerialization.data(withJSONObject: events)
        return try XCTUnwrap(String(data: eventsData, encoding: .utf8))
    }

    func testCreateDispatchSnapshotSerializeRestore() throws {
        let session = try AiuxSession.create(configJson: #"{"sessionId":"s1"}"#)

        let report = try jsonObject(try session.dispatchBatch(eventsJson: fixtureEventsJson()))
        XCTAssertEqual(report["applied"] as? Int, 7)

        let snapshot = try session.snapshot()
        XCTAssertEqual(try jsonObject(snapshot)["sessionId"] as? String, "s1")

        let serialized = try session.serialize()
        let restored = try AiuxSession.restore(serializedJson: serialized)

        // Restored session reduces to the exact same canonical snapshot.
        XCTAssertEqual(try restored.snapshot(), snapshot)
        XCTAssertEqual(try restored.serialize(), serialized)

        session.reset()
        let messages = try XCTUnwrap(
            try jsonObject(session.snapshot())["messages"] as? [Any]
        )
        XCTAssertTrue(messages.isEmpty)
    }
}
