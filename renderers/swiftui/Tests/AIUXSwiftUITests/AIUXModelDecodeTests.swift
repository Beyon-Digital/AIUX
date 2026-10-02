import XCTest
@testable import AIUXSwiftUI

/// Snapshot/persisted/part decode coverage — the mapping the views consume.
final class AIUXModelDecodeTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: Snapshot

    func testSnapshotDecodesEntityLists() throws {
        let json = """
        {
          "protocolVersion": "0.1",
          "sessionId": "s-1",
          "session": {"id": "s-1", "title": "Demo"},
          "messages": [
            {"id": "m-1", "role": "user",
             "parts": [{"type": "text", "id": "p-1", "text": "hi"}]},
            {"id": "m-2", "role": "assistant", "status": "streaming",
             "parts": []}
          ],
          "tools": [{"id": "t-1", "name": "search", "status": "running"}],
          "approvals": [{"id": "a-1", "prompt": "Run it?", "status": "requested"}],
          "artifacts": [{"id": "ar-1", "kind": "code", "revision": 2}],
          "surfaces": [{"id": "sf-1", "revision": 0,
            "root": {"type": "surface", "children": []}}],
          "context": [{"id": "c-1", "kind": "file", "label": "main.swift"}],
          "runs": [{"id": "r-1", "status": "running"}],
          "activeRunId": "r-1"
        }
        """
        let snapshot = try decoder.decode(AIUXSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(snapshot.sessionId, "s-1")
        XCTAssertEqual(snapshot.session?.title, "Demo")
        XCTAssertEqual(snapshot.messages.count, 2)
        XCTAssertEqual(snapshot.messages[1].status, .streaming)
        XCTAssertEqual(snapshot.tools.count, 1)
        XCTAssertEqual(snapshot.approvals[0].status, .requested)
        XCTAssertEqual(snapshot.artifacts[0].revision, 2)
        XCTAssertEqual(snapshot.surfaces[0].id, "sf-1")
        XCTAssertEqual(snapshot.context[0].kind, "file")
        XCTAssertEqual(snapshot.activeRunId, "r-1")
    }

    func testEmptySnapshotDecodesWithDefaults() throws {
        let snapshot = try decoder.decode(AIUXSnapshot.self, from: Data("{}".utf8))
        XCTAssertTrue(snapshot.messages.isEmpty)
        XCTAssertTrue(snapshot.surfaces.isEmpty)
        XCTAssertNil(snapshot.activeRunId)
    }

    // MARK: Persisted envelope (conformance/expected + serialize() shape)

    func testPersistedEnvelopeMapsStateToSnapshot() throws {
        let json = """
        {
          "protocolVersion": "0.1",
          "sessionId": "s-9",
          "state": {
            "messages": [{"id": "m-1", "role": "assistant",
              "parts": [{"type": "text", "id": "p-1", "text": "done"}]}],
            "runs": [{"id": "r-1", "status": "completed"}]
          },
          "nextExpectedSequence": 5,
          "seenEventIds": ["e-1"],
          "bufferedEvents": []
        }
        """
        let envelope = try decoder.decode(AIUXPersistedEnvelope.self, from: Data(json.utf8))
        let snapshot = envelope.snapshot
        XCTAssertEqual(snapshot.sessionId, "s-9")
        XCTAssertEqual(snapshot.messages.count, 1)
        XCTAssertEqual(snapshot.runs.first?.status, .completed)
    }

    // MARK: Parts — every protocol kind

    func testAllPartKindsDecode() throws {
        let kinds: [(json: String, kind: String)] = [
            (#"{"type":"text","id":"p","text":"t"}"#, "text"),
            (#"{"type":"markdown","id":"p","markdown":"**m**"}"#, "markdown"),
            (#"{"type":"code","id":"p","code":"x=1","language":"swift"}"#, "code"),
            (#"{"type":"image","id":"p","attachment":{"uri":"https://x/y.png"}}"#, "image"),
            (#"{"type":"attachment","id":"p","attachment":{"name":"a.pdf"}}"#, "attachment"),
            (#"{"type":"citation","id":"p","citation":{"title":"Doc","uri":"https://x"}}"#, "citation"),
            (#"{"type":"tool","id":"p","toolId":"t-1"}"#, "tool"),
            (#"{"type":"approval","id":"p","approvalId":"a-1"}"#, "approval"),
            (#"{"type":"artifact","id":"p","artifactId":"ar-1"}"#, "artifact"),
            (#"{"type":"status","id":"p","text":"Working","level":"info"}"#, "status"),
            (#"{"type":"progress","id":"p","progress":{"current":1,"total":4}}"#, "progress"),
            (#"{"type":"surface","id":"p","surfaceId":"sf-1"}"#, "surface"),
            (#"{"type":"error","id":"p","error":{"code":"E","message":"boom"}}"#, "error"),
        ]
        for (json, kind) in kinds {
            let part = try decoder.decode(AIUXPart.self, from: Data(json.utf8))
            XCTAssertEqual(part.kind, kind, "expected kind \(kind) for \(json)")
            XCTAssertFalse(part.id.isEmpty)
        }
    }

    func testUnknownPartDecodesToPlaceholder() throws {
        let part = try decoder.decode(
            AIUXPart.self,
            from: Data(#"{"type":"holoDeck","id":"p-9"}"#.utf8)
        )
        guard case .unknown(let id, let type) = part else {
            return XCTFail("expected .unknown, got \(part)")
        }
        XCTAssertEqual(id, "p-9")
        XCTAssertEqual(type, "holoDeck")
    }

    func testMissingPartIdGetsStableFallback() throws {
        let json = #"{"type":"text","text":"x"}"#
        let part = try decoder.decode(AIUXPart.self, from: Data(json.utf8))
        XCTAssertFalse(part.id.isEmpty)
        XCTAssertEqual(part.id, part.id, "id must be stable within the decoded instance")
    }

    func testPartRoundTrip() throws {
        let json = #"{"type":"status","id":"p-1","text":"ok","level":"warning"}"#
        let part = try decoder.decode(AIUXPart.self, from: Data(json.utf8))
        let data = try JSONEncoder().encode(part)
        let again = try decoder.decode(AIUXPart.self, from: data)
        XCTAssertEqual(part, again)
    }

    // MARK: Entities

    func testProgressFraction() {
        var p = AIUXProgress()
        XCTAssertNil(p.fraction)
        p.current = 5; p.total = 10
        XCTAssertEqual(p.fraction, 0.5)
        p.current = 99
        XCTAssertEqual(p.fraction, 1.0, "fraction clamps to 1")
    }

    func testJSONValueRoundTrip() throws {
        let json = #"{"a":1,"b":[true,"x"],"c":{"d":null}}"#
        let v = try decoder.decode(AIUXJSONValue.self, from: Data(json.utf8))
        XCTAssertEqual(v["a"], .int(1))
        XCTAssertEqual(v["b"], .array([.bool(true), .string("x")]))
        XCTAssertEqual(v["c"]?["d"], .null)
        let re = try decoder.decode(AIUXJSONValue.self, from: try JSONEncoder().encode(v))
        XCTAssertEqual(v, re)
    }

    func testJSONValuePreservesLargeIntegers() throws {
        // Beyond Double's 2^53 bound this collapses to 9007199254740992 —
        // integral wire values must stay exact through decode AND re-encode.
        let big: Int64 = 9_007_199_254_740_993
        let v = try decoder.decode(
            AIUXJSONValue.self,
            from: Data(#"{"n":9007199254740993}"#.utf8)
        )
        XCTAssertEqual(v["n"], .int(big))
        XCTAssertEqual(v["n"]?.intValue, big)
        XCTAssertEqual(v["n"]?.numberValue, Double(big))

        let reencoded = try JSONEncoder().encode(v)
        XCTAssertEqual(String(data: reencoded, encoding: .utf8), #"{"n":9007199254740993}"#)
        let re = try decoder.decode(AIUXJSONValue.self, from: reencoded)
        XCTAssertEqual(re["n"], .int(big))
    }

    func testJSONValuePreservesUnsignedIntegers() throws {
        // Above Int64.max the value only fits u64 — falling back to Double
        // would round 18446744073709551615 to 18446744073709552000.
        let big: UInt64 = 18_446_744_073_709_551_615
        let v = try decoder.decode(
            AIUXJSONValue.self,
            from: Data(#"{"n":18446744073709551615}"#.utf8)
        )
        XCTAssertEqual(v["n"], .uint(big))
        XCTAssertEqual(v["n"]?.uintValue, big)
        XCTAssertNil(v["n"]?.intValue)

        let reencoded = try JSONEncoder().encode(v)
        XCTAssertEqual(String(data: reencoded, encoding: .utf8), #"{"n":18446744073709551615}"#)
        let re = try decoder.decode(AIUXJSONValue.self, from: reencoded)
        XCTAssertEqual(re["n"], .uint(big))
    }

    func testJSONValueFractionalStaysDouble() throws {
        let v = try decoder.decode(
            AIUXJSONValue.self,
            from: Data(#"{"n":1.5,"neg":-0.25}"#.utf8)
        )
        XCTAssertEqual(v["n"], .number(1.5))
        XCTAssertEqual(v["neg"], .number(-0.25))
        XCTAssertNil(v["n"]?.intValue)
    }

    // MARK: Tool payload display (aiuxJSONDescription)

    func testJSONDescriptionRendersScalars() {
        // Scalars can't go through JSONSerialization — a bare `true`, `42`,
        // or `null` tool result must not render as nothing.
        XCTAssertEqual(aiuxJSONDescription(.bool(true)), "true")
        XCTAssertEqual(aiuxJSONDescription(.null), "null")
        XCTAssertEqual(aiuxJSONDescription(.int(42)), "42")
        XCTAssertEqual(aiuxJSONDescription(.int(-7)), "-7")
        XCTAssertEqual(aiuxJSONDescription(.number(2.5)), "2.5")
        XCTAssertEqual(aiuxJSONDescription(.number(3.0)), "3")
        XCTAssertEqual(aiuxJSONDescription(.string("done")), "done")
        XCTAssertNotNil(aiuxJSONDescription(.object(["ok": .bool(true)])))
        XCTAssertNotNil(aiuxJSONDescription(.array([.int(1), .int(2)])))
    }

    func testActionDecode() throws {
        let json = #"{"id":"invoice.approve","payload":{"invoiceId":"293"}}"#
        let action = try decoder.decode(AIUXAction.self, from: Data(json.utf8))
        XCTAssertEqual(action.id, "invoice.approve")
        XCTAssertEqual(action.payload["invoiceId"], .string("293"))
    }

    // MARK: Theme

    func testThemeDensityScalesSpacing() {
        var theme = AIUXTheme.default
        theme.density = .compact
        XCTAssertEqual(theme.space(.md), theme.spacing.md * 0.8, accuracy: 0.001)
        theme.density = .spacious
        XCTAssertEqual(theme.space(.md), theme.spacing.md * 1.25, accuracy: 0.001)
    }

    func testRadiusTokens() {
        let theme = AIUXTheme.default
        XCTAssertEqual(theme.radius.radius(.full), theme.radius.full)
        XCTAssertEqual(theme.radius.radius(nil), 0)
    }
}
