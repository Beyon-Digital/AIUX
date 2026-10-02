import 'package:flutter/material.dart';

import '../models.dart';
import '../scope.dart';
import '../surface_node.dart';
import '../theme.dart';

// MARK: - Approval (PLAN §23)
//
// `AIApproval` renders an approval request in all five lifecycle states —
// requested / approved / rejected / expired / executed — with the requested
// action's summary. Interactive controls emit `aiux.approval.resolve`
// actions upward; the renderer NEVER executes or auto-resolves anything.

/// Approval card. Approve/Reject are only actionable while `requested`.
class AIApproval extends StatelessWidget {
  const AIApproval({super.key, required this.approval});

  final AiuxApproval approval;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final statusColor = _statusColor(colors);
    return Semantics(
      label:
          'Approval request: ${approval.prompt}, status ${approval.status.name}',
      child: Container(
        padding: EdgeInsets.all(theme.space(AiuxGap.md)),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius:
              BorderRadius.circular(theme.radius.radius(AiuxRadius.lg)),
          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_statusIcon(), size: 18, color: statusColor),
                SizedBox(width: theme.space(AiuxGap.sm)),
                Expanded(
                  child: Text(approval.prompt, style: theme.typography.label),
                ),
                _badge(theme, statusColor),
              ],
            ),
            if (approval.description != null)
              Padding(
                padding: EdgeInsets.only(top: theme.space(AiuxGap.sm)),
                child: Text(approval.description!,
                    style: theme.typography.body.copyWith(color: colors.muted)),
              ),
            if (approval.action != null)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(top: theme.space(AiuxGap.sm)),
                padding: EdgeInsets.all(theme.space(AiuxGap.sm)),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius:
                      BorderRadius.circular(theme.radius.radius(AiuxRadius.sm)),
                ),
                child: Text(_actionSummary(approval.action!),
                    style: theme.typography.code.copyWith(color: colors.muted)),
              ),
            if (approval.expiresAt != null &&
                approval.status == AiuxApprovalStatus.requested)
              Padding(
                padding: EdgeInsets.only(top: theme.space(AiuxGap.sm)),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 12, color: colors.warning),
                    SizedBox(width: theme.space(AiuxGap.xs)),
                    Text('Expires ${approval.expiresAt}',
                        style: theme.typography.caption
                            .copyWith(color: colors.warning)),
                  ],
                ),
              ),
            if (approval.resolution?.note != null)
              Padding(
                padding: EdgeInsets.only(top: theme.space(AiuxGap.sm)),
                child: Text(approval.resolution!.note!,
                    style:
                        theme.typography.caption.copyWith(color: colors.muted)),
              ),
            SizedBox(height: theme.space(AiuxGap.sm)),
            _controls(context, theme, colors),
          ],
        ),
      ),
    );
  }

  // MARK: Status rendering — all five states visually distinct (§23)

  IconData _statusIcon() => switch (approval.status) {
        AiuxApprovalStatus.requested => Icons.pan_tool_outlined,
        AiuxApprovalStatus.approved => Icons.check_circle_outline,
        AiuxApprovalStatus.rejected => Icons.cancel_outlined,
        AiuxApprovalStatus.expired => Icons.running_with_errors,
        AiuxApprovalStatus.executed => Icons.verified,
      };

  Color _statusColor(AiuxColors colors) => switch (approval.status) {
        AiuxApprovalStatus.requested => colors.warning,
        AiuxApprovalStatus.approved => colors.accent,
        AiuxApprovalStatus.rejected => colors.destructive,
        AiuxApprovalStatus.expired => colors.muted,
        AiuxApprovalStatus.executed => colors.success,
      };

  Widget _badge(AiuxThemeData theme, Color statusColor) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: theme.space(AiuxGap.xs), vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(theme.radius.full),
      ),
      child: Text(approval.status.name,
          style: theme.typography.caption.copyWith(color: statusColor)),
    );
  }

  // MARK: Controls

  Widget _controls(
      BuildContext context, AiuxThemeData theme, AiuxColors colors) {
    switch (approval.status) {
      case AiuxApprovalStatus.requested:
        return Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () =>
                    _resolve(context, AiuxApprovalDecision.approved),
                style: FilledButton.styleFrom(backgroundColor: colors.accent),
                child: Text('Approve', style: theme.typography.label),
              ),
            ),
            SizedBox(width: theme.space(AiuxGap.sm)),
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    _resolve(context, AiuxApprovalDecision.rejected),
                style: OutlinedButton.styleFrom(
                    foregroundColor: colors.destructive,
                    side: BorderSide(color: colors.destructive)),
                child: Text('Reject', style: theme.typography.label),
              ),
            ),
          ],
        );
      case AiuxApprovalStatus.approved:
        return _statusNote(theme, colors.accent, Icons.hourglass_empty,
            'Approved — awaiting execution');
      case AiuxApprovalStatus.rejected:
        return _statusNote(
            theme, colors.destructive, Icons.back_hand_outlined, 'Rejected');
      case AiuxApprovalStatus.expired:
        return _statusNote(
            theme, colors.muted, Icons.running_with_errors, 'Expired');
      case AiuxApprovalStatus.executed:
        return _statusNote(theme, colors.success, Icons.verified, 'Executed');
    }
  }

  Widget _statusNote(
      AiuxThemeData theme, Color color, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        SizedBox(width: theme.space(AiuxGap.xs)),
        Text(text, style: theme.typography.caption.copyWith(color: color)),
      ],
    );
  }

  /// Emit `aiux.approval.resolve` — payload `{approvalId, decision}`. The
  /// host maps this to an `approval.resolved` event (or its own policy).
  void _resolve(BuildContext context, AiuxApprovalDecision decision) {
    AiuxScope.emitAction(
        context,
        AiuxAction(id: AiuxAction.approvalResolve, payload: {
          'approvalId': approval.id,
          'decision': decision.name,
        }));
  }

  /// One-line summary of the requested action: `id` + sorted payload keys.
  String _actionSummary(AiuxAction action) {
    final keys = action.payload.keys.toList()..sort();
    return [
      action.id,
      ...keys.map((k) => '$k: ${aiuxJsonDescribe(action.payload[k]) ?? ''}'),
    ].join('\n');
  }
}
