import 'models.dart';

// MARK: - Surface Schema v1 (PLAN §6, ADR 0006)
//
// Decoding mirror of `aiux-surfaces` `SurfaceNode`/`SurfaceTree`. The
// primitive set is closed and layout values are semantic tokens — never
// pixels, percentages, or absolute coordinates. Unknown node `type` values
// decode to [AiuxUnknownNode] so a newer schema degrades to a placeholder
// instead of failing the whole tree (PLAN §21).
//
// Layout tokens (`gap`, `padding`, `radius`, `alignment`, `distribution`)
// are flattened onto the node object on the wire.

/// Semantic gap between children (`xs|sm|md|lg|xl`).
enum AiuxGap { xs, sm, md, lg, xl }

/// Semantic padding (`none|xs|sm|md|lg`).
enum AiuxPadding { none, xs, sm, md, lg }

/// Semantic corner radius (`sm|md|lg|full`).
enum AiuxRadius { sm, md, lg, full }

/// Cross-axis alignment within a container.
enum AiuxAlignment { start, center, end, stretch }

/// Main-axis distribution of children within a container.
enum AiuxDistribution {
  start,
  center,
  end,
  spaceBetween,
  spaceAround,
  spaceEvenly
}

/// Stack direction.
enum AiuxStackDirection { vertical, horizontal }

/// Semantic text variant.
enum AiuxTextVariant { body, caption, label, emphasis, strong, muted }

/// Semantic tone for badges, statuses, and emphasis.
enum AiuxTone { standard, accent, muted, success, warning, destructive }

/// Icon size (semantic, resolved by renderer theme).
enum AiuxIconSize { sm, md, lg }

/// Button hierarchy variant.
enum AiuxButtonVariant { primary, secondary, ghost, destructive }

/// Input field type (semantic; renderers map to platform keyboards).
enum AiuxInputType { text, email, number, password, url }

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<dynamic> _list(Object? v) => v is List ? v : const [];

String _str(Map<String, dynamic> m, String key, [String fallback = '']) =>
    m[key] is String ? m[key] as String : fallback;

String? _strOr(Map<String, dynamic> m, String key) =>
    m[key] is String ? m[key] as String : null;

bool _bool(Map<String, dynamic> m, String key, [bool fallback = false]) =>
    m[key] is bool ? m[key] as bool : fallback;

int? _intOr(Map<String, dynamic> m, String key) =>
    m[key] is num ? (m[key] as num).toInt() : null;

double? _doubleOr(Map<String, dynamic> m, String key) =>
    m[key] is num ? (m[key] as num).toDouble() : null;

/// Tolerant enum decode: an unrecognized token degrades to null (renderer
/// default) rather than failing the whole node.
T? _enumOr<T extends Enum>(List<T> values, Object? wire) {
  // The wire uses "default" where Dart reserves the word — map both.
  if (wire == 'default' && values.any((v) => v.name == 'standard')) {
    wire = 'standard';
  }
  if (wire is! String) return null;
  for (final v in values) {
    if (v.name == wire) return v;
  }
  return null;
}

/// A key/value row for `keyValue` nodes.
class AiuxKeyValueItem {
  const AiuxKeyValueItem({required this.key, required this.value});

  factory AiuxKeyValueItem.fromJson(Map<String, dynamic> json) =>
      AiuxKeyValueItem(key: _str(json, 'key'), value: _str(json, 'value'));

  final String key;
  final String value;
}

/// A selectable option for `select` nodes.
class AiuxSelectOption {
  const AiuxSelectOption({required this.value, required this.label});

  factory AiuxSelectOption.fromJson(Map<String, dynamic> json) =>
      AiuxSelectOption(value: _str(json, 'value'), label: _str(json, 'label'));

  final String value;
  final String label;
}

/// A `menu` entry.
class AiuxMenuItem {
  const AiuxMenuItem({
    required this.label,
    required this.action,
    this.icon,
    this.disabled = false,
  });

  factory AiuxMenuItem.fromJson(Map<String, dynamic> json) => AiuxMenuItem(
        label: _str(json, 'label'),
        action: json['action'] is Map
            ? AiuxAction.fromJson(_map(json['action']))
            : const AiuxAction(id: 'aiux.unresolved'),
        icon: _strOr(json, 'icon'),
        disabled: _bool(json, 'disabled'),
      );

  final String label;
  final AiuxAction action;
  final String? icon;
  final bool disabled;
}

/// Semantic layout properties shared by every node.
class AiuxNodeLayout {
  const AiuxNodeLayout({
    this.gap,
    this.padding,
    this.radius,
    this.alignment,
    this.distribution,
  });

  /// Layout tokens decode from the node's own object (flattened on the wire);
  /// unrecognized tokens degrade to null per PLAN §21.
  factory AiuxNodeLayout.fromJson(Map<String, dynamic> json) => AiuxNodeLayout(
        gap: _enumOr(AiuxGap.values, json['gap']),
        padding: _enumOr(AiuxPadding.values, json['padding']),
        radius: _enumOr(AiuxRadius.values, json['radius']),
        alignment: _enumOr(AiuxAlignment.values, json['alignment']),
        distribution: _enumOr(AiuxDistribution.values, json['distribution']),
      );

  final AiuxGap? gap;
  final AiuxPadding? padding;
  final AiuxRadius? radius;
  final AiuxAlignment? alignment;
  final AiuxDistribution? distribution;
}

List<AiuxSurfaceNode> _children(Map<String, dynamic> json) =>
    _list(json['children'])
        .map((e) => AiuxSurfaceNode.fromJson(_map(e)))
        .toList();

/// AIUX Surface Schema v1 node, serialized as `{"type": "<kind>", ...}`.
sealed class AiuxSurfaceNode {
  const AiuxSurfaceNode({this.layout = const AiuxNodeLayout()});

  final AiuxNodeLayout layout;

  /// Discriminant name as it appears on the wire.
  String get kind;

  /// Direct children of this node (empty for leaves).
  List<AiuxSurfaceNode> get children => const [];

  /// Tolerant decode: semantic errors degrade to [AiuxUnknownNode] /
  /// renderer defaults; only a malformed payload shape throws.
  factory AiuxSurfaceNode.fromJson(Map<String, dynamic> json) {
    final type = _str(json, 'type');
    final layout = AiuxNodeLayout.fromJson(json);
    switch (type) {
      case 'surface':
        return AiuxSurface(children: _children(json), layout: layout);
      case 'card':
        return AiuxCard(
            children: _children(json),
            title: _strOr(json, 'title'),
            layout: layout);
      case 'stack':
        return AiuxStack(
            children: _children(json),
            direction: _enumOr(AiuxStackDirection.values, json['direction']),
            layout: layout);
      case 'row':
        return AiuxRow(children: _children(json), layout: layout);
      case 'grid':
        final columns = _intOr(json, 'columns') ?? 2;
        return AiuxGrid(
            children: _children(json),
            columns: columns < 1 ? 1 : columns,
            layout: layout);
      case 'heading':
        return AiuxHeading(
            text: _str(json, 'text'),
            level: _intOr(json, 'level'),
            layout: layout);
      case 'text':
        return AiuxText(
            text: _str(json, 'text'),
            variant: _enumOr(AiuxTextVariant.values, json['variant']),
            layout: layout);
      case 'markdown':
        return AiuxMarkdown(markdown: _str(json, 'markdown'), layout: layout);
      case 'code':
        return AiuxCode(
            code: _str(json, 'code'),
            language: _strOr(json, 'language'),
            layout: layout);
      case 'icon':
        return AiuxIcon(
            name: _str(json, 'name'),
            size: _enumOr(AiuxIconSize.values, json['size']),
            layout: layout);
      case 'image':
        return AiuxImage(
            src: _str(json, 'src'), alt: _strOr(json, 'alt'), layout: layout);
      case 'badge':
        return AiuxBadge(
            text: _str(json, 'text'),
            tone: _enumOr(AiuxTone.values, json['tone']),
            layout: layout);
      case 'divider':
        return AiuxDivider(layout: layout);
      case 'spacer':
        return AiuxSpacer(
            size: _enumOr(AiuxGap.values, json['size']), layout: layout);
      case 'keyValue':
        return AiuxKeyValue(
            items: _list(json['items'])
                .map((e) => AiuxKeyValueItem.fromJson(_map(e)))
                .toList(),
            layout: layout);
      case 'list':
        return AiuxList(
            children: _children(json),
            ordered: _bool(json, 'ordered'),
            layout: layout);
      case 'table':
        return AiuxTable(
            headers: _list(json['headers']).map((e) => e.toString()).toList(),
            rows: _list(json['rows'])
                .map((r) => _list(r).map((e) => e.toString()).toList())
                .toList(),
            caption: _strOr(json, 'caption'),
            layout: layout);
      case 'button':
        return AiuxButton(
            label: _str(json, 'label'),
            action: json['action'] is Map
                ? AiuxAction.fromJson(_map(json['action']))
                : const AiuxAction(id: 'aiux.unresolved'),
            variant: _enumOr(AiuxButtonVariant.values, json['variant']),
            disabled: _bool(json, 'disabled'),
            layout: layout);
      case 'menu':
        return AiuxMenu(
            label: _strOr(json, 'label'),
            items: _list(json['items'])
                .map((e) => AiuxMenuItem.fromJson(_map(e)))
                .toList(),
            layout: layout);
      case 'progress':
        return AiuxProgressNode(
            value: _doubleOr(json, 'value'),
            max: _doubleOr(json, 'max'),
            label: _strOr(json, 'label'),
            layout: layout);
      case 'status':
        return AiuxStatus(
            text: _str(json, 'text'),
            tone: _enumOr(AiuxTone.values, json['tone']),
            layout: layout);
      case 'input':
        return AiuxInput(
            name: _str(json, 'name'),
            label: _strOr(json, 'label'),
            placeholder: _strOr(json, 'placeholder'),
            value: _strOr(json, 'value'),
            inputType: _enumOr(AiuxInputType.values, json['inputType']),
            required: _bool(json, 'required'),
            disabled: _bool(json, 'disabled'),
            layout: layout);
      case 'textarea':
        return AiuxTextarea(
            name: _str(json, 'name'),
            label: _strOr(json, 'label'),
            placeholder: _strOr(json, 'placeholder'),
            value: _strOr(json, 'value'),
            rows: _intOr(json, 'rows'),
            disabled: _bool(json, 'disabled'),
            layout: layout);
      case 'select':
        return AiuxSelect(
            name: _str(json, 'name'),
            label: _strOr(json, 'label'),
            options: _list(json['options'])
                .map((e) => AiuxSelectOption.fromJson(_map(e)))
                .toList(),
            value: _strOr(json, 'value'),
            placeholder: _strOr(json, 'placeholder'),
            disabled: _bool(json, 'disabled'),
            layout: layout);
      case 'checkbox':
        return AiuxCheckbox(
            name: _str(json, 'name'),
            label: _str(json, 'label'),
            checked: _bool(json, 'checked'),
            disabled: _bool(json, 'disabled'),
            layout: layout);
      case 'actions':
        return AiuxActions(children: _children(json), layout: layout);
      default:
        return AiuxUnknownNode(type: type.isEmpty ? 'missing-type' : type);
    }
  }
}

/// Root surface container. Only valid as the tree root.
class AiuxSurface extends AiuxSurfaceNode {
  const AiuxSurface({required this.children, super.layout});
  @override
  final List<AiuxSurfaceNode> children;
  @override
  String get kind => 'surface';
}

/// Grouped content container.
class AiuxCard extends AiuxSurfaceNode {
  const AiuxCard({required this.children, this.title, super.layout});
  @override
  final List<AiuxSurfaceNode> children;
  final String? title;
  @override
  String get kind => 'card';
}

/// Vertical or horizontal stack.
class AiuxStack extends AiuxSurfaceNode {
  const AiuxStack({required this.children, this.direction, super.layout});
  @override
  final List<AiuxSurfaceNode> children;
  final AiuxStackDirection? direction;
  @override
  String get kind => 'stack';
}

/// Horizontal row (stack shorthand).
class AiuxRow extends AiuxSurfaceNode {
  const AiuxRow({required this.children, super.layout});
  @override
  final List<AiuxSurfaceNode> children;
  @override
  String get kind => 'row';
}

/// Fixed-column grid.
class AiuxGrid extends AiuxSurfaceNode {
  const AiuxGrid({required this.children, required this.columns, super.layout});
  @override
  final List<AiuxSurfaceNode> children;
  final int columns;
  @override
  String get kind => 'grid';
}

/// Section heading.
class AiuxHeading extends AiuxSurfaceNode {
  const AiuxHeading({required this.text, this.level, super.layout});
  final String text;
  final int? level;
  @override
  String get kind => 'heading';
}

/// Plain text.
class AiuxText extends AiuxSurfaceNode {
  const AiuxText({required this.text, this.variant, super.layout});
  final String text;
  final AiuxTextVariant? variant;
  @override
  String get kind => 'text';
}

/// Markdown content.
class AiuxMarkdown extends AiuxSurfaceNode {
  const AiuxMarkdown({required this.markdown, super.layout});
  final String markdown;
  @override
  String get kind => 'markdown';
}

/// Code block.
class AiuxCode extends AiuxSurfaceNode {
  const AiuxCode({required this.code, this.language, super.layout});
  final String code;
  final String? language;
  @override
  String get kind => 'code';
}

/// Named icon.
class AiuxIcon extends AiuxSurfaceNode {
  const AiuxIcon({required this.name, this.size, super.layout});
  final String name;
  final AiuxIconSize? size;
  @override
  String get kind => 'icon';
}

/// Image by URI.
class AiuxImage extends AiuxSurfaceNode {
  const AiuxImage({required this.src, this.alt, super.layout});
  final String src;
  final String? alt;
  @override
  String get kind => 'image';
}

/// Small labelled indicator.
class AiuxBadge extends AiuxSurfaceNode {
  const AiuxBadge({required this.text, this.tone, super.layout});
  final String text;
  final AiuxTone? tone;
  @override
  String get kind => 'badge';
}

/// Visual separator.
class AiuxDivider extends AiuxSurfaceNode {
  const AiuxDivider({super.layout});
  @override
  String get kind => 'divider';
}

/// Flexible whitespace.
class AiuxSpacer extends AiuxSurfaceNode {
  const AiuxSpacer({this.size, super.layout});
  final AiuxGap? size;
  @override
  String get kind => 'spacer';
}

/// Key/value pairs.
class AiuxKeyValue extends AiuxSurfaceNode {
  const AiuxKeyValue({required this.items, super.layout});
  final List<AiuxKeyValueItem> items;
  @override
  String get kind => 'keyValue';
}

/// Ordered or unordered list of nodes.
class AiuxList extends AiuxSurfaceNode {
  const AiuxList({required this.children, required this.ordered, super.layout});
  @override
  final List<AiuxSurfaceNode> children;
  final bool ordered;
  @override
  String get kind => 'list';
}

/// Semantic table.
class AiuxTable extends AiuxSurfaceNode {
  const AiuxTable({
    required this.headers,
    required this.rows,
    this.caption,
    super.layout,
  });
  final List<String> headers;
  final List<List<String>> rows;
  final String? caption;
  @override
  String get kind => 'table';
}

/// Action button.
class AiuxButton extends AiuxSurfaceNode {
  const AiuxButton({
    required this.label,
    required this.action,
    this.variant,
    required this.disabled,
    super.layout,
  });
  final String label;
  final AiuxAction action;
  final AiuxButtonVariant? variant;
  final bool disabled;
  @override
  String get kind => 'button';
}

/// Overflow/dropdown menu of actions.
class AiuxMenu extends AiuxSurfaceNode {
  const AiuxMenu({this.label, required this.items, super.layout});
  final String? label;
  final List<AiuxMenuItem> items;
  @override
  String get kind => 'menu';
}

/// Progress indicator.
class AiuxProgressNode extends AiuxSurfaceNode {
  const AiuxProgressNode({this.value, this.max, this.label, super.layout});
  final double? value;
  final double? max;
  final String? label;
  @override
  String get kind => 'progress';
}

/// Inline status line.
class AiuxStatus extends AiuxSurfaceNode {
  const AiuxStatus({required this.text, this.tone, super.layout});
  final String text;
  final AiuxTone? tone;
  @override
  String get kind => 'status';
}

/// Single-line input field.
class AiuxInput extends AiuxSurfaceNode {
  const AiuxInput({
    required this.name,
    this.label,
    this.placeholder,
    this.value,
    this.inputType,
    required this.required,
    required this.disabled,
    super.layout,
  });
  final String name;
  final String? label;
  final String? placeholder;
  final String? value;
  final AiuxInputType? inputType;
  final bool required;
  final bool disabled;
  @override
  String get kind => 'input';
}

/// Multi-line input field.
class AiuxTextarea extends AiuxSurfaceNode {
  const AiuxTextarea({
    required this.name,
    this.label,
    this.placeholder,
    this.value,
    this.rows,
    required this.disabled,
    super.layout,
  });
  final String name;
  final String? label;
  final String? placeholder;
  final String? value;
  final int? rows;
  final bool disabled;
  @override
  String get kind => 'textarea';
}

/// Single-choice dropdown.
class AiuxSelect extends AiuxSurfaceNode {
  const AiuxSelect({
    required this.name,
    this.label,
    required this.options,
    this.value,
    this.placeholder,
    required this.disabled,
    super.layout,
  });
  final String name;
  final String? label;
  final List<AiuxSelectOption> options;
  final String? value;
  final String? placeholder;
  final bool disabled;
  @override
  String get kind => 'select';
}

/// Boolean checkbox.
class AiuxCheckbox extends AiuxSurfaceNode {
  const AiuxCheckbox({
    required this.name,
    required this.label,
    required this.checked,
    required this.disabled,
    super.layout,
  });
  final String name;
  final String label;
  final bool checked;
  final bool disabled;
  @override
  String get kind => 'checkbox';
}

/// Action row/container; children are `button`/`menu` nodes.
class AiuxActions extends AiuxSurfaceNode {
  const AiuxActions({required this.children, super.layout});
  @override
  final List<AiuxSurfaceNode> children;
  @override
  String get kind => 'actions';
}

/// A node kind this renderer doesn't know — rendered as a placeholder.
class AiuxUnknownNode extends AiuxSurfaceNode {
  const AiuxUnknownNode({required this.type});
  final String type;
  @override
  String get kind => type;
}

/// A surface: a named, revisioned semantic node tree.
class AiuxSurfaceTree {
  const AiuxSurfaceTree({
    required this.id,
    required this.root,
    this.name,
    this.revision = 0,
  });

  factory AiuxSurfaceTree.fromJson(Map<String, dynamic> json) =>
      AiuxSurfaceTree(
        id: _str(json, 'id'),
        name: _strOr(json, 'name'),
        revision: _intOr(json, 'revision') ?? 0,
        root: AiuxSurfaceNode.fromJson(_map(json['root'])),
      );

  /// Stable surface identifier.
  final String id;

  /// Optional human-facing name.
  final String? name;

  /// Monotonic revision; bumps on every `surface.updated`.
  final int revision;

  /// Root node — a `surface` node per the schema.
  final AiuxSurfaceNode root;
}
