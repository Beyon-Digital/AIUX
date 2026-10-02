import SwiftUI

// MARK: - Context bar (plan §8)
//
// `AIContextBar` renders session context entities as chips with an add hook.
// Remove emits `aiux.context.remove` `{entityId}`; add emits
// `aiux.context.add` — the host owns pickers and policies.

/// Horizontal chip row for the session's context entities.
public struct AIContextBar: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit

    public let entities: [AIUXContextEntity]
    /// Show the trailing add chip.
    public var showsAddButton: Bool

    public init(entities: [AIUXContextEntity], showsAddButton: Bool = true) {
        self.entities = entities
        self.showsAddButton = showsAddButton
    }

    public var body: some View {
        let colors = theme.colors(for: colorScheme)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.space(.sm)) {
                ForEach(entities) { entity in
                    chip(entity, colors: colors)
                }
                if showsAddButton {
                    addChip(colors: colors)
                }
            }
            .padding(.horizontal, theme.space(.md))
        }
        .padding(.vertical, theme.space(.xs))
        .background(colors.background)
    }

    private func chip(_ entity: AIUXContextEntity, colors: AIUXResolvedColors) -> some View {
        HStack(spacing: theme.space(.xs)) {
            Image(systemName: aiuxContextIcon(kind: entity.kind))
                .font(theme.typography.caption)
            Text(entity.label)
                .font(theme.typography.caption)
                .lineLimit(1)
            Button {
                emit(AIUXAction(id: AIUXAction.contextRemove, payload: [
                    "entityId": .string(entity.id),
                ]))
            } label: {
                Image(systemName: "xmark")
                    .font(theme.typography.caption.weight(.bold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(entity.label)")
        }
        .padding(.horizontal, theme.space(.sm))
        .padding(.vertical, theme.space(.xs))
        .background(colors.surface)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(colors.border, lineWidth: 1))
        .foregroundStyle(colors.muted)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Context: \(entity.label)")
    }

    private func addChip(colors: AIUXResolvedColors) -> some View {
        Button {
            emit(AIUXAction(id: AIUXAction.contextAdd))
        } label: {
            Image(systemName: "plus")
                .font(theme.typography.caption)
                .padding(.horizontal, theme.space(.sm))
                .padding(.vertical, theme.space(.xs))
        }
        .background(colors.surface)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(colors.border, style: StrokeStyle(lineWidth: 1, dash: [3])))
        .foregroundStyle(colors.accent)
        .buttonStyle(.plain)
        .accessibilityLabel("Add context")
    }
}
