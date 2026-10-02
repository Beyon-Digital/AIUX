import 'package:flutter/material.dart';

import '../icons.dart';
import '../models.dart';
import '../scope.dart';
import '../surface_node.dart';
import '../theme.dart';

// MARK: - Context bar (PLAN §8)
//
// `AIContextBar` renders session context entities as chips with an add
// hook. Remove emits `aiux.context.remove` `{entityId}`; add emits
// `aiux.context.add` — the host owns pickers and policies.

/// Horizontal chip row for the session's context entities.
class AIContextBar extends StatelessWidget {
  const AIContextBar({
    super.key,
    required this.entities,
    this.showsAddButton = true,
  });

  final List<AiuxContextEntity> entities;

  /// Show the trailing add chip.
  final bool showsAddButton;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    return Container(
      color: colors.background,
      padding: EdgeInsets.symmetric(vertical: theme.space(AiuxGap.xs)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: theme.space(AiuxGap.md)),
        child: Row(
          children: [
            for (final entity in entities) ...[
              _chip(context, entity, theme, colors),
              SizedBox(width: theme.space(AiuxGap.sm)),
            ],
            if (showsAddButton) _addChip(context, theme, colors),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, AiuxContextEntity entity,
      AiuxThemeData theme, AiuxColors colors) {
    return Semantics(
      label: 'Context: ${entity.label}',
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: theme.space(AiuxGap.sm),
            vertical: theme.space(AiuxGap.xs)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(theme.radius.full),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(aiuxContextIcon(entity.kind), size: 14, color: colors.muted),
            SizedBox(width: theme.space(AiuxGap.xs)),
            Text(entity.label,
                style: theme.typography.caption.copyWith(color: colors.muted),
                maxLines: 1),
            SizedBox(width: theme.space(AiuxGap.xs)),
            Semantics(
              label: 'Remove ${entity.label}',
              button: true,
              child: InkWell(
                onTap: () => AiuxScope.emitAction(
                    context,
                    AiuxAction(
                        id: AiuxAction.contextRemove,
                        payload: {'entityId': entity.id})),
                child: Icon(Icons.close, size: 12, color: colors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addChip(
      BuildContext context, AiuxThemeData theme, AiuxColors colors) {
    return Semantics(
      label: 'Add context',
      button: true,
      child: InkWell(
        onTap: () => AiuxScope.emitAction(
            context, const AiuxAction(id: AiuxAction.contextAdd)),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: theme.space(AiuxGap.sm),
              vertical: theme.space(AiuxGap.xs)),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(theme.radius.full),
            border: Border.all(color: colors.accent),
          ),
          child: Icon(Icons.add, size: 14, color: colors.accent),
        ),
      ),
    );
  }
}
