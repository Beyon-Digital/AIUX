import SwiftUI

// MARK: - Composer (plan §8)
//
// `AIComposer` is the text-entry bar: send / cancel / attach. It never acts
// itself — send emits `aiux.composer.send` with `{text}`, cancel emits
// `aiux.composer.cancel`, attach emits `aiux.composer.attach` (the host owns
// the picker). Cancel is only enabled while a run is active.

/// The message composer bar.
public struct AIComposer: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit

    /// Whether a run is active (cancel enabled, send of a new prompt
    /// still allowed — hosts decide queueing policy).
    public var runActive: Bool
    /// Placeholder text.
    public var placeholder: String

    @State private var text: String = ""

    public init(runActive: Bool = false, placeholder: String = "Message…") {
        self.runActive = runActive
        self.placeholder = placeholder
    }

    public var body: some View {
        let colors = theme.colors(for: colorScheme)
        HStack(alignment: .bottom, spacing: theme.space(.sm)) {
            Button {
                emit(AIUXAction(id: AIUXAction.composerAttach))
            } label: {
                Image(systemName: "paperclip")
                    .font(theme.typography.heading)
                    .foregroundStyle(colors.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Attach")

            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...5)
                .font(theme.typography.body)
                .padding(.horizontal, theme.space(.sm))
                .padding(.vertical, theme.space(.xs))
                .background(colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.lg)))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.radius(.lg))
                        .strokeBorder(colors.border, lineWidth: 1)
                )
                .accessibilityLabel("Message input")

            if runActive {
                Button(role: .cancel) {
                    emit(AIUXAction(id: AIUXAction.composerCancel))
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(theme.typography.title)
                        .foregroundStyle(colors.destructive)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel run")
            } else {
                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(theme.typography.title)
                        .foregroundStyle(canSend ? colors.accent : colors.muted)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, theme.space(.md))
        .padding(.vertical, theme.space(.sm))
        .background(colors.background)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        emit(AIUXAction(id: AIUXAction.composerSend, payload: [
            "text": .string(trimmed),
        ]))
        text = ""
    }
}
