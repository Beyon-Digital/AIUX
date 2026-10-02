# SwiftUI Integration

`AIUXSwiftUI` (renderers/swiftui) + `AIUXCore` (bindings/swift, UniFFI →
XCFramework). The SwiftUI package itself is toolchain-free: it talks to any
`AIUXSessionBackend`; the host adapts the UniFFI `AiuxSession` to that
protocol once.

## Install

- SwiftPM: add the `AIUXSwiftUI` package and link `AIUXCore.xcframework`
  (built by `bindings/swift/package-xcframework.sh`, or the release asset).
- CocoaPods: the XCFramework ships per-slice `libaiux_uniffi.a` so podspec
  vendored-libraries work — same artifact.
- Generate bindings locally (macOS): `bash bindings/swift/generate.sh`
  (writes `Sources/AIUXCore{,FFI}`; gitignored — regenerate per version).

## Wire the backend

```swift
import AIUXCore     // generated UniFFI binding
import AIUXSwiftUI

struct UniFFIBackend: AIUXSessionBackend {
    let inner: AiuxSession          // the frozen JSON facade
    func snapshotJson() throws -> String { try inner.snapshot() }
    func dispatchJson(_ batch: String) throws -> String {
        try inner.dispatchBatch(eventsJson: batch)   // DispatchReport JSON
    }
    // create/restore/serialize/reset pass straight through
}
```

## Render

```swift
let store = AIUXSessionStore(backend: UniFFIBackend(inner: session))

AIConversation(store: store, mode: .fullscreen)   // or .embedded
    .onAIUXAction { action in
        // action.id + action.payload → YOUR policy; views never execute
    }
    .aiuxTheme(myTheme)                            // §7 contract
```

- `AIConversation` renders the whole surface: context bar, message stream
  (all 13 part kinds), tools, approvals (5-state), artifacts, `AISurface`
  trees, composer.
- `AIFixturePlayer(fixture:backend:mode:)` replays any conformance fixture —
  the example app's gallery is built on it; reuse it for your own previews
  and snapshot tests.
- Feeding events: `try store.ingest(fixture:)` or dispatch event JSON via
  the backend then `store.refresh()` — the store publishes decoded
  `AIUXRenderModel` snapshots; views observe, they don't poll.

## Rules

- One `AIUXSessionStore` per conversation; create fresh backends per fixture
  (the player does this for you).
- Actions are `AIUXAction {id, payload}` — route to your handlers; the
  library executes nothing (§23).
- Theme via `AIUXTheme` (light/dark pairs per color role); `.aiuxTheme` is
  the single entry point (see `docs/renderers/theme-contract.md`).
- Minimum targets: iOS 16 / macOS 13 (see compatibility matrix).
