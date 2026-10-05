# SwiftUI renderer — `AIUXSwiftUI`

Native SwiftUI renderer for iOS 16+ / macOS 13+. Distributed inside
`aiux-swift-package.tar.gz` (see [install](../integration/install.md#swift)).
The renderer package itself never depends on the core bindings — it talks to a
JSON backend protocol, so it can be driven by the real UniFFI `AiuxSession`, a
mock, or fixtures. Source: [`renderers/swiftui`](../../renderers/swiftui).

## The 3-piece setup

```swift
import AIUXCore
import AIUXSwiftUI

let backend = try UniFFIBackend.create(configJson: #"{"sessionId":"s1"}"#)
let store = AIUXSessionStore(backend: backend)

AIConversation(store: store)
    .onAIUXAction { action in route(action) }
```

## `AIUXSessionBackend`

The JSON boundary protocol — every input/output is a JSON string, matching
the [session contract](session-contract.md):

```swift
public protocol AIUXSessionBackend: AnyObject {
    func dispatch(eventJson: String) throws -> String
    func dispatchBatch(eventsJson: String) throws -> String
    func snapshot() throws -> String
    func serialize() throws -> String
    func reset() throws
}
```

[`UniFFIBackend`](../../examples/ios-native/Sources/AIUXExampleApp/UniFFIBackend.swift)
(~35 lines, copy it) adapts the generated `AIUXCore.AiuxSession`:
`UniFFIBackend.create(configJson:)` / `.restore(serializedJson:)`.

## `AIUXSessionStore`

`ObservableObject` owning a backend and publishing the decoded snapshot.

```swift
let store = AIUXSessionStore(backend: backend)
store.snapshot                     // AIUXSnapshot — published, current render model
try store.refresh()                // re-read backend.snapshot()
try store.ingest(eventJson: "...") // → AIUXDispatchReport
try store.ingest(eventsJson: "[…]")
try store.ingest(fixture: fx)      // dispatch a whole AIUXFixture
try store.serializedSession()      // → serialize() JSON for persistence
store.resetSession()
```

- `AIUXDispatchReport` — `Equatable & Decodable & Sendable`:
  `{applied, duplicatesIgnored, buffered}`.
- `AIUXStoreError` — `backend(String)` (backend threw) or
  `corruptSnapshot`/`corruptReport` decode failures; conforms to
  `LocalizedError` with `errorDescription`.

## `AIConversation`

```swift
public init(
    store: AIUXSessionStore,
    mode: AIUXConversationMode = .fullscreen,   // .fullscreen | .embedded
    composerPlaceholder: String = "Message…",
    showsComposer: Bool = true,
    composerToolbar: AIUXComposerToolbar = .default
)
```

Layout: top context bar, scrolling message feed, unreferenced entities, and
the floating two-row composer (input + `+`/tools/mic/action circle).

## Environment modifiers

Install on the `AIConversation` (or an ancestor):

| Modifier | Type | Purpose |
| --- | --- | --- |
| `.onAIUXAction(_:)` | `(AIUXAction) -> Void` | The semantic action sink — every control emits; the host executes. |
| `.aiuxCustomNodes(_:)` | `[String: AIUXCustomNodeRenderer]` | Registry for `custom` surface nodes (`kind` → `(AIUXSurfaceNode) -> AnyView`). Unregistered kinds render a placeholder and still render children. |
| `.aiuxRemoteURLPolicy(_:)` | `AIUXRemoteURLPolicy` | `(URL) -> Bool` gate for remote content (images, links, attachments). |
| `.environment(\.aiuxTheme, …)` | `AIUXTheme` | Theme injection — see [theming](../guides/theming.md). |

Environment-read helpers also available: `\.aiuxRenderModel`
(`AIUXRenderModel` — snapshot + `toolsByID`/`approvalsByID`/`artifactsByID`/
`surfacesByID` indexes, `streamingMessage`, `hasPendingApproval`),
`\.aiuxFormStore` (`AIUXFormStore` — form field values as
`[String: AIUXJSONValue]`), `\.aiuxAction`.

Default `aiuxRemoteURLPolicy`: allows `https`, the `aiux:` host scheme,
`data:image/…`, and relative references; refuses everything else
(`file:`, `javascript:`, non-image `data:`). Install a stricter allowlist
(e.g. CDN domains) for production.

## Composer toolbar

```swift
AIConversation(store: store, composerToolbar: AIUXComposerToolbar(
    attach: true,      // `+`  → aiux.composer.attach
    tools: false,      // accent-ringed tools toggle → aiux.composer.tools (opt-in)
    dictate: true,     // outline mic → aiux.composer.dictate
    extra: [AIUXComposerTool(id: "aiux.composer.docs",
                            accessibilityLabel: "Docs",
                            systemImage: "doc.text")]
))
```

Custom tools render in a uniform 40pt slot (SF Symbols) and emit their `id`
as the action. [Toolbar guide](../guides/composer-toolbar.md).

## Theme types

`AIUXTheme {colors, typography, spacing, radius, motion, density}` where
`colors: AIUXColorRoles` (incl. `inputSurface`, `codeSurface`,
`codeForeground`), `AIUXColor` (light/dark pair, `.resolve(in:)`),
`AIUXTypography` (Font roles), `AIUXSpacing`, `AIUXRadiusTokens`,
`AIUXMotion` (`duration`, `standard`, `animation(reduced:value:)`),
`AIUXDensity` (`.compact`/`.regular` with `factor`),
`AIUXResolvedColors`. Defaults: `AIUXTheme.light()` / `.dark()` —
see [theming](../guides/theming.md).

## Fixtures & the catalog player

```swift
let fixture = try AIUXFixture(contentsOf: url)     // or AIUXFixture(json:name:)
let names = try AIUXFixtureCatalog.manifest(in: dir)
let all = try AIUXFixtureCatalog.loadAll(in: dir)

AIFixturePlayer(directory: fixturesDir)            // picker → replays fixtures
```

`AIUXFixture` — `{name, protocolVersion?, events}`; `eventsJSON()` joins the
event array for `ingest(eventsJson:)`. Used by the example's headless gate
(`swift run AIUXExample`) and XCTest conformance replay.

## Models

`AIUXSnapshot`, `AIUXMessage`, `AIUXTool`, `AIUXApproval`, `AIUXArtifact`,
`AIUXSurfaceTree`/`AIUXSurfaceNode`, `AIUXPart`, `AIUXRun`,
`AIUXContextEntity`, `AIUXAction`, `AIUXJSONValue` — Codable wire models with
the renderer's tolerance for omitted optional fields.
