import 'package:flutter/material.dart';

import '../helpers.dart';
import '../icons.dart';
import '../models.dart';
import '../scope.dart';
import '../surface_node.dart';
import '../theme.dart';
import 'message_view.dart';

// MARK: - Semantic surface renderer (PLAN §6, ADR 0006)
//
// `AISurface` renders a Surface Schema v1 tree. Every primitive maps to a
// semantic Flutter layout — tokens (`gap`, `padding`, `radius`, `alignment`,
// `distribution`) never decode to pixels. Interactive nodes (button, menu,
// input, textarea, select, checkbox) emit `AiuxAction`s upward and never
// execute anything themselves. Unknown node kinds degrade to a placeholder.

/// A surface tree (one `surface` root node) embedded in a message or
/// standalone.
class AISurface extends StatelessWidget {
  const AISurface({super.key, required this.tree});

  final AiuxSurfaceTree tree;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    return Semantics(
      label: 'Surface ${tree.name ?? tree.id}, revision ${tree.revision}',
      child: Container(
        padding: EdgeInsets.all(theme.space(AiuxGap.sm)),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius:
              BorderRadius.circular(theme.radius.radius(AiuxRadius.lg)),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tree.name != null)
              Padding(
                padding: EdgeInsets.only(bottom: theme.space(AiuxGap.xs)),
                child: Text(tree.name!,
                    style:
                        theme.typography.caption.copyWith(color: colors.muted)),
              ),
            AiuxNodeView(node: tree.root),
          ],
        ),
      ),
    );
  }
}

// MARK: - Node dispatch

/// Renders a single surface node, recursing into container children.
class AiuxNodeView extends StatelessWidget {
  const AiuxNodeView({super.key, required this.node});

  final AiuxSurfaceNode node;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final layout = node.layout;
    final pad = theme.padding(layout.padding);

    Widget padded(Widget child) =>
        pad <= 0 ? child : Padding(padding: EdgeInsets.all(pad), child: child);

    switch (node) {
      case AiuxSurface(:final children):
        return Padding(
          padding:
              EdgeInsets.all(theme.padding(layout.padding ?? AiuxPadding.md)),
          child: AiuxFlowStack(
              children: children,
              direction: AiuxStackDirection.vertical,
              layout: layout),
        );

      case AiuxCard(:final children, :final title):
        return Container(
          padding:
              EdgeInsets.all(theme.padding(layout.padding ?? AiuxPadding.md)),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(
                theme.radius.radius(layout.radius ?? AiuxRadius.md)),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Padding(
                  padding: EdgeInsets.only(bottom: theme.space(AiuxGap.xs)),
                  child: Text(title, style: theme.typography.heading),
                ),
              AiuxFlowStack(
                  children: children,
                  direction: AiuxStackDirection.vertical,
                  layout: layout),
            ],
          ),
        );

      case AiuxStack(:final children, :final direction):
        return padded(AiuxFlowStack(
            children: children,
            direction: direction ?? AiuxStackDirection.vertical,
            layout: layout));

      case AiuxRow(:final children):
        return padded(AiuxFlowStack(
            children: children,
            direction: AiuxStackDirection.horizontal,
            layout: layout));

      case AiuxGrid(:final children, :final columns):
        return AiuxGridView(
            children: children, columns: columns, layout: layout);

      case AiuxHeading(:final text, :final level):
        final style = switch (level ?? 2) {
          1 => theme.typography.title,
          2 => theme.typography.heading,
          _ => theme.typography.label,
        };
        return padded(Semantics(header: true, child: Text(text, style: style)));

      case AiuxText(:final text, :final variant):
        var style = switch (variant) {
          AiuxTextVariant.caption => theme.typography.caption,
          AiuxTextVariant.label => theme.typography.label,
          _ => theme.typography.body,
        };
        if (variant == AiuxTextVariant.emphasis) {
          style = style.copyWith(fontStyle: FontStyle.italic);
        } else if (variant == AiuxTextVariant.strong) {
          style = style.copyWith(fontWeight: FontWeight.w700);
        }
        if (variant == AiuxTextVariant.caption ||
            variant == AiuxTextVariant.muted) {
          style = style.copyWith(color: colors.muted);
        }
        return padded(SelectableText(text, style: style));

      case AiuxMarkdown(:final markdown):
        return padded(AiuxMarkdownText(markdown));

      case AiuxCode(:final code, :final language):
        return padded(AiCodeBlock(code: code, language: language));

      case AiuxIcon(:final name, :final size):
        final iconSize = switch (size) {
          AiuxIconSize.sm => 14.0,
          AiuxIconSize.lg => 28.0,
          _ => 20.0,
        };
        return padded(Semantics(
            label: name,
            child: Icon(aiuxIcon(name), size: iconSize, color: colors.muted)));

      case AiuxImage(:final src, :final alt):
        return padded(_AiuxSurfaceImage(src: src, alt: alt));

      case AiuxBadge(:final text, :final tone):
        final toneColor = colors.tone(tone);
        return padded(Semantics(
          label: 'Badge: $text',
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: theme.space(AiuxGap.xs), vertical: 2),
            decoration: BoxDecoration(
              color: toneColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(theme.radius.full),
            ),
            child: Text(text,
                style: theme.typography.caption.copyWith(color: toneColor)),
          ),
        ));

      case AiuxDivider():
        return padded(Padding(
            padding: EdgeInsets.symmetric(vertical: theme.space(AiuxGap.xs)),
            child: Divider(color: colors.border, height: 1)));

      case AiuxSpacer(:final size):
        return SizedBox(height: theme.space(size ?? AiuxGap.md));

      case AiuxKeyValue(:final items):
        return padded(Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              Padding(
                padding: EdgeInsets.only(bottom: theme.space(AiuxGap.xs)),
                child: Row(
                  children: [
                    Text(item.key,
                        style: theme.typography.caption
                            .copyWith(color: colors.muted)),
                    Expanded(child: SizedBox(width: theme.space(AiuxGap.sm))),
                    Flexible(
                      child: Text(item.value,
                          style: theme.typography.label,
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
              ),
          ],
        ));

      case AiuxList(:final children, :final ordered):
        return padded(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++)
              Padding(
                padding: EdgeInsets.only(
                    bottom: theme.space(layout.gap ?? AiuxGap.xs)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ordered ? '${i + 1}.' : '•',
                        style: theme.typography.body
                            .copyWith(color: colors.muted)),
                    SizedBox(width: theme.space(AiuxGap.sm)),
                    Expanded(child: AiuxNodeView(node: children[i])),
                  ],
                ),
              ),
          ],
        ));

      case AiuxTable(:final headers, :final rows, :final caption):
        return padded(
            _AiuxTableView(headers: headers, rows: rows, caption: caption));

      case AiuxButton(
          :final label,
          :final action,
          :final variant,
          :final disabled
        ):
        return padded(_AiuxSurfaceButton(
            label: label,
            action: action,
            variant: variant,
            disabled: disabled));

      case AiuxMenu(:final label, :final items):
        return padded(PopupMenuButton<AiuxAction>(
          enabled: true,
          onSelected: (action) => AiuxScope.emitAction(context, action),
          itemBuilder: (context) => [
            for (final item in items)
              PopupMenuItem<AiuxAction>(
                value: item.action,
                enabled: !item.disabled,
                child: Row(
                  children: [
                    if (item.icon != null) ...[
                      Icon(aiuxIcon(item.icon!), size: 16),
                      SizedBox(width: theme.space(AiuxGap.xs)),
                    ],
                    Text(item.label),
                  ],
                ),
              ),
          ],
          child: Semantics(
            label: label ?? 'Menu',
            button: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.more_vert, size: 18, color: colors.muted),
                SizedBox(width: theme.space(AiuxGap.xs)),
                Text(label ?? 'More', style: theme.typography.label),
              ],
            ),
          ),
        ));

      case AiuxProgressNode(:final value, :final max, :final label):
        return padded(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240,
              child: LinearProgressIndicator(
                value: value != null
                    ? (value / ((max ?? 1) > 0 ? (max ?? 1) : 1))
                        .clamp(0.0, 1.0)
                    : null,
                color: colors.accent,
                backgroundColor: colors.surface,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (label != null)
              Padding(
                padding: EdgeInsets.only(top: theme.space(AiuxGap.xs)),
                child: Text(label,
                    style:
                        theme.typography.caption.copyWith(color: colors.muted)),
              ),
          ],
        ));

      case AiuxStatus(:final text, :final tone):
        return padded(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(aiuxToneIcon(tone), size: 14, color: colors.tone(tone)),
            SizedBox(width: theme.space(AiuxGap.xs)),
            Flexible(
              child: Text(text,
                  style: theme.typography.caption
                      .copyWith(color: colors.tone(tone))),
            ),
          ],
        ));

      case AiuxInput(
          :final name,
          :final label,
          :final placeholder,
          :final value,
          :final inputType,
          :final required,
          :final disabled
        ):
        return padded(_AiuxInputField(
            name: name,
            label: label,
            placeholder: placeholder,
            initialValue: value,
            inputType: inputType,
            required: required,
            disabled: disabled));

      case AiuxTextarea(
          :final name,
          :final label,
          :final placeholder,
          :final value,
          :final rows,
          :final disabled
        ):
        return padded(_AiuxInputField(
            name: name,
            label: label,
            placeholder: placeholder,
            initialValue: value,
            rows: rows,
            disabled: disabled));

      case AiuxSelect(
          :final name,
          :final label,
          :final options,
          :final value,
          :final placeholder,
          :final disabled
        ):
        return padded(_AiuxSelectField(
            name: name,
            label: label,
            options: options,
            value: value,
            placeholder: placeholder,
            disabled: disabled));

      case AiuxCheckbox(
          :final name,
          :final label,
          :final checked,
          :final disabled
        ):
        return padded(_AiuxCheckboxField(
            name: name, label: label, checked: checked, disabled: disabled));

      case AiuxActions(:final children):
        return padded(Row(
          children: [
            const Spacer(),
            for (final child in children) ...[
              AiuxNodeView(node: child),
              SizedBox(width: theme.space(layout.gap ?? AiuxGap.sm)),
            ],
          ],
        ));

      case AiuxUnknownNode(:final type):
        return AIUXUnsupported(kind: 'surface node', detail: type);
    }
  }
}

// MARK: - Semantic layout containers

/// A stack honoring semantic `direction`, `gap`, `alignment`, `distribution`.
/// `distribution` maps onto `MainAxisAlignment`.
class AiuxFlowStack extends StatelessWidget {
  const AiuxFlowStack({
    super.key,
    required this.children,
    required this.direction,
    required this.layout,
  });

  final List<AiuxSurfaceNode> children;
  final AiuxStackDirection direction;
  final AiuxNodeLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final gap = theme.space(layout.gap ?? AiuxGap.sm);
    final childWidgets = [
      for (final child in children) AiuxNodeView(node: child),
    ];
    final separated = <Widget>[
      for (var i = 0; i < childWidgets.length; i++) ...[
        childWidgets[i],
        if (i < childWidgets.length - 1)
          direction == AiuxStackDirection.horizontal
              ? SizedBox(width: gap)
              : SizedBox(height: gap),
      ],
    ];
    final mainAxis = switch (layout.distribution ?? AiuxDistribution.start) {
      AiuxDistribution.center => MainAxisAlignment.center,
      AiuxDistribution.end => MainAxisAlignment.end,
      AiuxDistribution.spaceBetween => MainAxisAlignment.spaceBetween,
      AiuxDistribution.spaceAround => MainAxisAlignment.spaceAround,
      AiuxDistribution.spaceEvenly => MainAxisAlignment.spaceEvenly,
      _ => MainAxisAlignment.start,
    };
    if (direction == AiuxStackDirection.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: mainAxis,
        crossAxisAlignment: switch (layout.alignment) {
          AiuxAlignment.center => CrossAxisAlignment.center,
          AiuxAlignment.end => CrossAxisAlignment.end,
          AiuxAlignment.stretch => CrossAxisAlignment.stretch,
          _ => CrossAxisAlignment.start,
        },
        children: separated,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxis,
      crossAxisAlignment: switch (layout.alignment) {
        AiuxAlignment.center => CrossAxisAlignment.center,
        AiuxAlignment.end => CrossAxisAlignment.end,
        AiuxAlignment.stretch => CrossAxisAlignment.stretch,
        _ => CrossAxisAlignment.start,
      },
      children: separated,
    );
  }
}

/// Fixed-column grid — children chunked into `columns`-wide rows.
class AiuxGridView extends StatelessWidget {
  const AiuxGridView({
    super.key,
    required this.children,
    required this.columns,
    required this.layout,
  });

  final List<AiuxSurfaceNode> children;
  final int columns;
  final AiuxNodeLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final gap = theme.space(layout.gap ?? AiuxGap.md);
    final rows = <List<AiuxSurfaceNode>>[];
    for (var i = 0; i < children.length; i += columns) {
      rows.add(children.sublist(
          i, i + columns > children.length ? children.length : i + columns));
    }
    final alignment = switch (layout.alignment) {
      AiuxAlignment.center => Alignment.center,
      AiuxAlignment.end => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };
    return Padding(
      padding: EdgeInsets.all(theme.padding(layout.padding)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) SizedBox(height: theme.space(layout.gap ?? AiuxGap.sm)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  Expanded(
                    child: c < rows[r].length
                        ? Align(
                            alignment: alignment,
                            child: AiuxNodeView(node: rows[r][c]))
                        : const SizedBox.shrink(),
                  ),
                  if (c < columns - 1) SizedBox(width: gap),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Semantic table: header row + body rows.
class _AiuxTableView extends StatelessWidget {
  const _AiuxTableView({
    required this.headers,
    required this.rows,
    this.caption,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final columnCount = headers.isNotEmpty
        ? headers.length
        : (rows.isEmpty ? 1 : rows.first.length);
    Widget cell(String text, {required bool header}) => Padding(
          padding: EdgeInsets.symmetric(
              horizontal: theme.space(AiuxGap.xs),
              vertical: theme.space(AiuxGap.xs) / 2),
          child: Text(text,
              style: header
                  ? theme.typography.label.copyWith(color: colors.muted)
                  : theme.typography.body),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(
            horizontalInside: BorderSide(color: colors.border, width: 0.5),
          ),
          children: [
            if (headers.isNotEmpty)
              TableRow(children: [
                for (var c = 0; c < columnCount; c++)
                  cell(c < headers.length ? headers[c] : '', header: true),
              ]),
            for (final row in rows)
              TableRow(children: [
                for (var c = 0; c < columnCount; c++)
                  cell(c < row.length ? row[c] : '', header: false),
              ]),
          ],
        ),
        if (caption != null)
          Padding(
            padding: EdgeInsets.only(top: theme.space(AiuxGap.xs)),
            child: Text(caption!,
                style: theme.typography.caption.copyWith(color: colors.muted)),
          ),
      ],
    );
  }
}

/// Surface `image` node.
///
/// `src` comes from the agent, so the scheme is allowlisted before any
/// fetch: `https?` loads over the network, `data:image/*` decodes inline —
/// everything else (file:, aiux:, javascript:, …) renders as unsupported
/// rather than letting a crafted URL make the host request it.
class _AiuxSurfaceImage extends StatelessWidget {
  const _AiuxSurfaceImage({required this.src, this.alt});

  final String src;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final image = _resolve();
    if (image == null) {
      return AIUXUnsupported(kind: 'image', detail: src);
    }
    return Semantics(
      label: alt ?? 'Image',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radius.radius(AiuxRadius.sm)),
        child: image,
      ),
    );
  }

  Widget? _resolve() {
    if (src.isEmpty) return null;
    final uri = Uri.tryParse(src);
    if (uri == null) return null;
    if (uri.isScheme('http') || uri.isScheme('https')) {
      return Image.network(
        src,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const SizedBox(
                height: 60, child: Center(child: CircularProgressIndicator())),
        errorBuilder: (context, error, stack) =>
            AIUXUnsupported(kind: 'image', detail: src),
      );
    }
    if (uri.isScheme('data')) {
      try {
        final data = UriData.parse(src);
        if (!data.mimeType.startsWith('image/')) return null;
        return Image.memory(
          data.contentAsBytes(),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) =>
              AIUXUnsupported(kind: 'image', detail: src),
        );
      } on FormatException {
        return null;
      }
    }
    return null;
  }
}

/// Maps the semantic `variant` token onto Material button styles via theme.
class _AiuxSurfaceButton extends StatelessWidget {
  const _AiuxSurfaceButton({
    required this.label,
    required this.action,
    this.variant,
    required this.disabled,
  });

  final String label;
  final AiuxAction action;
  final AiuxButtonVariant? variant;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final label_ = Text(label, style: theme.typography.label);
    void onPressed() => AiuxScope.emitAction(context, action);
    return switch (variant ?? AiuxButtonVariant.secondary) {
      AiuxButtonVariant.primary => FilledButton(
          onPressed: disabled ? null : onPressed,
          style: FilledButton.styleFrom(backgroundColor: colors.accent),
          child: label_),
      AiuxButtonVariant.destructive => FilledButton(
          onPressed: disabled ? null : onPressed,
          style: FilledButton.styleFrom(backgroundColor: colors.destructive),
          child: label_),
      AiuxButtonVariant.ghost => TextButton(
          onPressed: disabled ? null : onPressed,
          style: TextButton.styleFrom(foregroundColor: colors.accent),
          child: label_),
      _ => OutlinedButton(
          onPressed: disabled ? null : onPressed,
          style: OutlinedButton.styleFrom(foregroundColor: colors.accent),
          child: label_),
    };
  }
}

// MARK: - Interactive field nodes
//
// Every field emits `aiux.field.change` with `{name, value}` when the user
// edits — the renderer holds only presentation state.

class _AiuxInputField extends StatefulWidget {
  const _AiuxInputField({
    required this.name,
    this.label,
    this.placeholder,
    this.initialValue,
    this.inputType,
    this.required = false,
    this.rows,
    this.disabled = false,
  });

  final String name;
  final String? label;
  final String? placeholder;
  final String? initialValue;
  final AiuxInputType? inputType;
  final bool required;
  final int? rows;
  final bool disabled;

  @override
  State<_AiuxInputField> createState() => _AiuxInputFieldState();
}

class _AiuxInputFieldState extends State<_AiuxInputField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue ?? '');

  @override
  void didUpdateWidget(_AiuxInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // surface.updated carries a new wire value — display it; unchanged
    // values leave any local edit (and its cursor position) alone.
    if (widget.initialValue != oldWidget.initialValue) {
      final next = widget.initialValue ?? '';
      if (next != _controller.text) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() => AiuxScope.emitAction(
      context,
      AiuxAction(id: AiuxAction.fieldChange, payload: {
        'name': widget.name,
        'value': _controller.text,
      }));

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final keyboardType = switch (widget.inputType) {
      AiuxInputType.email => TextInputType.emailAddress,
      AiuxInputType.number => TextInputType.number,
      AiuxInputType.url => TextInputType.url,
      _ => TextInputType.text,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null)
          Padding(
            padding: EdgeInsets.only(bottom: theme.space(AiuxGap.xs)),
            child: Text(widget.label! + (widget.required ? ' *' : ''),
                style: theme.typography.caption.copyWith(color: colors.muted)),
          ),
        Semantics(
          label: widget.label ?? widget.name,
          textField: true,
          child: TextField(
            controller: _controller,
            enabled: !widget.disabled,
            obscureText: widget.inputType == AiuxInputType.password,
            keyboardType: keyboardType,
            minLines: widget.rows ?? 1,
            maxLines: widget.rows ?? 1,
            style: theme.typography.body,
            onChanged: (_) => _commit(),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              isDense: true,
              filled: true,
              fillColor: colors.surface,
              contentPadding: EdgeInsets.all(theme.space(AiuxGap.sm)),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(theme.radius.radius(AiuxRadius.sm)),
                borderSide: BorderSide(color: colors.border),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AiuxSelectField extends StatefulWidget {
  const _AiuxSelectField({
    required this.name,
    this.label,
    required this.options,
    this.value,
    this.placeholder,
    this.disabled = false,
  });

  final String name;
  final String? label;
  final List<AiuxSelectOption> options;
  final String? value;
  final String? placeholder;
  final bool disabled;

  @override
  State<_AiuxSelectField> createState() => _AiuxSelectFieldState();
}

class _AiuxSelectFieldState extends State<_AiuxSelectField> {
  late String _selected = widget.value ?? '';

  @override
  void didUpdateWidget(_AiuxSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _selected = widget.value ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    final colors = AiuxTheme.colorsOf(context);
    final displayLabel = widget.options
            .where((o) => o.value == _selected)
            .map((o) => o.label)
            .firstOrNull ??
        (_selected.isEmpty ? (widget.placeholder ?? 'Select…') : _selected);
    // DropdownButtonFormField asserts the value names an item — a value
    // outside `options` renders as its raw label via `hint` instead.
    final hasOption = widget.options.any((o) => o.value == _selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null)
          Padding(
            padding: EdgeInsets.only(bottom: theme.space(AiuxGap.xs)),
            child: Text(widget.label!,
                style: theme.typography.caption.copyWith(color: colors.muted)),
          ),
        Semantics(
          label: widget.label ?? widget.name,
          child: DropdownButtonFormField<String>(
            initialValue: hasOption ? _selected : null,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: colors.surface,
              contentPadding: EdgeInsets.all(theme.space(AiuxGap.xs)),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(theme.radius.radius(AiuxRadius.sm)),
                borderSide: BorderSide(color: colors.border),
              ),
            ),
            hint: Text(displayLabel,
                style: theme.typography.body
                    .copyWith(color: _selected.isEmpty ? colors.muted : null)),
            items: [
              for (final option in widget.options)
                DropdownMenuItem(
                    value: option.value, child: Text(option.label)),
            ],
            onChanged: widget.disabled
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _selected = value);
                    AiuxScope.emitAction(
                        context,
                        AiuxAction(id: AiuxAction.fieldChange, payload: {
                          'name': widget.name,
                          'value': value,
                        }));
                  },
          ),
        ),
      ],
    );
  }
}

class _AiuxCheckboxField extends StatefulWidget {
  const _AiuxCheckboxField({
    required this.name,
    required this.label,
    required this.checked,
    required this.disabled,
  });

  final String name;
  final String label;
  final bool checked;
  final bool disabled;

  @override
  State<_AiuxCheckboxField> createState() => _AiuxCheckboxFieldState();
}

class _AiuxCheckboxFieldState extends State<_AiuxCheckboxField> {
  late bool _isOn = widget.checked;

  @override
  void didUpdateWidget(_AiuxCheckboxField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checked != oldWidget.checked) {
      _isOn = widget.checked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiuxTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: _isOn,
          onChanged: widget.disabled
              ? null
              : (v) {
                  setState(() => _isOn = v ?? false);
                  AiuxScope.emitAction(
                      context,
                      AiuxAction(id: AiuxAction.fieldChange, payload: {
                        'name': widget.name,
                        'value': _isOn,
                      }));
                },
        ),
        Flexible(child: Text(widget.label, style: theme.typography.body)),
      ],
    );
  }
}
