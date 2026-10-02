import Foundation

// MARK: - Surface Schema v1 (plan §6, ADR 0006)
//
// Decodable mirror of `aiux-surfaces` `SurfaceNode`/`SurfaceTree`. The
// primitive set is closed and layout values are semantic tokens — never
// pixels, percentages, or absolute coordinates. Unknown node `type` values
// decode to `.unknown` so a newer schema degrades to a placeholder instead of
// failing the whole tree (plan §21).

/// Semantic gap between children (`xs|sm|md|lg|xl`).
public enum AIUXGap: String, Decodable, Sendable {
    case xs, sm, md, lg, xl
}

/// Semantic padding (`none|xs|sm|md|lg`).
public enum AIUXPadding: String, Decodable, Sendable {
    case none, xs, sm, md, lg
}

/// Semantic corner radius (`sm|md|lg|full`).
public enum AIUXRadius: String, Decodable, Sendable {
    case sm, md, lg, full
}

/// Cross-axis alignment within a container.
public enum AIUXAlignment: String, Decodable, Sendable {
    case start, center, end, stretch
}

/// Main-axis distribution of children within a container.
public enum AIUXDistribution: String, Decodable, Sendable {
    case start, center, end, spaceBetween, spaceAround, spaceEvenly
}

/// Stack direction.
public enum AIUXStackDirection: String, Decodable, Sendable {
    case vertical, horizontal
}

/// Semantic text variant.
public enum AIUXTextVariant: String, Decodable, Sendable {
    case body, caption, label, emphasis, strong, muted
}

/// Semantic tone for badges, statuses, and emphasis.
public enum AIUXTone: String, Decodable, Sendable {
    case `default`, accent, muted, success, warning, destructive
}

/// Icon size (semantic, resolved by renderer theme).
public enum AIUXIconSize: String, Decodable, Sendable {
    case sm, md, lg
}

/// Button hierarchy variant.
public enum AIUXButtonVariant: String, Decodable, Sendable {
    case primary, secondary, ghost, destructive
}

/// Input field type (semantic; renderers map to platform keyboards).
public enum AIUXInputType: String, Decodable, Sendable {
    case text, email, number, password, url
}

/// A key/value row for `keyValue` nodes.
public struct AIUXKeyValueItem: Equatable, Decodable, Sendable {
    public var key: String
    public var value: String
    /// Semantic tone applied to the value (ADR 0007).
    public var tone: AIUXTone?
}

/// A selectable option for `select` nodes.
public struct AIUXSelectOption: Equatable, Decodable, Sendable {
    public var value: String
    public var label: String
}

/// Table column alignment (ADR 0007).
public enum AIUXColumnAlign: String, Decodable, Sendable {
    case start, center, end
}

/// A `table` column descriptor (ADR 0007).
public struct AIUXTableColumn: Equatable, Decodable, Sendable {
    public var key: String
    public var title: String
    public var align: AIUXColumnAlign?
}

/// A typed `table` cell — `{"type": ...}` on the wire; a bare string decodes
/// as `.text` (ADR 0007).
public enum AIUXTableCell: Equatable, Sendable {
    case text(String)
    case number(Double)
    case badge(text: String, tone: AIUXTone?)
    case action(label: String, action: AIUXAction)
}

extension AIUXTableCell: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type, text, value, tone, label, action
    }

    public init(from decoder: Decoder) throws {
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            self = .text(s)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decodeIfPresent(String.self, forKey: .type) ?? "text" {
        case "text":
            self = .text(try c.decodeIfPresent(String.self, forKey: .text) ?? "")
        case "number":
            self = .number(try c.decodeIfPresent(Double.self, forKey: .value) ?? 0)
        case "badge":
            self = .badge(
                text: try c.decodeIfPresent(String.self, forKey: .text) ?? "",
                tone: (try? c.decodeIfPresent(AIUXTone.self, forKey: .tone)) ?? nil
            )
        case "action":
            self = .action(
                label: try c.decodeIfPresent(String.self, forKey: .label) ?? "",
                action: (try? c.decodeIfPresent(AIUXAction.self, forKey: .action))
                    ?? AIUXAction(id: "aiux.unresolved")
            )
        default:
            self = .text("")
        }
    }
}

/// A `menu` entry.
public struct AIUXMenuItem: Equatable, Decodable, Sendable {
    public var label: String
    public var action: AIUXAction
    public var icon: String?
    public var disabled: Bool = false

    private enum CodingKeys: String, CodingKey { case label, action, icon, disabled }

    /// `disabled` defaults to false on the wire.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decode(String.self, forKey: .label)
        action = try c.decode(AIUXAction.self, forKey: .action)
        icon = try c.decodeIfPresent(String.self, forKey: .icon)
        disabled = try c.decodeIfPresent(Bool.self, forKey: .disabled) ?? false
    }
}

/// Semantic layout properties shared by every node.
public struct AIUXNodeLayout: Equatable, Sendable {
    public var gap: AIUXGap?
    public var padding: AIUXPadding?
    public var radius: AIUXRadius?
    public var alignment: AIUXAlignment?
    public var distribution: AIUXDistribution?

    public init() {}
}

extension AIUXNodeLayout: Decodable {
    private enum CodingKeys: String, CodingKey {
        case gap, padding, radius, alignment, distribution
    }

    /// Tolerant decode: an unrecognized token degrades to `nil` (renderer
    /// default) rather than failing the whole node.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gap = (try? c.decodeIfPresent(AIUXGap.self, forKey: .gap)) ?? nil
        padding = (try? c.decodeIfPresent(AIUXPadding.self, forKey: .padding)) ?? nil
        radius = (try? c.decodeIfPresent(AIUXRadius.self, forKey: .radius)) ?? nil
        alignment = (try? c.decodeIfPresent(AIUXAlignment.self, forKey: .alignment)) ?? nil
        distribution = (try? c.decodeIfPresent(AIUXDistribution.self, forKey: .distribution)) ?? nil
    }
}

/// AIUX Surface Schema v1 node, serialized as `{"type": "<kind>", ...}`.
public enum AIUXSurfaceNode: Equatable, Sendable {
    /// Root surface container. Only valid as the tree root.
    case surface(children: [AIUXSurfaceNode], layout: AIUXNodeLayout)
    /// Grouped content container.
    case card(children: [AIUXSurfaceNode], title: String?, layout: AIUXNodeLayout)
    /// Vertical or horizontal stack.
    case stack(children: [AIUXSurfaceNode], direction: AIUXStackDirection?, layout: AIUXNodeLayout)
    /// Horizontal row (stack shorthand).
    case row(children: [AIUXSurfaceNode], layout: AIUXNodeLayout)
    /// Fixed-column grid.
    case grid(children: [AIUXSurfaceNode], columns: Int, layout: AIUXNodeLayout)
    /// Section heading.
    case heading(text: String, level: Int?, layout: AIUXNodeLayout)
    /// Plain text.
    case text(text: String, variant: AIUXTextVariant?, layout: AIUXNodeLayout)
    /// Markdown content.
    case markdown(markdown: String, layout: AIUXNodeLayout)
    /// Code block.
    case code(code: String, language: String?, layout: AIUXNodeLayout)
    /// Named icon.
    case icon(name: String, size: AIUXIconSize?, layout: AIUXNodeLayout)
    /// Image by URI.
    case image(src: String, alt: String?, layout: AIUXNodeLayout)
    /// Small labelled indicator.
    case badge(text: String, tone: AIUXTone?, icon: String?, layout: AIUXNodeLayout)
    /// Visual separator.
    case divider(layout: AIUXNodeLayout)
    /// Flexible whitespace.
    case spacer(size: AIUXGap?, layout: AIUXNodeLayout)
    /// Key/value pairs.
    case keyValue(items: [AIUXKeyValueItem], layout: AIUXNodeLayout)
    /// Ordered or unordered list of nodes.
    case list(children: [AIUXSurfaceNode], ordered: Bool, layout: AIUXNodeLayout)
    /// Structured list row — direct child of `list` only (ADR 0007).
    case listItem(title: String, subtitle: String?, icon: String?, action: AIUXAction?, children: [AIUXSurfaceNode], layout: AIUXNodeLayout)
    /// Semantic table.
    case table(headers: [String], columns: [AIUXTableColumn], rows: [[AIUXTableCell]], caption: String?, layout: AIUXNodeLayout)
    /// Action button.
    case button(label: String, action: AIUXAction, variant: AIUXButtonVariant?, disabled: Bool, layout: AIUXNodeLayout)
    /// Overflow/dropdown menu of actions.
    case menu(label: String?, items: [AIUXMenuItem], layout: AIUXNodeLayout)
    /// Progress indicator.
    case progress(value: Double?, max: Double?, label: String?, layout: AIUXNodeLayout)
    /// Inline status line.
    case status(text: String, tone: AIUXTone?, layout: AIUXNodeLayout)
    /// Single-line input field.
    case input(name: String, label: String?, placeholder: String?, value: String?, inputType: AIUXInputType?, required: Bool, disabled: Bool, errorText: String?, layout: AIUXNodeLayout)
    /// Multi-line input field.
    case textarea(name: String, label: String?, placeholder: String?, value: String?, rows: Int?, required: Bool, disabled: Bool, errorText: String?, layout: AIUXNodeLayout)
    /// Single-choice dropdown.
    case select(name: String, label: String?, options: [AIUXSelectOption], value: String?, placeholder: String?, required: Bool, disabled: Bool, errorText: String?, layout: AIUXNodeLayout)
    /// Boolean checkbox.
    case checkbox(name: String, label: String, checked: Bool, required: Bool, disabled: Bool, errorText: String?, layout: AIUXNodeLayout)
    /// Single-choice option group (ADR 0007).
    case radio(name: String, label: String?, options: [AIUXSelectOption], value: String?, required: Bool, disabled: Bool, errorText: String?, layout: AIUXNodeLayout)
    /// Labelled field wrapper — label/helper/error around children (ADR 0007).
    case field(children: [AIUXSurfaceNode], label: String?, helperText: String?, required: Bool, disabled: Bool, errorText: String?, layout: AIUXNodeLayout)
    /// Form scope — submit emits its `AIUXAction` with collected `fields`
    /// folded into the payload (ADR 0007).
    case form(children: [AIUXSurfaceNode], submit: AIUXAction, submitLabel: String?, disabled: Bool, layout: AIUXNodeLayout)
    /// Action row/container; children are `button`/`menu` nodes.
    case actions(children: [AIUXSurfaceNode], layout: AIUXNodeLayout)
    /// Host-registered custom node kind (ADR 0007).
    case custom(kind: String, props: [String: AIUXJSONValue], children: [AIUXSurfaceNode], layout: AIUXNodeLayout)
    /// A node kind this renderer doesn't know — rendered as a placeholder.
    case unknown(type: String)

    /// Discriminant name as it appears on the wire.
    public var kind: String {
        switch self {
        case .surface: return "surface"
        case .card: return "card"
        case .stack: return "stack"
        case .row: return "row"
        case .grid: return "grid"
        case .heading: return "heading"
        case .text: return "text"
        case .markdown: return "markdown"
        case .code: return "code"
        case .icon: return "icon"
        case .image: return "image"
        case .badge: return "badge"
        case .divider: return "divider"
        case .spacer: return "spacer"
        case .keyValue: return "keyValue"
        case .list: return "list"
        case .table: return "table"
        case .button: return "button"
        case .menu: return "menu"
        case .progress: return "progress"
        case .status: return "status"
        case .input: return "input"
        case .textarea: return "textarea"
        case .select: return "select"
        case .checkbox: return "checkbox"
        case .radio: return "radio"
        case .field: return "field"
        case .form: return "form"
        case .listItem: return "listItem"
        case .custom: return "custom"
        case .actions: return "actions"
        case .unknown(let type): return type
        }
    }

    /// Direct children of this node (empty for leaves).
    public var children: [AIUXSurfaceNode] {
        switch self {
        case .surface(let children, _),
             .card(let children, _, _),
             .stack(let children, _, _),
             .row(let children, _),
             .grid(let children, _, _),
             .list(let children, _, _),
             .field(let children, _, _, _, _, _, _),
             .form(let children, _, _, _, _),
             .listItem(_, _, _, _, let children, _),
             .custom(_, _, let children, _),
             .actions(let children, _):
            return children
        default:
            return []
        }
    }

    /// Shared layout properties (empty for nodes that carry none).
    public var layout: AIUXNodeLayout {
        switch self {
        case .surface(_, let l), .row(_, let l), .divider(let l),
             .markdown(_, let l), .spacer(_, let l), .keyValue(_, let l),
             .menu(_, _, let l), .actions(_, let l),
             .card(_, _, let l), .stack(_, _, let l), .grid(_, _, let l),
             .heading(_, _, let l), .text(_, _, let l), .code(_, _, let l),
             .icon(_, _, let l), .image(_, _, let l), .badge(_, _, let l),
             .list(_, _, let l), .table(_, _, _, _, let l),
             .progress(_, _, _, let l), .status(_, _, let l),
             .button(_, _, _, _, let l), .checkbox(_, _, _, _, _, _, let l),
             .input(_, _, _, _, _, _, _, _, let l), .select(_, _, _, _, _, _, _, _, let l),
             .textarea(_, _, _, _, _, _, _, _, let l),
             .radio(_, _, _, _, _, _, _, let l),
             .field(_, _, _, _, _, _, let l), .form(_, _, _, _, let l),
             .listItem(_, _, _, _, _, let l), .custom(_, _, _, let l):
            return l
        case .unknown:
            return AIUXNodeLayout()
        }
    }
}

extension AIUXSurfaceNode: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case children, direction, columns, text, level, variant, markdown, code
        case language, name, size, src, alt, tone, items, ordered, headers, rows
        case caption, label, action, disabled, value, max, inputType, required
        case placeholder, checked, title, options
        case errorText, helperText, submit, submitLabel, kind, props, subtitle
        case icon
    }

    /// Tolerant decode: semantic errors degrade to `.unknown` / renderer
    /// defaults; only a malformed payload shape (e.g. children not an array)
    /// throws.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        let layout = (try? AIUXNodeLayout(from: decoder)) ?? AIUXNodeLayout()
        func children() throws -> [AIUXSurfaceNode] {
            try c.decodeIfPresent([AIUXSurfaceNode].self, forKey: .children) ?? []
        }

        switch type {
        case "surface":
            self = .surface(children: try children(), layout: layout)
        case "card":
            self = .card(
                children: try children(),
                title: try c.decodeIfPresent(String.self, forKey: .title),
                layout: layout
            )
        case "stack":
            self = .stack(
                children: try children(),
                direction: (try? c.decodeIfPresent(AIUXStackDirection.self, forKey: .direction)) ?? nil,
                layout: layout
            )
        case "row":
            self = .row(children: try children(), layout: layout)
        case "grid":
            let columns = (try? c.decodeIfPresent(Int.self, forKey: .columns)) ?? nil
            self = .grid(children: try children(), columns: max(columns ?? 2, 1), layout: layout)
        case "heading":
            self = .heading(
                text: try c.decodeIfPresent(String.self, forKey: .text) ?? "",
                level: (try? c.decodeIfPresent(Int.self, forKey: .level)) ?? nil,
                layout: layout
            )
        case "text":
            self = .text(
                text: try c.decodeIfPresent(String.self, forKey: .text) ?? "",
                variant: (try? c.decodeIfPresent(AIUXTextVariant.self, forKey: .variant)) ?? nil,
                layout: layout
            )
        case "markdown":
            self = .markdown(
                markdown: try c.decodeIfPresent(String.self, forKey: .markdown) ?? "",
                layout: layout
            )
        case "code":
            self = .code(
                code: try c.decodeIfPresent(String.self, forKey: .code) ?? "",
                language: try c.decodeIfPresent(String.self, forKey: .language),
                layout: layout
            )
        case "icon":
            self = .icon(
                name: try c.decodeIfPresent(String.self, forKey: .name) ?? "",
                size: (try? c.decodeIfPresent(AIUXIconSize.self, forKey: .size)) ?? nil,
                layout: layout
            )
        case "image":
            self = .image(
                src: try c.decodeIfPresent(String.self, forKey: .src) ?? "",
                alt: try c.decodeIfPresent(String.self, forKey: .alt),
                layout: layout
            )
        case "badge":
            self = .badge(
                text: try c.decodeIfPresent(String.self, forKey: .text) ?? "",
                tone: (try? c.decodeIfPresent(AIUXTone.self, forKey: .tone)) ?? nil,
                icon: try c.decodeIfPresent(String.self, forKey: .icon),
                layout: layout
            )
        case "divider":
            self = .divider(layout: layout)
        case "spacer":
            self = .spacer(
                size: (try? c.decodeIfPresent(AIUXGap.self, forKey: .size)) ?? nil,
                layout: layout
            )
        case "keyValue":
            self = .keyValue(
                items: (try? c.decodeIfPresent([AIUXKeyValueItem].self, forKey: .items)) ?? [],
                layout: layout
            )
        case "list":
            self = .list(
                children: try children(),
                ordered: (try? c.decodeIfPresent(Bool.self, forKey: .ordered)) ?? false,
                layout: layout
            )
        case "table":
            let headers = (try? c.decodeIfPresent([String].self, forKey: .headers)) ?? []
            let columns = (try? c.decodeIfPresent([AIUXTableColumn].self, forKey: .columns)) ?? []
            let rows = (try? c.decodeIfPresent([[AIUXTableCell]].self, forKey: .rows)) ?? []
            let caption = try c.decodeIfPresent(String.self, forKey: .caption)
            self = .table(
                headers: headers, columns: columns, rows: rows,
                caption: caption, layout: layout
            )
        case "button":
            let label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
            let action = (try? c.decodeIfPresent(AIUXAction.self, forKey: .action))
                ?? AIUXAction(id: "aiux.unresolved")
            let variant = (try? c.decodeIfPresent(AIUXButtonVariant.self, forKey: .variant)) ?? nil
            let disabled = (try? c.decodeIfPresent(Bool.self, forKey: .disabled)) ?? false
            self = .button(
                label: label, action: action, variant: variant,
                disabled: disabled, layout: layout
            )
        case "menu":
            let label = try c.decodeIfPresent(String.self, forKey: .label)
            let items = (try? c.decodeIfPresent([AIUXMenuItem].self, forKey: .items)) ?? []
            self = .menu(label: label, items: items, layout: layout)
        case "progress":
            let value = (try? c.decodeIfPresent(Double.self, forKey: .value)) ?? nil
            let maxValue = (try? c.decodeIfPresent(Double.self, forKey: .max)) ?? nil
            let label = try c.decodeIfPresent(String.self, forKey: .label)
            self = .progress(value: value, max: maxValue, label: label, layout: layout)
        case "status":
            let text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
            let tone = (try? c.decodeIfPresent(AIUXTone.self, forKey: .tone)) ?? nil
            self = .status(text: text, tone: tone, layout: layout)
        case "input":
            let name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            let label = try c.decodeIfPresent(String.self, forKey: .label)
            let placeholder = try c.decodeIfPresent(String.self, forKey: .placeholder)
            let value = try c.decodeIfPresent(String.self, forKey: .value)
            let inputType = (try? c.decodeIfPresent(AIUXInputType.self, forKey: .inputType)) ?? nil
            let required = (try? c.decodeIfPresent(Bool.self, forKey: .required)) ?? false
            let disabled = (try? c.decodeIfPresent(Bool.self, forKey: .disabled)) ?? false
            self = .input(
                name: name, label: label, placeholder: placeholder, value: value,
                inputType: inputType, required: required, disabled: disabled,
                errorText: try c.decodeIfPresent(String.self, forKey: .errorText),
                layout: layout
            )
        case "textarea":
            let name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            let label = try c.decodeIfPresent(String.self, forKey: .label)
            let placeholder = try c.decodeIfPresent(String.self, forKey: .placeholder)
            let value = try c.decodeIfPresent(String.self, forKey: .value)
            let rows = (try? c.decodeIfPresent(Int.self, forKey: .rows)) ?? nil
            let required = (try? c.decodeIfPresent(Bool.self, forKey: .required)) ?? false
            let disabled = (try? c.decodeIfPresent(Bool.self, forKey: .disabled)) ?? false
            self = .textarea(
                name: name, label: label, placeholder: placeholder, value: value,
                rows: rows, required: required, disabled: disabled,
                errorText: try c.decodeIfPresent(String.self, forKey: .errorText),
                layout: layout
            )
        case "select":
            let name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
            let label = try c.decodeIfPresent(String.self, forKey: .label)
            let options = (try? c.decodeIfPresent([AIUXSelectOption].self, forKey: .options)) ?? []
            let value = try c.decodeIfPresent(String.self, forKey: .value)
            let placeholder = try c.decodeIfPresent(String.self, forKey: .placeholder)
            let required = (try? c.decodeIfPresent(Bool.self, forKey: .required)) ?? false
            let disabled = (try? c.decodeIfPresent(Bool.self, forKey: .disabled)) ?? false
            self = .select(
                name: name, label: label, options: options, value: value,
                placeholder: placeholder, required: required, disabled: disabled,
                errorText: try c.decodeIfPresent(String.self, forKey: .errorText),
                layout: layout
            )
        case "checkbox":
            self = .checkbox(
                name: try c.decodeIfPresent(String.self, forKey: .name) ?? "",
                label: try c.decodeIfPresent(String.self, forKey: .label) ?? "",
                checked: (try? c.decodeIfPresent(Bool.self, forKey: .checked)) ?? false,
                required: (try? c.decodeIfPresent(Bool.self, forKey: .required)) ?? false,
                disabled: (try? c.decodeIfPresent(Bool.self, forKey: .disabled)) ?? false,
                errorText: try c.decodeIfPresent(String.self, forKey: .errorText),
                layout: layout
            )
        case "radio":
            self = .radio(
                name: try c.decodeIfPresent(String.self, forKey: .name) ?? "",
                label: try c.decodeIfPresent(String.self, forKey: .label),
                options: (try? c.decodeIfPresent([AIUXSelectOption].self, forKey: .options)) ?? [],
                value: try c.decodeIfPresent(String.self, forKey: .value),
                required: (try? c.decodeIfPresent(Bool.self, forKey: .required)) ?? false,
                disabled: (try? c.decodeIfPresent(Bool.self, forKey: .disabled)) ?? false,
                errorText: try c.decodeIfPresent(String.self, forKey: .errorText),
                layout: layout
            )
        case "field":
            self = .field(
                children: try children(),
                label: try c.decodeIfPresent(String.self, forKey: .label),
                helperText: try c.decodeIfPresent(String.self, forKey: .helperText),
                required: (try? c.decodeIfPresent(Bool.self, forKey: .required)) ?? false,
                disabled: (try? c.decodeIfPresent(Bool.self, forKey: .disabled)) ?? false,
                errorText: try c.decodeIfPresent(String.self, forKey: .errorText),
                layout: layout
            )
        case "form":
            self = .form(
                children: try children(),
                submit: (try? c.decodeIfPresent(AIUXAction.self, forKey: .submit))
                    ?? AIUXAction(id: "aiux.unresolved"),
                submitLabel: try c.decodeIfPresent(String.self, forKey: .submitLabel),
                disabled: (try? c.decodeIfPresent(Bool.self, forKey: .disabled)) ?? false,
                layout: layout
            )
        case "listItem":
            self = .listItem(
                title: try c.decodeIfPresent(String.self, forKey: .title) ?? "",
                subtitle: try c.decodeIfPresent(String.self, forKey: .subtitle),
                icon: try c.decodeIfPresent(String.self, forKey: .icon),
                action: try c.decodeIfPresent(AIUXAction.self, forKey: .action),
                children: try children(),
                layout: layout
            )
        case "custom":
            self = .custom(
                kind: try c.decodeIfPresent(String.self, forKey: .kind) ?? "",
                props: (try? c.decodeIfPresent([String: AIUXJSONValue].self, forKey: .props)) ?? [:],
                children: try children(),
                layout: layout
            )
        case "actions":
            self = .actions(children: try children(), layout: layout)
        default:
            self = .unknown(type: type.isEmpty ? "missing-type" : type)
        }
    }
}

/// A surface: a named, revisioned semantic node tree.
public struct AIUXSurfaceTree: Equatable, Decodable, Identifiable, Sendable {
    /// Stable surface identifier.
    public var id: String
    /// Optional human-facing name.
    public var name: String?
    /// Monotonic revision; bumps on every `surface.updated`.
    public var revision: UInt64 = 0
    /// Root node — a `surface` node per the schema.
    public var root: AIUXSurfaceNode

    public init(id: String, root: AIUXSurfaceNode) {
        self.id = id
        self.root = root
    }

    private enum CodingKeys: String, CodingKey { case id, name, revision, root }

    /// `revision` is skipped when zero on the wire.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        revision = try c.decodeIfPresent(UInt64.self, forKey: .revision) ?? 0
        root = try c.decode(AIUXSurfaceNode.self, forKey: .root)
    }
}

// MARK: - Inline surface descriptors + artifact contracts (ADR 0007)

/// An inline surface descriptor: a self-contained semantic node tree carried
/// inside another entity (`artifact.preview` / `artifact.workspace`) rather
/// than registered as a session surface.
public struct AIUXSurfaceDescriptor: Equatable, Decodable, Identifiable, Sendable {
    /// Stable descriptor identifier (lazy-mount key).
    public var id: String
    /// Root node — a `surface` node per the schema.
    public var root: AIUXSurfaceNode
}

/// How an opened artifact workspace presents.
public enum AIUXWorkspaceMode: String, Decodable, Sendable {
    case fullscreen, detail, sheet
}

/// `artifact.workspace` — the contract a host honors when the user opens an
/// artifact: a presentation mode, an optional detail surface descriptor, and
/// a lazy render hint.
public struct AIUXArtifactWorkspace: Equatable, Decodable, Sendable {
    public var mode: AIUXWorkspaceMode?
    public var surface: AIUXSurfaceDescriptor?
    public var lazy: Bool = false
}

/// `artifact.preview` — what an artifact card shows inline: a short summary
/// and/or an inline surface descriptor.
public struct AIUXArtifactPreview: Equatable, Decodable, Sendable {
    public var summary: String?
    public var surface: AIUXSurfaceDescriptor?
}
