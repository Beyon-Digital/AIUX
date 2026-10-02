import 'package:flutter/material.dart';

import '../models.dart';
import '../scope.dart';
import '../surface_node.dart';
import '../theme.dart';

// MARK: - Composer (PLAN §8)
//
// `AIComposer` is the text-entry bar: send / cancel / attach. It never acts
// itself — send emits `aiux.composer.send` with `{text}`, cancel emits
// `aiux.composer.cancel`, attach emits `aiux.composer.attach` (the host owns
// the picker). Cancel is only enabled while a run is active.

/// The message composer bar.
class AIComposer extends StatefulWidget {
  const AIComposer({
    super.key,
    this.runActive = false,
    this.placeholder = 'Message…',
  });

  /// Whether a run is active (cancel enabled, send of a new prompt still
  /// allowed — hosts decide queueing policy).
  final bool runActive;

  /// Placeholder text.
  final String placeholder;

  @override
  State<AIComposer> createState() => _AIComposerState();
}

class _AIComposerState extends State<AIComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend => _controller.text.trim().isNotEmpty;

  void _send() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    AiuxScope.emitAction(context,
        AiuxAction(id: AiuxAction.composerSend, payload: {'text': trimmed}));
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    return Container(
      color: colors.background,
      padding: EdgeInsets.symmetric(
          horizontal: theme.space(AiuxGap.md),
          vertical: theme.space(AiuxGap.sm)),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Semantics(
              label: 'Attach',
              button: true,
              child: IconButton(
                onPressed: () => AiuxScope.emitAction(
                    context, const AiuxAction(id: AiuxAction.composerAttach)),
                icon: Icon(Icons.attach_file, color: colors.muted),
                visualDensity: VisualDensity.compact,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                style: theme.typography.body,
                onChanged: (_) => setState(() {}),
                // Multiline field: Enter inserts a newline; sending goes
                // through the arrow button.
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  hintStyle:
                      theme.typography.body.copyWith(color: colors.muted),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: theme.space(AiuxGap.sm),
                      vertical: theme.space(AiuxGap.xs)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                        theme.radius.radius(AiuxRadius.lg)),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                        theme.radius.radius(AiuxRadius.lg)),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
            ),
            SizedBox(width: theme.space(AiuxGap.sm)),
            if (widget.runActive)
              Semantics(
                label: 'Cancel run',
                button: true,
                child: IconButton(
                  onPressed: () => AiuxScope.emitAction(
                      context, const AiuxAction(id: AiuxAction.composerCancel)),
                  icon: Icon(Icons.stop_circle,
                      color: colors.destructive, size: 28),
                  visualDensity: VisualDensity.compact,
                ),
              )
            else
              Semantics(
                label: 'Send',
                button: true,
                child: IconButton(
                  onPressed: _canSend ? _send : null,
                  icon: Icon(Icons.arrow_circle_up,
                      color: _canSend ? colors.accent : colors.muted, size: 28),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
