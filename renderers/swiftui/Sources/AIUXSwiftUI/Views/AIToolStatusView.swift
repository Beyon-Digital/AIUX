import SwiftUI

// MARK: - Tool status (plan §8)
//
// `AIToolStatus` renders a session `Tool` record: name, lifecycle status,
// live progress, and result/error summaries. It is display-only — tools are
// executed by the host/agent, never by the renderer.

/// Card for one tool invocation: started → progress → completed/failed.
public struct AIToolStatus: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    public let tool: AIUXTool

    public init(tool: AIUXTool) {
        self.tool = tool
    }

    public var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: theme.space(.xs)) {
            HStack(spacing: theme.space(.sm)) {
                statusIcon
                    .foregroundStyle(statusColor)
                Text(tool.name)
                    .font(theme.typography.label)
                statusBadge
                Spacer()
            }

            if let progress = tool.progress {
                VStack(alignment: .leading, spacing: 2) {
                    if let fraction = progress.fraction {
                        ProgressView(value: fraction)
                            .tint(colors.accent)
                    } else if tool.status == .running {
                        ProgressView()
                            .tint(colors.accent)
                    }
                    if let label = progress.label {
                        Text(label)
                            .font(theme.typography.caption)
                            .foregroundStyle(colors.muted)
                    }
                }
            }

            if let error = tool.error {
                Text(error.message)
                    .font(theme.typography.caption)
                    .foregroundStyle(colors.destructive)
                    .padding(.leading, theme.space(.lg))
            } else if let result = aiuxJSONDescription(tool.result) {
                Text(result)
                    .font(theme.typography.caption)
                    .foregroundStyle(colors.muted)
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .padding(.horizontal, theme.space(.sm))
                    .padding(.vertical, theme.space(.xs))
                    .background(colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.sm)))
                    .padding(.leading, theme.space(.lg))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tool \(tool.name): \(tool.status.rawValue)")
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch tool.status {
        case .running:
            ProgressView()
                .controlSize(.mini)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .failed:
            Image(systemName: "xmark.octagon.fill")
        }
    }

    private var statusColor: Color {
        let colors = theme.colors(for: colorScheme)
        switch tool.status {
        case .running: return colors.muted
        case .completed: return colors.muted
        case .failed: return colors.destructive
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        Text(tool.status.rawValue)
            .font(theme.typography.caption)
            .foregroundStyle(statusColor)
    }
}
