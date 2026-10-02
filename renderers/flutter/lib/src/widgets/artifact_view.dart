import 'package:flutter/material.dart';

import '../helpers.dart';
import '../models.dart';
import '../scope.dart';
import '../surface_node.dart';
import '../theme.dart';

// MARK: - Artifact (PLAN §8)
//
// `AIArtifactPreview` renders an artifact card (kind icon, title, revision)
// that opens a detail sheet on tap. Opening the artifact's URI emits
// `aiux.attachment.open` upward — navigation is host-mediated (§23).

/// Artifact card → detail sheet.
class AIArtifactPreview extends StatelessWidget {
  const AIArtifactPreview({super.key, required this.artifact});

  final AiuxArtifact artifact;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    return Semantics(
      label:
          'Artifact: ${artifact.title ?? artifact.kind}, revision ${artifact.revision}',
      button: true,
      child: InkWell(
        onTap: () {
          AiuxScope.emitAction(
              context,
              AiuxAction(
                  id: AiuxAction.artifactOpen,
                  payload: {'artifactId': artifact.id}));
          // Capture scope before pushing the sheet — the sheet's context
          // sits above the conversation in the widget tree.
          final model = AiuxScope.modelOf(context);
          final emit = AiuxScope.emitterOf(context);
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (context) => AiuxScope(
              model: model,
              emit: emit,
              child: AiArtifactDetail(artifact: artifact),
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.all(theme.space(AiuxGap.sm)),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                BorderRadius.circular(theme.radius.radius(AiuxRadius.md)),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(_icon(), size: 18, color: colors.accent),
              SizedBox(width: theme.space(AiuxGap.sm)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(artifact.title ?? artifact.kind,
                        style: theme.typography.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('${artifact.kind} · rev ${artifact.revision}',
                        style: theme.typography.caption
                            .copyWith(color: colors.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon() => switch (artifact.kind) {
        'code' => Icons.code,
        'document' || 'doc' || 'report' => Icons.description_outlined,
        'diff' || 'patch' => Icons.difference_outlined,
        'plan' => Icons.checklist,
        'image' => Icons.photo_outlined,
        'table' || 'spreadsheet' => Icons.table_chart,
        _ => Icons.article_outlined,
      };
}

/// Full artifact detail sheet — title, revision, scrollable content, and a
/// host-mediated "Open" affordance when the artifact carries a URI.
class AiArtifactDetail extends StatelessWidget {
  const AiArtifactDetail({super.key, required this.artifact});

  final AiuxArtifact artifact;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    return SafeArea(
      child: Container(
        color: colors.background,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: theme.space(AiuxGap.md),
                  vertical: theme.space(AiuxGap.sm)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(artifact.title ?? artifact.kind,
                        style: theme.typography.heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (artifact.uri != null)
                    TextButton.icon(
                      onPressed: () => AiuxScope.emitAction(
                          context,
                          AiuxAction(id: AiuxAction.attachmentOpen, payload: {
                            'uri': artifact.uri,
                            'artifactId': artifact.id,
                          })),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('Open'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(theme.space(AiuxGap.lg)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (artifact.content != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: artifact.kind == 'markdown' ||
                                artifact.kind == 'document'
                            ? AiuxMarkdownText(artifact.content!)
                            : SelectableText(artifact.content!,
                                style: theme.typography.code),
                      ),
                    if (aiuxJsonDescribe(artifact.metadata) != null)
                      Padding(
                        padding: EdgeInsets.only(top: theme.space(AiuxGap.md)),
                        child: Text(aiuxJsonDescribe(artifact.metadata)!,
                            style: theme.typography.caption
                                .copyWith(color: colors.muted)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
