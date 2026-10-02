import 'package:flutter/material.dart';

import '../session.dart';
import '../surface_node.dart';
import '../theme.dart';
import 'conversation.dart';

// MARK: - Fixture player
//
// `AIFixturePlayer` replays one conformance fixture through a caller-supplied
// backend and renders the resulting snapshot — the same JSON the Rust
// conformance runner verifies. Host apps build galleries over it; the
// example app uses it for its catalog view.

/// Replays a fixture's events through a backend and renders the snapshot.
class AIFixturePlayer extends StatefulWidget {
  const AIFixturePlayer({
    super.key,
    required this.fixture,
    required this.backend,
    this.mode = AiuxConversationMode.embedded,
  });

  /// The fixture being played.
  final AiuxFixture fixture;

  /// Factory producing a fresh session backend (so every fixture gets an
  /// empty session).
  final AiuxSessionBackend Function() backend;

  /// Presentation mode for the rendered conversation.
  final AiuxConversationMode mode;

  @override
  State<AIFixturePlayer> createState() => _AIFixturePlayerState();
}

class _AIFixturePlayerState extends State<AIFixturePlayer> {
  late final AiuxSessionBackend _backend;
  late final AiuxSessionStore _store;
  String? _replayError;

  @override
  void initState() {
    super.initState();
    _backend = widget.backend();
    _store = AiuxSessionStore(backend: _backend);
    WidgetsBinding.instance.addPostFrameCallback((_) => _replay());
  }

  @override
  void dispose() {
    _store.dispose();
    // The player owns the backend it built — an FFI backend holds a native
    // session that only its finalizer would otherwise release.
    if (_backend is AiuxFfiBackend) {
      _backend.close();
    }
    super.dispose();
  }

  void _replay() {
    try {
      _store.ingestFixture(widget.fixture);
    } catch (e) {
      setState(() => _replayError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    return Stack(
      children: [
        AIConversation(store: _store, mode: widget.mode),
        if (_replayError != null)
          Positioned(
            top: theme.space(AiuxGap.sm),
            left: theme.space(AiuxGap.md),
            right: theme.space(AiuxGap.md),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: theme.space(AiuxGap.sm),
                  vertical: theme.space(AiuxGap.xs)),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(theme.radius.full),
              ),
              child: Text(_replayError!,
                  style: theme.typography.caption
                      .copyWith(color: colors.destructive)),
            ),
          ),
      ],
    );
  }
}
