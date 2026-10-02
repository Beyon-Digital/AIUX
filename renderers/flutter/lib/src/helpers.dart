import 'package:flutter/material.dart';

import 'surface_node.dart';
import 'theme.dart';

// MARK: - Shared display helpers
//
// Small internal utilities used across views: markdown rendering and the
// non-fatal "unsupported" placeholder. Nothing here invents styling —
// everything resolves through `AiuxTheme`.

/// Render markdown into a `Text.rich`, covering the subset the protocol
/// emits: ATX headings, fenced code blocks, `**bold**`, `*em*`/`_em_`,
/// `` `code` ``, `-`/`*` bullets, `1.` ordered items, `[label](uri)` links
/// (styled, not navigable — navigation is host-mediated), and paragraphs.
/// Falls back to literal source for anything unrecognized — semantic parity,
/// never a crash.
class AiuxMarkdownText extends StatelessWidget {
  const AiuxMarkdownText(this.source, {super.key, this.style});

  final String source;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final base = style ?? theme.typography.body;
    return Text.rich(
      TextSpan(children: _parse(context, base, colors)),
      style: base,
    );
  }

  List<InlineSpan> _parse(
      BuildContext context, TextStyle base, AiuxColors colors) {
    final theme = AiuxTheme.of(context);
    final codeStyle =
        theme.typography.code.copyWith(backgroundColor: colors.surface);
    final spans = <InlineSpan>[];
    final lines = source.split('\n');
    var inFence = false;
    var orderedIndex = 0;

    void newline() => spans.add(const TextSpan(text: '\n'));

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('```')) {
        inFence = !inFence;
        continue;
      }
      if (inFence) {
        spans.add(TextSpan(text: '$line\n', style: codeStyle));
        continue;
      }
      if (line.trim().isEmpty) {
        newline();
        continue;
      }
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final headingStyle = switch (level) {
          1 => theme.typography.title,
          2 => theme.typography.heading,
          _ => theme.typography.label,
        };
        spans.addAll(
            _inline(heading.group(2)!, headingStyle, codeStyle, colors));
        newline();
        continue;
      }
      final bullet = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        spans.add(
            TextSpan(text: '  •  ', style: base.copyWith(color: colors.muted)));
        spans.addAll(_inline(bullet.group(1)!, base, codeStyle, colors));
        newline();
        continue;
      }
      final ordered = RegExp(r'^\s*(\d+)\.\s+(.*)$').firstMatch(line);
      if (ordered != null) {
        orderedIndex = int.tryParse(ordered.group(1)!) ?? ++orderedIndex;
        spans.add(TextSpan(
            text: '  $orderedIndex.  ',
            style: base.copyWith(color: colors.muted)));
        spans.addAll(_inline(ordered.group(2)!, base, codeStyle, colors));
        newline();
        continue;
      }
      spans.addAll(_inline(line, base, codeStyle, colors));
      if (i < lines.length - 1) newline();
    }
    return spans;
  }

  List<InlineSpan> _inline(
      String text, TextStyle base, TextStyle codeStyle, AiuxColors colors) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(\*\*[^*]+\*\*)|(\*[^*]+\*)|(_[^_]+_)|(`[^`]+`)|(\[[^\]]*\]\([^)]*\))',
    );
    var offset = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('**')) {
        spans.add(TextSpan(
            text: token.substring(2, token.length - 2),
            style: base.copyWith(fontWeight: FontWeight.w700)));
      } else if (token.startsWith('`')) {
        spans.add(TextSpan(
            text: token.substring(1, token.length - 1), style: codeStyle));
      } else if (token.startsWith('[')) {
        final inner = RegExp(r'\[([^\]]*)\]\(([^)]*)\)').firstMatch(token)!;
        spans.add(TextSpan(
            text: inner.group(1),
            style: base.copyWith(
                color: colors.accent, decoration: TextDecoration.underline)));
      } else {
        // *emphasis* or _emphasis_
        spans.add(TextSpan(
            text: token.substring(1, token.length - 1),
            style: base.copyWith(fontStyle: FontStyle.italic)));
      }
      offset = match.end;
    }
    if (offset < text.length) {
      spans.add(TextSpan(text: text.substring(offset)));
    }
    return spans;
  }
}

/// The non-fatal placeholder for unknown parts/nodes/references (PLAN §21 —
/// an unrecognized element degrades, never crashes the render).
class AIUXUnsupported extends StatelessWidget {
  const AIUXUnsupported({super.key, required this.kind, this.detail});

  final String kind;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    return Semantics(
      label: 'Unsupported content: $kind',
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: theme.space(AiuxGap.md),
            vertical: theme.space(AiuxGap.sm)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius:
              BorderRadius.circular(theme.radius.radius(AiuxRadius.sm)),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.extension_outlined, size: 16, color: colors.muted),
            SizedBox(width: theme.space(AiuxGap.sm)),
            Flexible(
              child: Text(
                detail != null
                    ? 'Unsupported $kind: $detail'
                    : 'Unsupported $kind',
                style: theme.typography.caption.copyWith(color: colors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
