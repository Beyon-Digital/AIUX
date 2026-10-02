import 'package:flutter/material.dart';

import '../models.dart';
import '../surface_node.dart';
import '../theme.dart';

// MARK: - Tool status (PLAN §8)
//
// `AIToolStatus` renders a session `Tool` record: name, lifecycle status,
// live progress, and result/error summaries. It is display-only — tools are
// executed by the host/agent, never by the renderer.

/// Card for one tool invocation: started → progress → completed/failed.
class AIToolStatus extends StatelessWidget {
  const AIToolStatus({super.key, required this.tool});

  final AiuxTool tool;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final statusColor = _statusColor(colors);
    return Semantics(
      label: 'Tool ${tool.name}: ${tool.status.name}',
      child: Container(
        padding: EdgeInsets.all(theme.space(AiuxGap.sm)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius:
              BorderRadius.circular(theme.radius.radius(AiuxRadius.md)),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _statusIcon(statusColor),
                SizedBox(width: theme.space(AiuxGap.sm)),
                Text(tool.name, style: theme.typography.label),
                SizedBox(width: theme.space(AiuxGap.xs)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: theme.space(AiuxGap.xs), vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(theme.radius.full),
                  ),
                  child: Text(tool.status.name,
                      style: theme.typography.caption
                          .copyWith(color: statusColor)),
                ),
                const Spacer(),
              ],
            ),
            if (tool.progress != null)
              Padding(
                padding: EdgeInsets.only(top: theme.space(AiuxGap.xs)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tool.progress!.fraction != null ||
                        tool.status == AiuxToolStatus.running)
                      LinearProgressIndicator(
                        value: tool.progress!.fraction,
                        color: colors.accent,
                        backgroundColor: colors.background,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    if (tool.progress!.label != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(tool.progress!.label!,
                            style: theme.typography.caption
                                .copyWith(color: colors.muted)),
                      ),
                  ],
                ),
              ),
            if (tool.error != null)
              Padding(
                padding: EdgeInsets.only(top: theme.space(AiuxGap.xs)),
                child: Text(tool.error!.message,
                    style: theme.typography.caption
                        .copyWith(color: colors.destructive)),
              )
            else if (aiuxJsonDescribe(tool.result) != null)
              Padding(
                padding: EdgeInsets.only(top: theme.space(AiuxGap.xs)),
                child: Text(aiuxJsonDescribe(tool.result)!,
                    style:
                        theme.typography.caption.copyWith(color: colors.muted),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(Color statusColor) => switch (tool.status) {
        AiuxToolStatus.running => const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
        AiuxToolStatus.completed =>
          Icon(Icons.check_circle, size: 16, color: statusColor),
        AiuxToolStatus.failed =>
          Icon(Icons.error, size: 16, color: statusColor),
      };

  Color _statusColor(AiuxColors colors) => switch (tool.status) {
        AiuxToolStatus.running => colors.accent,
        AiuxToolStatus.completed => colors.success,
        AiuxToolStatus.failed => colors.destructive,
      };
}
