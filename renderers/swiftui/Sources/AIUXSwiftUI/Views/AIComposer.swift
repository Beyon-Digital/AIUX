import SwiftUI

// MARK: - Composer (plan §8)
//
// `AIComposer` is the text-entry bar: send / cancel / attach / tools /
// dictate / voice. It never acts itself — send emits `aiux.composer.send`
// with `{text}`, cancel emits `aiux.composer.cancel`, the affordances emit
// `aiux.composer.attach` / `.tools` / `.dictate` / `.voice` (the host owns
// each picker or mode). Cancel is only enabled while a run is active.

/// The floating message composer — the current ChatGPT mobile shape: one
/// rounded surface with the input on top and a controls row pinned to the
/// bottom (`+`, tools ring, mic, filled action circle).
public struct AIComposer: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit

    /// Whether a run is active (cancel enabled, send of a new prompt
    /// still allowed — hosts decide queueing policy).
    public var runActive: Bool
    /// Placeholder text.
    public var placeholder: String
    /// Which controls render + custom tools appended to the row.
    public var toolbar: AIUXComposerToolbar

    @State private var text: String = ""

    public init(
        runActive: Bool = false,
        placeholder: String = "Message…",
        toolbar: AIUXComposerToolbar = .default
    ) {
        self.runActive = runActive
        self.placeholder = placeholder
        self.toolbar = toolbar
    }

    public var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: 0) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...6)
                .font(theme.typography.body)
                .tint(colors.accent)
                .frame(minHeight: 52, alignment: .topLeading)
                .padding(.horizontal, theme.space(.xs))
                .padding(.top, theme.space(.xs))
                .accessibilityLabel("Message input")

            HStack(alignment: .center, spacing: theme.space(.xs)) {
                if toolbar.attach {
                    Button {
                        emit(AIUXAction(id: AIUXAction.composerAttach))
                    } label: {
                        Image(systemName: "plus")
                            .font(theme.typography.title)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Attach")
                }

                Spacer(minLength: 0)

                if toolbar.tools {
                    Button {
                        emit(AIUXAction(id: AIUXAction.composerTools))
                    } label: {
                        toolsGlyph(colors: colors)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tools")
                }

                if toolbar.dictate {
                    Button {
                        emit(AIUXAction(id: AIUXAction.composerDictate))
                    } label: {
                        Image(systemName: "mic")
                            .font(theme.typography.title)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dictate")
                }

                ForEach(toolbar.extra) { tool in
                    Button {
                        emit(AIUXAction(id: tool.id))
                    } label: {
                        Image(systemName: tool.systemImage)
                            .font(theme.typography.title)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tool.accessibilityLabel)
                }

                actionButton(colors: colors)
            }
        }
        .padding(.leading, theme.space(.md))
        .padding(.trailing, theme.space(.md))
        .padding(.top, theme.space(.sm))
        .padding(.bottom, theme.space(.sm))
        .background(colors.inputSurface)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        // Floating composer: soft elevation instead of a docked bar.
        .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4)
        .padding(.horizontal, theme.space(.md))
        .padding(.top, theme.space(.xs))
        .padding(.bottom, theme.space(.md))
    }

    /// Accent-ringed circle with a magnifier — the tools toggle.
    private func toolsGlyph(colors: AIUXResolvedColors) -> some View {
        ZStack {
            Circle()
                .strokeBorder(colors.accent, lineWidth: 1.5)
                .frame(width: 26, height: 26)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .semibold))
        }
    }

    /// Filled accent action circle: stop square while a run is active,
    /// up-arrow with text, waveform (voice mode) while empty.
    private func actionButton(colors: AIUXResolvedColors) -> some View {
        Button {
            if runActive {
                emit(AIUXAction(id: AIUXAction.composerCancel))
            } else if canSend {
                send()
            } else {
                emit(AIUXAction(id: AIUXAction.composerVoice))
            }
        } label: {
            ZStack {
                Circle()
                    .fill(colors.accent)
                    .frame(width: 40, height: 40)
                if runActive {
                    Image(systemName: "square.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(colors.accentForeground)
                } else if canSend {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(colors.accentForeground)
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(colors.accentForeground)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(runActive ? "Cancel run" : (canSend ? "Send" : "Voice mode"))
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
