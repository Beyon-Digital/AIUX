import XCTest
@testable import AIUXSwiftUI

/// Surface-node → view resolution coverage: every §6 primitive decodes and
/// resolves. `AIUXNodeView`'s switch is exhaustively checked at compile time;
/// these tests pin the wire mapping per primitive plus the tolerant-decode
/// and unknown-node behavior (plan §21).
final class AIUXSurfaceNodeTests: XCTestCase {

    private let decoder = JSONDecoder()

    /// Every primitive's discriminant, in schema order.
    func testAllPrimitivesDecodeAndResolve() throws {
        let cases: [(json: String, kind: String)] = [
            (#"{"type":"surface","children":[]}"#, "surface"),
            (#"{"type":"card","title":"T","children":[]}"#, "card"),
            (#"{"type":"stack","direction":"vertical","children":[]}"#, "stack"),
            (#"{"type":"row","children":[]}"#, "row"),
            (#"{"type":"grid","columns":3,"children":[]}"#, "grid"),
            (#"{"type":"heading","text":"H","level":1}"#, "heading"),
            (#"{"type":"text","text":"x","variant":"caption"}"#, "text"),
            (#"{"type":"markdown","markdown":"**b**"}"#, "markdown"),
            (#"{"type":"code","code":"x=1","language":"rust"}"#, "code"),
            (#"{"type":"icon","name":"check","size":"sm"}"#, "icon"),
            (#"{"type":"image","src":"https://x/y.png","alt":"a"}"#, "image"),
            (#"{"type":"badge","text":"B","tone":"warning"}"#, "badge"),
            (#"{"type":"divider"}"#, "divider"),
            (#"{"type":"spacer","size":"lg"}"#, "spacer"),
            (#"{"type":"keyValue","items":[{"key":"K","value":"V"}]}"#, "keyValue"),
            (#"{"type":"list","ordered":true,"children":[]}"#, "list"),
            (#"{"type":"table","headers":["A"],"rows":[["1"]],"caption":"c"}"#, "table"),
            (#"{"type":"button","label":"Go","action":{"id":"a.b"},"variant":"primary"}"#, "button"),
            (#"{"type":"menu","label":"M","items":[{"label":"x","action":{"id":"a.c"}}]}"#, "menu"),
            (#"{"type":"progress","value":0.4,"max":1,"label":"L"}"#, "progress"),
            (#"{"type":"status","text":"s","tone":"success"}"#, "status"),
            (#"{"type":"input","name":"n","label":"L","inputType":"email","required":true}"#, "input"),
            (#"{"type":"textarea","name":"n","label":"L","rows":4}"#, "textarea"),
            (#"{"type":"select","name":"n","options":[{"value":"v","label":"V"}],"value":"v"}"#, "select"),
            (#"{"type":"checkbox","name":"n","label":"L","checked":true}"#, "checkbox"),
            (#"{"type":"radio","name":"n","options":[{"value":"a","label":"A"}]}"#, "radio"),
            (#"{"type":"field","label":"L","children":[{"type":"input","name":"n"}]}"#, "field"),
            (#"{"type":"form","submit":{"id":"f.submit"},"children":[]}"#, "form"),
            (#"{"type":"listItem","title":"t","action":{"id":"open"}}"#, "listItem"),
            (#"{"type":"custom","kind":"beyondigital.chart","props":{"y":1}}"#, "custom"),
            (#"{"type":"actions","children":[{"type":"button","label":"B","action":{"id":"a.d"}}]}"#, "actions"),
        ]
        XCTAssertEqual(cases.count, 31, "Surface Schema v1 defines 31 primitives (ADR 0007)")
        for (json, kind) in cases {
            let node = try decoder.decode(AIUXSurfaceNode.self, from: Data(json.utf8))
            XCTAssertEqual(node.kind, kind, "kind mismatch for \(json)")
            // Resolution: the node view accepts every primitive (compile-time
            // exhaustivity in AIUXNodeView; this guards a runtime no-op path).
            _ = AIUXNodeView(node: node)
        }
    }

    func testUnknownNodeDecodesToPlaceholder() throws {
        let node = try decoder.decode(
            AIUXSurfaceNode.self,
            from: Data(#"{"type":"holoDeck","children":[]}"#.utf8)
        )
        guard case .unknown(let type) = node else {
            return XCTFail("expected .unknown, got \(node)")
        }
        XCTAssertEqual(type, "holoDeck")
        XCTAssertTrue(node.children.isEmpty)
        _ = AIUXNodeView(node: node)
    }

    func testBadLayoutTokensDegradeToDefaults() throws {
        let node = try decoder.decode(
            AIUXSurfaceNode.self,
            from: Data(#"{"type":"stack","gap":"13px","padding":"huge","children":[]}"#.utf8)
        )
        guard case .stack(_, _, let layout) = node else {
            return XCTFail("expected .stack, got \(node)")
        }
        XCTAssertNil(layout.gap)
        XCTAssertNil(layout.padding)
    }

    func testNestedChildrenDecode() throws {
        let json = """
        {"type":"surface","gap":"sm","children":[
          {"type":"heading","text":"Invoice summary","level":1},
          {"type":"stack","direction":"vertical","gap":"sm","children":[
            {"type":"keyValue","items":[{"key":"Total","value":"$420.00"}]},
            {"type":"badge","text":"Due soon","tone":"warning"}
          ]},
          {"type":"actions","children":[
            {"type":"button","label":"Approve","variant":"primary",
             "action":{"id":"invoice.approve","payload":{"id":"inv-9"}}}
          ]}
        ]}
        """
        let node = try decoder.decode(AIUXSurfaceNode.self, from: Data(json.utf8))
        XCTAssertEqual(node.children.count, 3)
        guard case .actions(let actions, _) = node.children[2] else {
            return XCTFail("expected actions node")
        }
        guard case .button(_, let action, _, _, _) = actions[0] else {
            return XCTFail("expected button node")
        }
        XCTAssertEqual(action.id, "invoice.approve")
        XCTAssertEqual(action.payload["id"], .string("inv-9"))
    }

    func testSurfaceTreeDecodes() throws {
        let json = """
        {"id":"sf-1","name":"invoice-card","revision":3,
         "root":{"type":"surface","children":[{"type":"text","text":"hi"}]}}
        """
        let tree = try decoder.decode(AIUXSurfaceTree.self, from: Data(json.utf8))
        XCTAssertEqual(tree.id, "sf-1")
        XCTAssertEqual(tree.revision, 3)
        XCTAssertEqual(tree.root.children.count, 1)
        _ = AISurface(tree: tree)
    }
}
