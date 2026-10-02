import SwiftUI

// MARK: - Semantic surface renderer (plan §6, ADR 0006)
//
// `AISurface` renders a Surface Schema v1 tree. Every primitive maps to a
// semantic SwiftUI layout — tokens (`gap`, `padding`, `radius`, `alignment`,
// `distribution`) never decode to pixels. Interactive nodes (button, menu,
// input, textarea, select, checkbox) emit `AIUXAction`s upward and never
// execute anything themselves. Unknown node kinds degrade to a placeholder.

/// A surface tree (one `surface` root node) embedded in a message or standalone.
public struct AISurface: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    public let tree: AIUXSurfaceTree

    public init(tree: AIUXSurfaceTree) {
        self.tree = tree
    }

    public var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: theme.space(.xs)) {
            if let name = tree.name {
                Text(name)
                    .font(theme.typography.caption)
                    .foregroundStyle(colors.muted)
            }
            AIUXNodeView(node: tree.root)
        }
        .padding(theme.space(.sm))
        .background(colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.lg)))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.radius(.lg))
                .strokeBorder(colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Surface \(tree.name ?? tree.id), revision \(tree.revision)")
    }
}

// MARK: - Node dispatch

/// Renders a single surface node, recursing into container children.
struct AIUXNodeView: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit

    let node: AIUXSurfaceNode

    var body: some View {
        switch node {
        case .surface(let children, let layout):
            AIUXFlowStack(children: children, direction: .vertical, layout: layout)
                .padding(theme.padding(layout.padding ?? .md))

        case .card(let children, let title, let layout):
            let colors = theme.colors(for: colorScheme)
            VStack(alignment: .leading, spacing: theme.space(.xs)) {
                if let title {
                    Text(title)
                        .font(theme.typography.heading)
                }
                AIUXFlowStack(children: children, direction: .vertical, layout: layout)
            }
            .padding(theme.padding(layout.padding ?? .md))
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(layout.radius ?? .md)))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.radius(layout.radius ?? .md))
                    .strokeBorder(colors.border, lineWidth: 1)
            )

        case .stack(let children, let direction, let layout):
            AIUXFlowStack(children: children, direction: direction ?? .vertical, layout: layout)
                .padding(theme.padding(layout.padding))

        case .row(let children, let layout):
            AIUXFlowStack(children: children, direction: .horizontal, layout: layout)
                .padding(theme.padding(layout.padding))

        case .grid(let children, let columns, let layout):
            AIUXGridView(children: children, columns: columns, layout: layout)

        case .heading(let text, let level, let layout):
            Text(text)
                .font(headingFont(level))
                .padding(theme.padding(layout.padding))
                .accessibilityAddTraits(.isHeader)

        case .text(let text, let variant, let layout):
            Group {
                if variant == .emphasis {
                    Text(text).italic()
                } else if variant == .strong {
                    Text(text).bold()
                } else {
                    Text(text)
                }
            }
            .font(textFont(variant))
            .foregroundStyle(textColor(variant))
            .textSelection(.enabled)
            .padding(theme.padding(layout.padding))

        case .markdown(let markdown, let layout):
            aiuxMarkdownText(markdown)
                .font(theme.typography.body)
                .textSelection(.enabled)
                .padding(theme.padding(layout.padding))

        case .code(let code, let language, let layout):
            AICodeBlock(code: code, language: language)
                .padding(theme.padding(layout.padding))

        case .icon(let name, let size, let layout):
            Image(systemName: aiuxIconName(name))
                .font(iconFont(size))
                .foregroundStyle(theme.colors(for: colorScheme).muted)
                .padding(theme.padding(layout.padding))
                .accessibilityLabel(name)

        case .image(let src, let alt, let layout):
            AIUXSurfaceImage(src: src, alt: alt)
                .padding(theme.padding(layout.padding))

        case .badge(let text, let tone, let icon, let layout):
            AIBadge(text: text, tone: tone, icon: icon)
                .padding(theme.padding(layout.padding))

        case .divider(let layout):
            Divider()
                .padding(.vertical, theme.space(.xs))
                .padding(theme.padding(layout.padding))

        case .spacer(let size, _):
            Spacer(minLength: theme.space(size ?? .md))

        case .keyValue(let items, let layout):
            AIUXKeyValueView(items: items)
                .padding(theme.padding(layout.padding))

        case .list(let children, let ordered, let layout):
            VStack(alignment: .leading, spacing: theme.space(layout.gap ?? .xs)) {
                ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                    HStack(alignment: .firstTextBaseline, spacing: theme.space(.sm)) {
                        Text(ordered ? "\(index + 1)." : "•")
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors(for: colorScheme).muted)
                        AIUXNodeView(node: child)
                    }
                }
            }
            .padding(theme.padding(layout.padding))

        case .table(let headers, let columns, let rows, let caption, let layout):
            AIUXTableView(headers: headers, columns: columns, rows: rows, caption: caption)
                .padding(theme.padding(layout.padding))

        case .button(let label, let action, let variant, let disabled, let layout):
            Button {
                emit(action)
            } label: {
                Text(label)
            }
            .modifier(AIUXButtonStyleModifier(variant: variant, theme: theme, scheme: colorScheme))
            .disabled(disabled)
            .padding(theme.padding(layout.padding))
            .accessibilityLabel(label)

        case .menu(let label, let items, let layout):
            Menu {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Button {
                        emit(item.action)
                    } label: {
                        if let icon = item.icon {
                            Label(item.label, systemImage: aiuxIconName(icon))
                        } else {
                            Text(item.label)
                        }
                    }
                    .disabled(item.disabled)
                }
            } label: {
                Label(label ?? "More", systemImage: "ellipsis.circle")
                    .font(theme.typography.label)
            }
            .padding(theme.padding(layout.padding))
            .accessibilityLabel(label ?? "Menu")

        case .progress(let value, let max, let label, let layout):
            let colors = theme.colors(for: colorScheme)
            VStack(alignment: .leading, spacing: theme.space(.xs)) {
                if let value, let max, max > 0 {
                    ProgressView(value: value, total: max)
                        .tint(colors.accent)
                } else if let value {
                    ProgressView(value: value, total: 1)
                        .tint(colors.accent)
                } else {
                    ProgressView()
                        .tint(colors.accent)
                }
                if let label {
                    Text(label)
                        .font(theme.typography.caption)
                        .foregroundStyle(colors.muted)
                }
            }
            .padding(theme.padding(layout.padding))

        case .status(let text, let tone, let layout):
            let colors = theme.colors(for: colorScheme)
            Label(text, systemImage: aiuxToneIcon(tone))
                .font(theme.typography.caption)
                .foregroundStyle(colors.tone(tone))
                .padding(theme.padding(layout.padding))

        case .input(let name, let label, let placeholder, let value, let inputType, let required, let disabled, let errorText, let layout):
            AIUXInputField(
                name: name,
                label: label,
                placeholder: placeholder,
                initialValue: value,
                inputType: inputType,
                required: required,
                disabled: disabled,
                errorText: errorText
            )
            .padding(theme.padding(layout.padding))

        case .textarea(let name, let label, let placeholder, let value, let rows, let required, let disabled, let errorText, let layout):
            AIUXTextareaField(
                name: name,
                label: label,
                placeholder: placeholder,
                initialValue: value,
                rows: rows,
                required: required,
                disabled: disabled,
                errorText: errorText
            )
            .padding(theme.padding(layout.padding))

        case .select(let name, let label, let options, let value, let placeholder, let required, let disabled, let errorText, let layout):
            AIUXSelectField(
                name: name,
                label: label,
                options: options,
                value: value,
                placeholder: placeholder,
                required: required,
                disabled: disabled,
                errorText: errorText
            )
            .padding(theme.padding(layout.padding))

        case .checkbox(let name, let label, let checked, let required, let disabled, let errorText, let layout):
            AIUXCheckboxField(
                name: name, label: label, checked: checked,
                required: required, disabled: disabled, errorText: errorText
            )
            .padding(theme.padding(layout.padding))

        case .radio(let name, let label, let options, let value, let required, let disabled, let errorText, let layout):
            AIUXRadioField(
                name: name,
                label: label,
                options: options,
                value: value,
                required: required,
                disabled: disabled,
                errorText: errorText
            )
            .padding(theme.padding(layout.padding))

        case .field(let children, let label, let helperText, let required, let disabled, let errorText, let layout):
            AIUXFieldBlock(
                children: children,
                label: label,
                helperText: helperText,
                required: required,
                disabled: disabled,
                errorText: errorText
            )
            .padding(theme.padding(layout.padding))

        case .form(let children, let submit, let submitLabel, let disabled, let layout):
            AIUXFormView(
                children: children,
                submit: submit,
                submitLabel: submitLabel,
                disabled: disabled
            )
            .padding(theme.padding(layout.padding))

        case .listItem(let title, let subtitle, let icon, let action, let children, let layout):
            AIUXListItemView(
                title: title,
                subtitle: subtitle,
                icon: icon,
                action: action,
                children: children
            )
            .padding(theme.padding(layout.padding))

        case .custom(let kind, let props, let children, let layout):
            AIUXCustomNodeView(kind: kind, props: props, children: children)
                .padding(theme.padding(layout.padding))

        case .actions(let children, let layout):
            HStack(spacing: theme.space(layout.gap ?? .sm)) {
                Spacer(minLength: 0)
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    AIUXNodeView(node: child)
                }
            }
            .padding(theme.padding(layout.padding))

        case .unknown(let type):
            AIUXUnsupported(kind: "surface node", detail: type)
        }
    }

    private func headingFont(_ level: Int?) -> Font {
        switch level ?? 2 {
        case 1: return theme.typography.title
        case 2: return theme.typography.heading
        default: return theme.typography.label
        }
    }

    private func textFont(_ variant: AIUXTextVariant?) -> Font {
        switch variant {
        case .caption: return theme.typography.caption
        case .label: return theme.typography.label
        default: return theme.typography.body
        }
    }

    private func textColor(_ variant: AIUXTextVariant?) -> Color {
        let colors = theme.colors(for: colorScheme)
        switch variant {
        case .caption, .muted: return colors.muted
        default: return Color.primary
        }
    }

    private func iconFont(_ size: AIUXIconSize?) -> Font {
        switch size {
        case .sm: return theme.typography.caption
        case .lg: return theme.typography.title
        default: return theme.typography.heading
        }
    }
}

// MARK: - Semantic layout containers

/// A stack honoring semantic `direction`, `gap`, `alignment`, `distribution`.
/// `distribution` is expressed with leading/trailing/inter-item `Spacer`s.
struct AIUXFlowStack: View {
    @Environment(\.aiuxTheme) private var theme

    let children: [AIUXSurfaceNode]
    let direction: AIUXStackDirection
    let layout: AIUXNodeLayout

    var body: some View {
        if direction == .horizontal {
            HStack(
                alignment: verticalAlignment(layout.alignment),
                spacing: theme.space(layout.gap ?? .sm)
            ) {
                distributed
            }
        } else {
            VStack(
                alignment: horizontalAlignment(layout.alignment),
                spacing: theme.space(layout.gap ?? .sm)
            ) {
                distributed
            }
        }
    }

    /// Children interleaved with spacers per the distribution token.
    @ViewBuilder
    private var distributed: some View {
        switch layout.distribution ?? .start {
        case .start:
            childViews
            Spacer(minLength: 0)
        case .end:
            Spacer(minLength: 0)
            childViews
        case .center:
            Spacer(minLength: 0)
            childViews
            Spacer(minLength: 0)
        case .spaceBetween:
            ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                if index > 0 { Spacer(minLength: 0) }
                childView(child)
            }
        case .spaceAround, .spaceEvenly:
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                Spacer(minLength: 0)
                childView(child)
                if layout.distribution == .spaceAround {
                    Spacer(minLength: 0)
                }
            }
            if layout.distribution == .spaceEvenly {
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var childViews: some View {
        ForEach(Array(children.enumerated()), id: \.offset) { _, child in
            childView(child)
        }
    }

    @ViewBuilder
    private func childView(_ child: AIUXSurfaceNode) -> some View {
        // `.stretch` alignment fills the cross axis.
        if layout.alignment == .stretch {
            if direction == .horizontal {
                AIUXNodeView(node: child).frame(maxHeight: .infinity)
            } else {
                AIUXNodeView(node: child).frame(maxWidth: .infinity)
            }
        } else {
            AIUXNodeView(node: child)
        }
    }

    private func horizontalAlignment(_ alignment: AIUXAlignment?) -> HorizontalAlignment {
        switch alignment {
        case .center: return .center
        case .end: return .trailing
        default: return .leading
        }
    }

    private func verticalAlignment(_ alignment: AIUXAlignment?) -> VerticalAlignment {
        switch alignment {
        case .center: return .center
        case .end: return .bottom
        case .stretch: return .center // stretch handled per-child
        default: return .top
        }
    }
}

/// Fixed-column grid via `Grid`/`GridRow`.
struct AIUXGridView: View {
    @Environment(\.aiuxTheme) private var theme

    let children: [AIUXSurfaceNode]
    let columns: Int
    let layout: AIUXNodeLayout

    var body: some View {
        Grid(
            alignment: gridAlignment(layout.alignment),
            horizontalSpacing: theme.space(layout.gap ?? .md),
            verticalSpacing: theme.space(layout.gap ?? .sm)
        ) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, child in
                        AIUXNodeView(node: child)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(theme.padding(layout.padding))
    }

    /// Children chunked into `columns`-wide rows.
    private var rows: [[AIUXSurfaceNode]] {
        var result: [[AIUXSurfaceNode]] = []
        var current: [AIUXSurfaceNode] = []
        for child in children {
            current.append(child)
            if current.count >= columns {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private func gridAlignment(_ alignment: AIUXAlignment?) -> Alignment {
        switch alignment {
        case .center: return .center
        case .end: return .trailing
        default: return .leading
        }
    }
}

/// `keyValue` rows.
struct AIUXKeyValueView: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let items: [AIUXKeyValueItem]

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: theme.space(.xs)) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline) {
                    Text(item.key)
                        .font(theme.typography.caption)
                        .foregroundStyle(colors.muted)
                    Spacer(minLength: theme.space(.sm))
                    Text(item.value)
                        .font(theme.typography.label)
                        .foregroundStyle(item.tone != nil ? colors.tone(item.tone) : Color.primary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Semantic table: header row (or `columns`) + typed body rows (ADR 0007).
struct AIUXTableView: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit

    let headers: [String]
    let columns: [AIUXTableColumn]
    let rows: [[AIUXTableCell]]
    let caption: String?

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        let effectiveHeaders = headers.isEmpty ? columns.map(\.title) : headers
        VStack(alignment: .leading, spacing: theme.space(.xs)) {
            Grid(alignment: .leading, horizontalSpacing: theme.space(.md), verticalSpacing: theme.space(.xs)) {
                if !effectiveHeaders.isEmpty {
                    GridRow {
                        ForEach(Array(effectiveHeaders.enumerated()), id: \.offset) { index, header in
                            Text(header)
                                .font(theme.typography.label)
                                .frame(maxWidth: .infinity, alignment: cellAlignment(index))
                        }
                    }
                    .foregroundStyle(colors.muted)
                    Divider()
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { index, cell in
                            cellView(cell)
                                .frame(maxWidth: .infinity, alignment: cellAlignment(index))
                        }
                    }
                }
            }
            if let caption {
                Text(caption)
                    .font(theme.typography.caption)
                    .foregroundStyle(colors.muted)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func cellView(_ cell: AIUXTableCell) -> some View {
        switch cell {
        case .text(let text):
            Text(text)
                .font(theme.typography.body)
        case .number(let value):
            Text(value.truncatingRemainder(dividingBy: 1) == 0
                 ? String(Int(value)) : String(value))
                .font(theme.typography.body.monospacedDigit())
        case .badge(let text, let tone):
            AIBadge(text: text, tone: tone, icon: nil)
        case .action(let label, let action):
            Button(label) { emit(action) }
                .buttonStyle(.plain)
                .font(theme.typography.label)
                .foregroundStyle(theme.colors(for: colorScheme).accent)
        }
    }

    private func cellAlignment(_ column: Int) -> Alignment {
        switch columns.indices.contains(column) ? columns[column].align : nil {
        case .center: return .center
        case .end: return .trailing
        default: return .leading
        }
    }
}

/// A `badge`: text capsule colored by tone (optional icon, ADR 0007).
struct AIBadge: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let text: String
    let tone: AIUXTone?
    var icon: String? = nil

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        HStack(spacing: 2) {
            if let icon {
                Image(systemName: aiuxIconName(icon))
            }
            Text(text)
        }
        .font(theme.typography.caption)
        .foregroundStyle(colors.tone(tone))
        .padding(.horizontal, theme.space(.xs))
        .padding(.vertical, 2)
        .background(colors.tone(tone).opacity(0.14))
        .clipShape(Capsule())
        .accessibilityLabel("Badge: \(text)")
    }
}

/// Surface `image` node.
struct AIUXSurfaceImage: View {
    @Environment(\.aiuxTheme) private var theme

    let src: String
    let alt: String?

    var body: some View {
        if let url = URL(string: src) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    AIUXUnsupported(kind: "image", detail: src)
                default:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.sm)))
            .accessibilityLabel(alt ?? "Image")
        } else {
            AIUXUnsupported(kind: "image", detail: src)
        }
    }
}

// MARK: - Interactive field nodes
//
// Every field emits `aiux.field.change` with `{name, value}` when the user
// commits an edit — the renderer holds only presentation state.

struct AIUXInputField: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit
    @Environment(\.aiuxFormStore) private var formStore

    let name: String
    let label: String?
    let placeholder: String?
    let initialValue: String?
    let inputType: AIUXInputType?
    let required: Bool
    let disabled: Bool
    var errorText: String? = nil

    @State private var value: String = ""

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: theme.space(.xs)) {
            if let label {
                Text(label + (required ? " *" : ""))
                    .font(theme.typography.caption)
                    .foregroundStyle(colors.muted)
            }
            field
            AIUXFieldError(errorText)
        }
        .onAppear {
            value = initialValue ?? ""
            publish()
        }
    }

    @ViewBuilder
    private var field: some View {
        Group {
            if inputType == .password {
                SecureField(placeholder ?? "", text: $value)
            } else {
                TextField(placeholder ?? "", text: $value)
                    .modifier(AIUXKeyboardModifier(inputType: inputType))
            }
        }
        .textFieldStyle(.roundedBorder)
        .font(theme.typography.body)
        .disabled(disabled)
        .onSubmit { commit() }
        .onChange(of: value) { _ in commit() }
        .accessibilityLabel(label ?? name)
    }

    private func commit() {
        publish()
        emit(AIUXAction(id: AIUXAction.fieldChange, payload: [
            "name": .string(name),
            "value": .string(value),
        ]))
    }

    private func publish() {
        formStore?.values[name] = .string(value)
    }
}

/// Field validation message under a control (ADR 0007).
struct AIUXFieldError: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let text: String?

    init(_ text: String?) { self.text = text }

    var body: some View {
        if let text, !text.isEmpty {
            Text(text)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors(for: colorScheme).destructive)
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

/// iOS-only keyboard hints for input types; a no-op on macOS.
struct AIUXKeyboardModifier: ViewModifier {
    let inputType: AIUXInputType?

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        switch inputType {
        case .email:
            content.keyboardType(.emailAddress).autocorrectionDisabled()
        case .number:
            content.keyboardType(.decimalPad)
        case .url:
            content.keyboardType(.URL).autocorrectionDisabled()
        case .text, .password, .none:
            content
        }
        #else
        content
        #endif
    }
}

struct AIUXTextareaField: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit
    @Environment(\.aiuxFormStore) private var formStore

    let name: String
    let label: String?
    let placeholder: String?
    let initialValue: String?
    let rows: Int?
    var required: Bool = false
    let disabled: Bool
    var errorText: String? = nil

    @State private var value: String = ""

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: theme.space(.xs)) {
            if let label {
                Text(label + (required ? " *" : ""))
                    .font(theme.typography.caption)
                    .foregroundStyle(colors.muted)
            }
            TextField(placeholder ?? "", text: $value, axis: .vertical)
                .lineLimit((rows ?? 3)...)
                .textFieldStyle(.roundedBorder)
                .font(theme.typography.body)
                .disabled(disabled)
                .onSubmit { commit() }
                .onChange(of: value) { _ in commit() }
                .accessibilityLabel(label ?? name)
            AIUXFieldError(errorText)
        }
        .onAppear {
            value = initialValue ?? ""
            publish()
        }
    }

    private func commit() {
        publish()
        emit(AIUXAction(id: AIUXAction.fieldChange, payload: [
            "name": .string(name),
            "value": .string(value),
        ]))
    }

    private func publish() {
        formStore?.values[name] = .string(value)
    }
}

struct AIUXSelectField: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit
    @Environment(\.aiuxFormStore) private var formStore

    let name: String
    let label: String?
    let options: [AIUXSelectOption]
    let value: String?
    let placeholder: String?
    var required: Bool = false
    let disabled: Bool
    var errorText: String? = nil

    @State private var selected: String = ""

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: theme.space(.xs)) {
            if let label {
                Text(label + (required ? " *" : ""))
                    .font(theme.typography.caption)
                    .foregroundStyle(colors.muted)
            }
            Menu {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Button(option.label) {
                        selected = option.value
                        commit(option.value)
                    }
                }
            } label: {
                HStack {
                    Text(displayLabel)
                        .font(theme.typography.body)
                        .foregroundStyle(selected.isEmpty ? colors.muted : Color.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(colors.muted)
                }
                .padding(theme.space(.xs))
                .background(colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.sm)))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.radius(.sm))
                        .strokeBorder(colors.border, lineWidth: 1)
                )
            }
            .disabled(disabled)
            .accessibilityLabel(label ?? name)
            AIUXFieldError(errorText)
        }
        .onAppear {
            selected = value ?? ""
            publish()
        }
    }

    private func commit(_ newValue: String) {
        publish(newValue)
        emit(AIUXAction(id: AIUXAction.fieldChange, payload: [
            "name": .string(name),
            "value": .string(newValue),
        ]))
    }

    private func publish(_ v: String? = nil) {
        formStore?.values[name] = .string(v ?? selected)
    }

    private var displayLabel: String {
        options.first { $0.value == selected }?.label
            ?? (selected.isEmpty ? (placeholder ?? "Select…") : selected)
    }
}

struct AIUXCheckboxField: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.aiuxAction) private var emit
    @Environment(\.aiuxFormStore) private var formStore

    let name: String
    let label: String
    let checked: Bool
    var required: Bool = false
    let disabled: Bool
    var errorText: String? = nil

    @State private var isOn: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.xs)) {
            Toggle(isOn: $isOn) {
                Text(label + (required ? " *" : ""))
                    .font(theme.typography.body)
            }
            .disabled(disabled)
            .onAppear {
                isOn = checked
                publish()
            }
            .onChange(of: isOn) { newValue in
                publish(newValue)
                emit(AIUXAction(id: AIUXAction.fieldChange, payload: [
                    "name": .string(name),
                    "value": .bool(newValue),
                ]))
            }
            .accessibilityLabel(label)
            AIUXFieldError(errorText)
        }
    }

    private func publish(_ v: Bool? = nil) {
        formStore?.values[name] = .bool(v ?? isOn)
    }
}

/// `radio` — single-choice option group (ADR 0007).
struct AIUXRadioField: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit
    @Environment(\.aiuxFormStore) private var formStore

    let name: String
    let label: String?
    let options: [AIUXSelectOption]
    let value: String?
    let required: Bool
    let disabled: Bool
    let errorText: String?

    @State private var selected: String = ""

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: theme.space(.xs)) {
            if let label {
                Text(label + (required ? " *" : ""))
                    .font(theme.typography.label)
            }
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button {
                    selected = option.value
                    commit(option.value)
                } label: {
                    HStack(spacing: theme.space(.sm)) {
                        Image(systemName: selected == option.value
                              ? "circle.inset.filled" : "circle")
                            .foregroundStyle(selected == option.value
                                             ? colors.accent : colors.muted)
                        Text(option.label)
                            .font(theme.typography.body)
                            .foregroundStyle(Color.primary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(selected == option.value ? .isSelected : [])
            }
            AIUXFieldError(errorText)
        }
        .onAppear {
            selected = value ?? ""
            publish()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label ?? name)
    }

    private func commit(_ newValue: String) {
        publish(newValue)
        emit(AIUXAction(id: AIUXAction.fieldChange, payload: [
            "name": .string(name),
            "value": .string(newValue),
        ]))
    }

    private func publish(_ v: String? = nil) {
        formStore?.values[name] = .string(v ?? selected)
    }
}

/// `field` — label/helper/error wrapper around one or more controls
/// (ADR 0007).
struct AIUXFieldBlock: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let children: [AIUXSurfaceNode]
    let label: String?
    let helperText: String?
    let required: Bool
    let disabled: Bool
    let errorText: String?

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: theme.space(.xs)) {
            if let label {
                Text(label + (required ? " *" : ""))
                    .font(theme.typography.label)
            }
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                AIUXNodeView(node: child)
            }
            if let helperText, errorText == nil {
                Text(helperText)
                    .font(theme.typography.caption)
                    .foregroundStyle(colors.muted)
            }
            AIUXFieldError(errorText)
        }
        .disabled(disabled)
        .accessibilityElement(children: .contain)
    }
}

/// `form` — own field scope; submit folds collected `fields` into the action
/// payload (ADR 0007).
struct AIUXFormView: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit

    let children: [AIUXSurfaceNode]
    let submit: AIUXAction
    let submitLabel: String?
    let disabled: Bool

    @StateObject private var store = AIUXFormStore()

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.md)) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                AIUXNodeView(node: child)
            }
            Button {
                var payload = submit.payload
                if !store.values.isEmpty {
                    payload["fields"] = .object(store.values)
                }
                emit(AIUXAction(id: submit.id, payload: payload))
            } label: {
                Text(submitLabel ?? "Submit")
            }
            .modifier(AIUXButtonStyleModifier(variant: .primary, theme: theme, scheme: colorScheme))
            .disabled(disabled)
        }
        .environment(\.aiuxFormStore, store)
        .accessibilityElement(children: .contain)
    }
}

/// `listItem` — structured list row: icon, title, subtitle, optional action,
/// nested children (ADR 0007).
struct AIUXListItemView: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit

    let title: String
    let subtitle: String?
    let icon: String?
    let action: AIUXAction?
    let children: [AIUXSurfaceNode]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space(.xs)) {
            row
            if !children.isEmpty {
                VStack(alignment: .leading, spacing: theme.space(.xs)) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        AIUXNodeView(node: child)
                    }
                }
                .padding(.leading, theme.space(.lg))
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var row: some View {
        let colors = theme.colors(for: colorScheme)
        let content = HStack(spacing: theme.space(.sm)) {
            if let icon {
                Image(systemName: aiuxIconName(icon))
                    .foregroundStyle(colors.muted)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(theme.typography.label)
                    .foregroundStyle(Color.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(theme.typography.caption)
                        .foregroundStyle(colors.muted)
                }
            }
        }
        if let action {
            Button { emit(action) } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

/// `custom` — host-registered node kind; unregistered kinds degrade to a
/// labelled placeholder plus their (core-schema) children (ADR 0007).
struct AIUXCustomNodeView: View {
    @Environment(\.aiuxCustomNodes) private var registry

    let kind: String
    let props: [String: AIUXJSONValue]
    let children: [AIUXSurfaceNode]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let render = registry[kind] {
                render(.custom(kind: kind, props: props, children: children,
                               layout: AIUXNodeLayout()))
            } else {
                AIUXUnsupported(kind: "custom node", detail: kind)
            }
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                AIUXNodeView(node: child)
            }
        }
    }
}

// MARK: - Button styling

/// Maps the semantic `variant` token onto SwiftUI button styles via theme.
struct AIUXButtonStyleModifier: ViewModifier {
    let variant: AIUXButtonVariant?
    let theme: AIUXTheme
    let scheme: ColorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        let colors = theme.colors(for: scheme)
        switch variant ?? .secondary {
        case .primary:
            content
                .buttonStyle(.borderedProminent)
                .tint(colors.accent)
        case .destructive:
            content
                .buttonStyle(.borderedProminent)
                .tint(colors.destructive)
        case .secondary:
            content
                .buttonStyle(.bordered)
                .tint(colors.accent)
        case .ghost:
            content
                .buttonStyle(.plain)
                .foregroundStyle(colors.accent)
        }
    }
}

// MARK: - Icon mapping

/// Semantic icon names → SF Symbols. Unknown names fall back to a neutral
/// glyph — semantic names are renderer-mapped, never raw asset keys (§6).
func aiuxIconName(_ name: String) -> String {
    switch name.lowercased() {
    case "check", "ok", "done": return "checkmark"
    case "close", "cancel", "x": return "xmark"
    case "warning", "warn": return "exclamationmark.triangle"
    case "error": return "xmark.octagon"
    case "info": return "info.circle"
    case "success": return "checkmark.circle"
    case "add", "plus": return "plus"
    case "remove", "minus": return "minus"
    case "search": return "magnifyingglass"
    case "settings", "gear": return "gearshape"
    case "user", "person", "account": return "person"
    case "file", "document", "doc": return "doc"
    case "folder": return "folder"
    case "link", "url": return "link"
    case "code": return "chevron.left.forwardslash.chevron.right"
    case "image", "photo": return "photo"
    case "star", "favorite": return "star"
    case "heart": return "heart"
    case "calendar", "date": return "calendar"
    case "clock", "time": return "clock"
    case "download": return "arrow.down.to.line"
    case "upload": return "arrow.up.to.line"
    case "open", "external": return "arrow.up.forward"
    case "more", "overflow": return "ellipsis"
    case "play": return "play.fill"
    case "stop": return "stop.fill"
    case "refresh", "reload": return "arrow.clockwise"
    case "back": return "chevron.left"
    case "forward", "next": return "chevron.right"
    case "send": return "paperplane.fill"
    case "attach", "attachment": return "paperclip"
    case "lock", "secure": return "lock"
    case "unlock": return "lock.open"
    case "eye", "visible": return "eye"
    case "tool", "wrench": return "wrench.and.screwdriver"
    case "artifact": return "doc.richtext"
    default:
        // A dotted name is likely already an SF Symbol — pass through; blank
        // rendering is still non-fatal, and unknown names log nothing fatal.
        return name.contains(".") ? name : "questionmark.square"
    }
}

func aiuxToneIcon(_ tone: AIUXTone?) -> String {
    switch tone {
    case .accent: return "info.circle"
    case .success: return "checkmark.circle"
    case .warning: return "exclamationmark.triangle"
    case .destructive: return "xmark.octagon"
    case .muted, .default, .none: return "circle.fill"
    }
}
