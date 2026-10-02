import 'package:flutter/material.dart';

import '../models.dart';
import '../scope.dart';
import '../session.dart';
import '../surface_node.dart';
import '../theme.dart';
import 'composer.dart';
import 'context_bar.dart';
import 'message_view.dart';

// MARK: - Conversation (PLAN §8, §14)
//
// `AIConversation` is the root renderer view: a scrollable stream of
// messages and their parts, auto-scrolling with streaming output. Two
// presentation modes (§14):
//   - fullscreen — takes over the surface: context bar, message stream,
//     composer pinned at the bottom.
//   - embedded   — just the message stream for embedding in host chrome
//                  (the host may place its own `AIComposer`).
//
// The view is driven by an `AiuxSessionStore` and emits actions via the
// `AiuxScope` — it holds no business logic.

/// Presentation mode for `AIConversation` (§14).
enum AiuxConversationMode {
  /// Owns the whole surface: context bar + stream + composer.
  fullscreen,

  /// Stream only, for embedding inside host layout.
  embedded,
}

/// The AIUX conversation surface.
class AIConversation extends StatefulWidget {
  const AIConversation({
    super.key,
    required this.store,
    this.mode = AiuxConversationMode.fullscreen,
    this.composerPlaceholder = 'Message…',
  });

  final AiuxSessionStore store;
  final AiuxConversationMode mode;

  /// Optional override for the composer's placeholder text.
  final String composerPlaceholder;

  @override
  State<AIConversation> createState() => _AIConversationState();
}

class _AIConversationState extends State<AIConversation> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToBottom(animated: false));
  }

  @override
  void didUpdateWidget(AIConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.store, widget.store)) {
      oldWidget.store.removeListener(_onStore);
      widget.store.addListener(_onStore);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    _scroll.dispose();
    super.dispose();
  }

  void _onStore() => _scrollToBottom(animated: true);

  void _scrollToBottom({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      final reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (animated && !reduceMotion) {
        _scroll.animateTo(target,
            duration: AiuxTheme.of(context).motionDuration,
            curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final emit = AiuxScope.emitterOf(context);

    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final model = widget.store.renderModel;
        final snapshot = model.snapshot;
        return AiuxScope(
          model: model,
          emit: emit,
          child: Container(
            color: colors.background,
            child: Column(
              children: [
                if (widget.mode == AiuxConversationMode.fullscreen &&
                    snapshot.context.isNotEmpty)
                  AIContextBar(entities: snapshot.context),
                Expanded(child: _stream(theme, colors, snapshot)),
                if (widget.mode == AiuxConversationMode.fullscreen)
                  AIComposer(
                    runActive: snapshot.activeRunId != null,
                    placeholder: widget.composerPlaceholder,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stream(
      AiuxThemeData theme, AiuxColors colors, AiuxSnapshot snapshot) {
    final messages = snapshot.messages;
    if (messages.isEmpty) return _emptyState(theme, colors, snapshot);
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.symmetric(
          horizontal: theme.space(AiuxGap.md),
          vertical: theme.space(AiuxGap.sm)),
      itemCount: messages.length,
      itemBuilder: (context, i) => Padding(
        padding: EdgeInsets.only(bottom: theme.space(AiuxGap.md)),
        child: AIMessage(key: ValueKey(messages[i].id), message: messages[i]),
      ),
    );
  }

  Widget _emptyState(
      AiuxThemeData theme, AiuxColors colors, AiuxSnapshot snapshot) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.space(AiuxGap.xl)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 32, color: colors.accent),
            SizedBox(height: theme.space(AiuxGap.sm)),
            Text(snapshot.session?.title ?? 'How can I help?',
                style: theme.typography.heading, textAlign: TextAlign.center),
            Text('Send a message to start the conversation.',
                style: theme.typography.caption.copyWith(color: colors.muted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
