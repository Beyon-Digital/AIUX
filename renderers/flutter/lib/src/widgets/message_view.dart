import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers.dart';
import '../icons.dart';
import '../models.dart';
import '../scope.dart';
import '../surface_node.dart';
import '../theme.dart';
import 'approval_view.dart';
import 'artifact_view.dart';
import 'surface_view.dart';
import 'tool_status_view.dart';

// MARK: - Message rendering (PLAN §8, §14)
//
// `AIMessage` renders one protocol message: role determines alignment and
// surface role, `parts` render in order through `AIPartView`. Reference
// parts (`tool`/`approval`/`artifact`/`surface`) resolve their entities
// through `AiuxScope.modelOf` — missing references degrade to placeholders.

/// One message in a conversation — a bubble of ordered parts.
class AIMessage extends StatelessWidget {
  const AIMessage({super.key, required this.message});

  final AiuxMessage message;

  @override
  Widget build(BuildContext context) {
    switch (message.role) {
      case AiuxMessageRole.system:
        return _systemRow(context);
      case AiuxMessageRole.user:
        return _alignedRow(context, isUser: true);
      case AiuxMessageRole.assistant:
      case AiuxMessageRole.tool:
        return _alignedRow(context, isUser: false);
    }
  }

  Widget _systemRow(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    return Semantics(
      label: 'System message',
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.space(AiuxGap.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final part in message.parts) AIPartView(part: part),
            _statusBadge(theme, colors),
          ]
              .map((w) => DefaultTextStyle(
                    style:
                        theme.typography.caption.copyWith(color: colors.muted),
                    child: w,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _alignedRow(BuildContext context, {required bool isUser}) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final fill = isUser ? colors.userSurface : colors.assistantSurface;
    return Semantics(
      label: isUser
          ? 'You'
          : (message.role == AiuxMessageRole.tool
              ? 'Tool output'
              : 'Assistant'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUser) SizedBox(width: theme.space(AiuxGap.xl)),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(theme.space(AiuxGap.md)),
              decoration: BoxDecoration(
                color: fill,
                borderRadius:
                    BorderRadius.circular(theme.radius.radius(AiuxRadius.lg)),
              ),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  for (final part in message.parts)
                    Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      widthFactor: 1,
                      child: Padding(
                        padding:
                            EdgeInsets.only(bottom: theme.space(AiuxGap.sm)),
                        child: AIPartView(part: part),
                      ),
                    ),
                  _statusBadge(theme, colors),
                ],
              ),
            ),
          ),
          if (!isUser) SizedBox(width: theme.space(AiuxGap.xl)),
        ],
      ),
    );
  }

  /// Streaming / failed / cancelled marker under a message.
  Widget _statusBadge(AiuxThemeData theme, AiuxColors colors) {
    switch (message.status) {
      case AiuxMessageStatus.streaming:
        return Padding(
          padding: EdgeInsets.only(top: theme.space(AiuxGap.xs)),
          child: const AiuxStreamingDots(),
        );
      case AiuxMessageStatus.failed:
        return _badgeRow(
            theme, colors.destructive, Icons.error_outline, 'Failed');
      case AiuxMessageStatus.cancelled:
        return _badgeRow(theme, colors.muted, Icons.block, 'Cancelled');
      case AiuxMessageStatus.complete:
      case null:
        return const SizedBox.shrink();
    }
  }

  Widget _badgeRow(
      AiuxThemeData theme, Color color, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        SizedBox(width: theme.space(AiuxGap.xs)),
        Text(text, style: theme.typography.caption.copyWith(color: color)),
      ],
    );
  }
}

/// Three pulsing dots marking in-flight streaming output. Collapses to a
/// static marker when animations are disabled.
class AiuxStreamingDots extends StatefulWidget {
  const AiuxStreamingDots({super.key});

  @override
  State<AiuxStreamingDots> createState() => _AiuxStreamingDotsState();
}

class _AiuxStreamingDotsState extends State<AiuxStreamingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      return Text('…',
          style: theme.typography.body.copyWith(color: colors.muted));
    }
    return Semantics(
      label: 'Streaming response',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = (_controller.value * 3).floor() % 3;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 5,
                  height: 5,
                  margin: EdgeInsets.only(right: theme.space(AiuxGap.xs)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.muted.withValues(alpha: i == t ? 0.9 : 0.35),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// MARK: - Part dispatch

/// Renders a single typed part. Unknown/missing data → `AIUXUnsupported`.
class AIPartView extends StatelessWidget {
  const AIPartView({super.key, required this.part});

  final AiuxPart part;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final model = AiuxScope.modelOf(context);
    switch (part) {
      case AiuxTextPart(:final text):
        return SelectableText(text, style: theme.typography.body);
      case AiuxMarkdownPart(:final markdown):
        return AiuxMarkdownText(markdown);
      case AiuxCodePart(:final code, :final language):
        return AiCodeBlock(code: code, language: language);
      case AiuxImagePart(:final attachment):
        return AiImagePart(attachment: attachment);
      case AiuxAttachmentPart(:final attachment):
        return AiAttachmentRow(attachment: attachment);
      case AiuxCitationPart(:final citation):
        return AiCitationRow(citation: citation);
      case AiuxToolPart(:final toolId):
        final tool = model.tool(toolId);
        return tool != null
            ? AIToolStatus(tool: tool)
            : AIUXUnsupported(kind: 'tool reference', detail: toolId);
      case AiuxApprovalPart(:final approvalId):
        final approval = model.approval(approvalId);
        return approval != null
            ? AIApproval(approval: approval)
            : AIUXUnsupported(kind: 'approval reference', detail: approvalId);
      case AiuxArtifactPart(:final artifactId):
        final artifact = model.artifact(artifactId);
        return artifact != null
            ? AIArtifactPreview(artifact: artifact)
            : AIUXUnsupported(kind: 'artifact reference', detail: artifactId);
      case AiuxStatusPart(:final text, :final level):
        return AiStatusLine(text: text, level: level);
      case AiuxProgressPart(:final progress):
        return AiProgressLine(progress: progress);
      case AiuxSurfacePart(:final surfaceId):
        final tree = model.surface(surfaceId);
        return tree != null
            ? AISurface(tree: tree)
            : AIUXUnsupported(kind: 'surface reference', detail: surfaceId);
      case AiuxErrorPart(:final error):
        return AiErrorPart(partId: part.id, error: error);
      case AiuxUnknownPart(:final type):
        return AIUXUnsupported(kind: 'part', detail: type);
    }
  }
}

// MARK: - Leaf part views

/// Code block with language badge, monospace body, copy affordance.
class AiCodeBlock extends StatelessWidget {
  const AiCodeBlock({super.key, required this.code, this.language});

  final String code;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final radius = theme.radius.radius(AiuxRadius.md);
    return Semantics(
      label: 'Code block${language != null ? ', $language' : ''}',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: colors.surface,
              padding: EdgeInsets.symmetric(
                  horizontal: theme.space(AiuxGap.md),
                  vertical: theme.space(AiuxGap.xs)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(language ?? 'code',
                        style: theme.typography.caption
                            .copyWith(color: colors.muted)),
                  ),
                  Semantics(
                    label: 'Copy code',
                    button: true,
                    child: InkWell(
                      onTap: () => Clipboard.setData(ClipboardData(text: code)),
                      child: Icon(Icons.copy_outlined,
                          size: 16, color: colors.muted),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.all(theme.space(AiuxGap.md)),
              child: SelectableText(code, style: theme.typography.code),
            ),
          ],
        ),
      ),
    );
  }
}

/// Image part — network-loaded from the attachment URI, degrading to the
/// attachment row on failure or a missing URI.
class AiImagePart extends StatelessWidget {
  const AiImagePart({super.key, required this.attachment});

  final AiuxAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final uri = attachment.uri;
    if (uri != null && Uri.tryParse(uri) != null) {
      return Semantics(
        label: attachment.name ?? attachment.uri ?? 'Image',
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(theme.radius.radius(AiuxRadius.md)),
          child: Image.network(
            uri,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator())),
            errorBuilder: (context, error, stack) =>
                AiAttachmentRow(attachment: attachment),
          ),
        ),
      );
    }
    return AiAttachmentRow(attachment: attachment);
  }
}

/// Attachment part — file row; taps emit `aiux.attachment.open`.
class AiAttachmentRow extends StatelessWidget {
  const AiAttachmentRow({super.key, required this.attachment});

  final AiuxAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final subtitle = [attachment.mimeType, aiuxByteCount(attachment.sizeBytes)]
        .whereType<String>()
        .join(' · ');
    return Semantics(
      label: 'Attachment: ${attachment.name ?? 'file'}',
      button: true,
      child: InkWell(
        onTap: () => AiuxScope.emitAction(
            context,
            AiuxAction(id: AiuxAction.attachmentOpen, payload: {
              'uri': attachment.uri,
              'name': attachment.name,
              'attachmentId': attachment.id,
            })),
        child: Container(
          padding: EdgeInsets.all(theme.space(AiuxGap.sm)),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                BorderRadius.circular(theme.radius.radius(AiuxRadius.md)),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(aiuxAttachmentIcon(attachment.mimeType),
                  size: 20, color: colors.accent),
              SizedBox(width: theme.space(AiuxGap.sm)),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(attachment.name ?? 'Attachment',
                        style: theme.typography.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: theme.typography.caption
                              .copyWith(color: colors.muted)),
                  ],
                ),
              ),
              SizedBox(width: theme.space(AiuxGap.sm)),
              Icon(Icons.open_in_new, size: 14, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Citation part — source row; taps emit `aiux.citation.open` (host
/// validates the target before navigating, §23).
class AiCitationRow extends StatelessWidget {
  const AiCitationRow({super.key, required this.citation});

  final AiuxCitation citation;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    return Semantics(
      label: 'Citation: ${citation.title ?? citation.uri ?? 'source'}',
      button: true,
      child: InkWell(
        onTap: () => AiuxScope.emitAction(
            context,
            AiuxAction(id: AiuxAction.citationOpen, payload: {
              'citationId': citation.id,
              'uri': citation.uri,
              'title': citation.title,
            })),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(theme.space(AiuxGap.sm)),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                BorderRadius.circular(theme.radius.radius(AiuxRadius.sm)),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: colors.accent),
                  SizedBox(width: theme.space(AiuxGap.xs)),
                  Flexible(
                    child: Text(citation.title ?? citation.uri ?? 'Source',
                        style: theme.typography.label
                            .copyWith(color: colors.accent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (citation.source != null) ...[
                    SizedBox(width: theme.space(AiuxGap.xs)),
                    Text(citation.source!,
                        style: theme.typography.caption
                            .copyWith(color: colors.muted)),
                  ],
                ],
              ),
              if (citation.snippet != null)
                Padding(
                  padding: EdgeInsets.only(top: theme.space(AiuxGap.xs)),
                  child: Text(citation.snippet!,
                      style: theme.typography.caption
                          .copyWith(color: colors.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline `status` part.
class AiStatusLine extends StatelessWidget {
  const AiStatusLine({super.key, required this.text, this.level});

  final String text;
  final AiuxStatusLevel? level;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    return Semantics(
      label: 'Status: $text',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(aiuxStatusIcon(level),
              size: 14, color: colors.statusLevel(level)),
          SizedBox(width: theme.space(AiuxGap.xs)),
          Flexible(
            child: Text(text,
                style: theme.typography.caption
                    .copyWith(color: colors.statusLevel(level))),
          ),
        ],
      ),
    );
  }
}

/// Inline `progress` part.
class AiProgressLine extends StatelessWidget {
  const AiProgressLine({super.key, required this.progress});

  final AiuxProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    return Semantics(
      label: 'Progress: ${progress.label ?? 'in progress'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 240,
            child: LinearProgressIndicator(
              value: progress.fraction,
              color: colors.accent,
              backgroundColor: colors.surface,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (progress.label != null)
            Padding(
              padding: EdgeInsets.only(top: theme.space(AiuxGap.xs)),
              child: Text(progress.label!,
                  style:
                      theme.typography.caption.copyWith(color: colors.muted)),
            ),
        ],
      ),
    );
  }
}

/// `error` part with retry affordance — emits `aiux.error.retry`, never
/// retries itself.
class AiErrorPart extends StatelessWidget {
  const AiErrorPart({super.key, required this.partId, required this.error});

  final String partId;
  final AiuxError error;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    return Semantics(
      label: 'Error ${error.code}: ${error.message}',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(theme.space(AiuxGap.sm)),
        decoration: BoxDecoration(
          color: colors.destructive.withValues(alpha: 0.08),
          borderRadius:
              BorderRadius.circular(theme.radius.radius(AiuxRadius.sm)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, size: 16, color: colors.destructive),
                SizedBox(width: theme.space(AiuxGap.xs)),
                Flexible(
                  child: Text(error.message,
                      style: theme.typography.label
                          .copyWith(color: colors.destructive)),
                ),
              ],
            ),
            Text(error.code,
                style: theme.typography.caption.copyWith(color: colors.muted)),
            if (error.retryable == true)
              TextButton(
                onPressed: () => AiuxScope.emitAction(
                    context,
                    AiuxAction(id: AiuxAction.errorRetry, payload: {
                      'partId': partId,
                      'code': error.code,
                    })),
                child: Text('Retry',
                    style:
                        theme.typography.label.copyWith(color: colors.accent)),
              ),
          ],
        ),
      ),
    );
  }
}
