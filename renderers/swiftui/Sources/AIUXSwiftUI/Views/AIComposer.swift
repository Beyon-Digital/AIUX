import SwiftUI

// MARK: - Composer (plan §8)
//
// `AIComposer` is the text-entry bar: send / cancel / attach. It never acts
// itself — send emits `aiux.composer.send` with `{text}`, cancel emits
// `aiux.composer.cancel`, attach emits `aiux.composer.attach` (the host owns
// the picker). Cancel is only enabled while a run is active.

/// The floating message composer — a margin-free pill over the content.
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
        HStack(alignment: .center, spacing: theme.space(.sm)) {
            Button {
                emit(AIUXAction(id: AIUXAction.composerAttach))
            } label: {
                Image(systemName: "plus")
                    .font(theme.typography.title)
                    .foregroundStyle(colors.muted)
                    .frame(width: 40, height: 40)
                    .background(colors.surface)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(colors.border, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Attach")

            HStack(alignment: .center, spacing: theme.space(.xs)) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .font(theme.typography.body)
                    .padding(.horizontal, theme.space(.sm))
                    .padding(.vertical, theme.space(.xs))
                    .accessibilityLabel("Message input")

                if runActive {
                    Button(role: .cancel) {
                        emit(AIUXAction(id: AIUXAction.composerCancel))
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(theme.typography.title)
                            .foregroundStyle(colors.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel run")
                } else {
                    Button {
                        send()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(theme.typography.title)
                            .foregroundStyle(canSend ? colors.accent : colors.muted.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .accessibilityLabel("Send")
                }
            }
            .padding(.leading, theme.space(.sm))
            .padding(.trailing, 6)
            .padding(.vertical, 4)
            .background(colors.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(colors.border, lineWidth: 1)
            )
            // Floating composer: soft elevation instead of a docked bar.
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)

        }
        .padding(.horizontal, theme.space(.md))
        .padding(.top, theme.space(.xs))
        .padding(.bottom, theme.space(.md))
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
