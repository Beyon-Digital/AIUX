import SwiftUI

// MARK: - AIUXSwiftUI
//
// The SwiftUI renderer for AIUX (docs/PLAN.md §8, ADR 0002).
//
// Architecture:
//   - `AIUXSessionBackend` — the JSON boundary to the session core. The
//     UniFFI `AiuxSession` binding (bindings/swift) conforms via a thin
//     adapter in the host app; this package stays toolchain-free.
//   - `AIUXSessionStore` — the `ObservableObject` owning a backend; ingests
//     events and publishes decoded snapshots as `AIUXRenderModel`.
//   - `AIConversation` — the root view (fullscreen / embedded, §14).
//   - `AIMessage`/`AIPartView` — all 13 protocol part kinds.
//   - `AIToolStatus`, `AIApproval`, `AIArtifactPreview`, `AISurface` (all 26
//     §6 primitives), `AIContextBar`, `AIComposer`.
//   - `AIUXTheme` — the §7 role contract; every visual resolves through it.
//
// Actions flow up via `.onAIUXAction(_:)`; views never execute (§23).

/// Package marker + protocol version the renderer was built against.
public enum AIUXSwiftUI {
    /// The protocol version this renderer targets.
    public static let protocolVersion = "0.1"
}

// MARK: - Fixture player
//
// `AIFixturePlayer` replays one conformance fixture through a caller-supplied
// backend and renders the resulting snapshot — the same JSON the Rust
// conformance runner verifies. Host apps build galleries over it; the iOS
// example uses it for its catalog view.

/// Replays a fixture's events through a backend and renders the snapshot.
public struct AIFixturePlayer: View {
    @StateObject private var store: AIUXSessionStore
    @State private var replayError: String?

    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    /// The fixture being played.
    public let fixture: AIUXFixture
    /// Presentation mode for the rendered conversation.
    public var mode: AIUXConversationMode

    /// - Parameters:
    ///   - fixture: the conformance fixture to replay.
    ///   - backend: factory producing a fresh session backend (so every
    ///     fixture gets an empty session).
    ///   - mode: `.fullscreen` or `.embedded` rendering.
    public init(
        fixture: AIUXFixture,
        backend: @escaping () -> AIUXSessionBackend,
        mode: AIUXConversationMode = .embedded
    ) {
        self.fixture = fixture
        self.mode = mode
        _store = StateObject(wrappedValue: AIUXSessionStore(backend: backend()))
    }

    public var body: some View {
        AIConversation(store: store, mode: mode)
            .task {
                do {
                    _ = try store.ingest(fixture: fixture)
                } catch {
                    replayError = String(describing: error)
                }
            }
            .overlay(alignment: .top) {
                if let replayError {
                    let colors = theme.colors(for: colorScheme)
                    Text(replayError)
                        .font(theme.typography.caption)
                        .foregroundStyle(colors.destructive)
                        .padding(.horizontal, theme.space(.sm))
                        .padding(.vertical, theme.space(.xs))
                        .background(colors.surfaceElevated)
                        .clipShape(Capsule())
                        .padding(theme.space(.sm))
                }
            }
    }
}
