/// beyond_aiux — the Flutter renderer for AIUX (docs/PLAN.md §13).
///
/// Architecture (mirrors renderers/swiftui):
///   - `AiuxSessionBackend` — the JSON boundary to the session core.
///     [AiuxFfiBackend] conforms `aiux_ffi.AiuxSession` (the Phase 7
///     Dart-FFI path); tests may drive a store with any conforming backend.
///   - `AiuxSessionStore` — the [ChangeNotifier] owning a backend; ingests
///     events and publishes decoded snapshots as `AiuxRenderModel`.
///   - `AIConversation` — the root view (fullscreen / embedded, §14).
///   - `AIMessage`/`AIPartView` — all 13 protocol part kinds.
///   - `AIToolStatus`, `AIApproval`, `AIArtifactPreview`, `AISurface` (all 26
///     §6 primitives), `AIContextBar`, `AIComposer`.
///   - `AiuxThemeData` — the §7 role contract; every visual resolves through
///     it. Light and dark palettes both work from day one.
///
/// Actions flow up via `AiuxScope`; views never execute (§23). No platform
/// views embedding SwiftUI/Compose anywhere in the default path.
library;

export 'src/helpers.dart' show AiuxMarkdownText, AIUXUnsupported;
export 'src/icons.dart';
export 'src/models.dart';
export 'src/scope.dart';
export 'src/session.dart';
export 'src/surface_node.dart';
export 'src/theme.dart';
export 'src/widgets/approval_view.dart';
export 'src/widgets/artifact_view.dart';
export 'src/widgets/composer.dart';
export 'src/widgets/context_bar.dart';
export 'src/widgets/conversation.dart';
export 'src/widgets/fixture_player.dart';
export 'src/widgets/message_view.dart'
    show AIMessage, AIPartView, AiuxStreamingDots;
export 'src/widgets/surface_view.dart';
export 'src/widgets/tool_status_view.dart';

/// The protocol version this renderer targets.
const aiuxProtocolVersion = '0.1';
