import SwiftUI

// MARK: - Message rendering (plan §8, §14)
//
// `AIMessage` renders one protocol message: role determines alignment and
// surface role, `parts` render in order through `AIPartView`. Reference parts
// (`tool`/`approval`/`artifact`/`surface`) resolve their entities through the
// `aiuxRenderModel` environment — missing references degrade to placeholders.

/// One message in a conversation — a bubble of ordered parts.
public struct AIMessage: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    public let message: AIUXMessage

    public init(message: AIUXMessage) {
        self.message = message
    }

    public var body: some View {
        switch message.role {
        case .system:
            systemRow
        case .user:
            alignedRow(alignment: .trailing, isUser: true)
        case .assistant, .tool:
            alignedRow(alignment: .leading, isUser: false)
        }
    }

    private var systemRow: some View {
        let colors = theme.colors(for: colorScheme)
        return VStack(spacing: theme.space(.xs)) {
            ForEach(message.parts) { part in
                AIPartView(part: part)
            }
            statusBadge
        }
        .font(theme.typography.caption)
        .foregroundStyle(colors.muted)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, theme.space(.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("System message")
    }

    private func alignedRow(alignment: HorizontalAlignment, isUser: Bool) -> some View {
        let colors = theme.colors(for: colorScheme)
        let fill = isUser ? colors.userSurface : colors.assistantSurface
        return HStack(spacing: 0) {
            if isUser { Spacer(minLength: theme.space(.xl)) }
            VStack(alignment: alignment, spacing: theme.space(.sm)) {
                ForEach(message.parts) { part in
                    AIPartView(part: part)
                        .frame(maxWidth: .infinity, alignment: Alignment(
                            horizontal: alignment == .trailing ? .trailing : .leading,
                            vertical: .center
                        ))
                }
                statusBadge
            }
            .padding(theme.space(.md))
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.lg)))
            if !isUser { Spacer(minLength: theme.space(.xl)) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isUser ? "You" : (message.role == .tool ? "Tool output" : "Assistant"))
    }

    /// Streaming / failed / cancelled marker under a message.
    @ViewBuilder
    private var statusBadge: some View {
        let colors = theme.colors(for: colorScheme)
        switch message.status {
        case .streaming:
            AIUXStreamingDots()
                .padding(.top, theme.space(.xs))
        case .failed:
            Label("Failed", systemImage: "exclamationmark.circle")
                .font(theme.typography.caption)
                .foregroundStyle(colors.destructive)
        case .cancelled:
            Label("Cancelled", systemImage: "slash.circle")
                .font(theme.typography.caption)
                .foregroundStyle(colors.muted)
        case .complete, .none:
            EmptyView()
        }
    }
}

/// Three pulsing dots marking in-flight streaming output. Collapses to a
/// static marker under Reduce Motion.
struct AIUXStreamingDots: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        Group {
            if reduceMotion {
                Text("…")
                    .foregroundStyle(colors.muted)
            } else {
                TimelineView(.animation(minimumInterval: theme.motion.duration)) { context in
                    let t = Int(context.date.timeIntervalSince1970 / max(theme.motion.duration, 0.1)) % 3
                    HStack(spacing: theme.space(.xs)) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(colors.muted.opacity(i == t ? 0.9 : 0.35))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Streaming response")
    }
}

// MARK: - Part dispatch

/// Renders a single typed part. Unknown/missing data → `AIUXUnsupported`.
public struct AIPartView: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.aiuxRenderModel) private var model

    public let part: AIUXPart

    public init(part: AIUXPart) {
        self.part = part
    }

    public var body: some View {
        switch part {
        case .text(_, let text):
            Text(text)
                .font(theme.typography.body)
                .textSelection(.enabled)
        case .markdown(_, let markdown):
            aiuxMarkdownText(markdown)
                .font(theme.typography.body)
                .textSelection(.enabled)
        case .code(_, let code, let language):
            AICodeBlock(code: code, language: language)
        case .image(_, let attachment):
            AIImagePart(attachment: attachment)
        case .attachment(_, let attachment):
            AIAttachmentRow(attachment: attachment)
        case .citation(_, let citation):
            AICitationRow(citation: citation)
        case .tool(_, let toolId):
            if let tool = model.tool(toolId) {
                AIToolStatus(tool: tool)
            } else {
                AIUXUnsupported(kind: "tool reference", detail: toolId)
            }
        case .approval(_, let approvalId):
            if let approval = model.approval(approvalId) {
                AIApproval(approval: approval)
            } else {
                AIUXUnsupported(kind: "approval reference", detail: approvalId)
            }
        case .artifact(_, let artifactId):
            if let artifact = model.artifact(artifactId) {
                AIArtifactPreview(artifact: artifact)
            } else {
                AIUXUnsupported(kind: "artifact reference", detail: artifactId)
            }
        case .status(_, let text, let level):
            AIStatusLine(text: text, level: level)
        case .progress(_, let progress):
            AIProgressLine(progress: progress)
        case .surface(_, let surfaceId):
            if let tree = model.surface(surfaceId) {
                AISurface(tree: tree)
            } else {
                AIUXUnsupported(kind: "surface reference", detail: surfaceId)
            }
        case .error(_, let error):
            AIErrorPart(partId: part.id, error: error)
        case .unknown(_, let type):
            AIUXUnsupported(kind: "part", detail: type)
        }
    }
}

// MARK: - Leaf part views

/// Code block with language badge, monospace body, copy affordance.
struct AICodeBlock: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let code: String
    let language: String?

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language ?? "code")
                    .font(theme.typography.caption)
                    .foregroundStyle(colors.muted)
                Spacer()
                Button {
                    aiuxCopyToPasteboard(code)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(colors.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy code")
            }
            .padding(.horizontal, theme.space(.md))
            .padding(.vertical, theme.space(.xs))
            .background(colors.surface)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(theme.typography.code)
                    .textSelection(.enabled)
                    .padding(theme.space(.md))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.md)))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.radius(.md))
                .strokeBorder(colors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Code block\(language.map { ", \($0)" } ?? "")")
    }
}

/// Image part — async-loaded from the attachment URI.
struct AIImagePart: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let attachment: AIUXAttachment

    var body: some View {
        if let uri = attachment.uri, let url = URL(string: uri) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    AIAttachmentRow(attachment: attachment)
                default:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.md)))
            .accessibilityLabel(attachment.name ?? attachment.uri ?? "Image")
        } else {
            AIAttachmentRow(attachment: attachment)
        }
    }
}

/// Attachment part — file row; taps emit `aiux.attachment.open`.
struct AIAttachmentRow: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit

    let attachment: AIUXAttachment

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        Button {
            emit(AIUXAction(id: AIUXAction.attachmentOpen, payload: [
                "uri": attachment.uri.map(AIUXJSONValue.string) ?? .null,
                "name": attachment.name.map(AIUXJSONValue.string) ?? .null,
                "attachmentId": attachment.id.map(AIUXJSONValue.string) ?? .null,
            ]))
        } label: {
            HStack(spacing: theme.space(.sm)) {
                Image(systemName: aiuxAttachmentIcon(mimeType: attachment.mimeType))
                    .foregroundStyle(colors.accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text(attachment.name ?? "Attachment")
                        .font(theme.typography.label)
                        .lineLimit(1)
                    let subtitle = [attachment.mimeType, aiuxByteCount(attachment.sizeBytes)]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(theme.typography.caption)
                            .foregroundStyle(colors.muted)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .foregroundStyle(colors.muted)
            }
            .padding(theme.space(.sm))
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.md)))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.radius(.md))
                    .strokeBorder(colors.border, lineWidth: 1)
            )
            .foregroundStyle(Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Attachment: \(attachment.name ?? "file")")
    }
}

/// Citation part — source row; taps emit `aiux.citation.open` (host validates
/// the target before navigating, §23).
struct AICitationRow: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit

    let citation: AIUXCitation

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        Button {
            emit(AIUXAction(id: AIUXAction.citationOpen, payload: [
                "citationId": citation.id.map(AIUXJSONValue.string) ?? .null,
                "uri": citation.uri.map(AIUXJSONValue.string) ?? .null,
                "title": citation.title.map(AIUXJSONValue.string) ?? .null,
            ]))
        } label: {
            VStack(alignment: .leading, spacing: theme.space(.xs)) {
                HStack(spacing: theme.space(.xs)) {
                    Image(systemName: "link")
                    Text(citation.title ?? citation.uri ?? "Source")
                        .font(theme.typography.label)
                        .lineLimit(1)
                    if let source = citation.source {
                        Text(source)
                            .font(theme.typography.caption)
                            .foregroundStyle(colors.muted)
                    }
                }
                if let snippet = citation.snippet {
                    Text(snippet)
                        .font(theme.typography.caption)
                        .foregroundStyle(colors.muted)
                        .lineLimit(2)
                }
            }
            .padding(theme.space(.sm))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.sm)))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.radius(.sm))
                    .strokeBorder(colors.border, lineWidth: 1)
            )
            .foregroundStyle(colors.accent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Citation: \(citation.title ?? citation.uri ?? "source")")
    }
}

/// Inline `status` part.
struct AIStatusLine: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let text: String
    let level: AIUXStatusLevel?

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        Label(text, systemImage: aiuxStatusIcon(level))
            .font(theme.typography.caption)
            .foregroundStyle(colors.statusLevel(level))
            .accessibilityLabel("Status: \(text)")
    }
}

/// Inline `progress` part.
struct AIProgressLine: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let progress: AIUXProgress

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: theme.space(.xs)) {
            if let fraction = progress.fraction {
                ProgressView(value: fraction)
                    .tint(colors.accent)
            } else {
                ProgressView()
                    .tint(colors.accent)
            }
            if let label = progress.label {
                Text(label)
                    .font(theme.typography.caption)
                    .foregroundStyle(colors.muted)
            }
        }
        .accessibilityLabel("Progress: \(progress.label ?? "in progress")")
    }
}

/// `error` part with retry affordance — emits `aiux.error.retry`, never
/// retries itself.
struct AIErrorPart: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit

    let partId: String
    let error: AIUXError

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: theme.space(.xs)) {
            Label(error.message, systemImage: "exclamationmark.triangle")
                .font(theme.typography.label)
            Text(error.code)
                .font(theme.typography.caption)
                .foregroundStyle(colors.muted)
            if error.retryable == true {
                Button("Retry") {
                    emit(AIUXAction(id: AIUXAction.errorRetry, payload: [
                        "partId": .string(partId),
                        "code": .string(error.code),
                    ]))
                }
                .font(theme.typography.label)
                .foregroundStyle(colors.accent)
                .accessibilityHint("Asks the host to retry this operation")
            }
        }
        .foregroundStyle(colors.destructive)
        .padding(theme.space(.sm))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.destructive.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.sm)))
        .accessibilityLabel("Error \(error.code): \(error.message)")
    }
}

func aiuxStatusIcon(_ level: AIUXStatusLevel?) -> String {
    switch level {
    case .info, .none: return "info.circle"
    case .success: return "checkmark.circle"
    case .warning: return "exclamationmark.triangle"
    case .error: return "xmark.octagon"
    }
}

// MARK: - Platform copy

#if canImport(UIKit)
import UIKit
func aiuxCopyToPasteboard(_ string: String) {
    UIPasteboard.general.string = string
}
#elseif canImport(AppKit)
import AppKit
func aiuxCopyToPasteboard(_ string: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
}
#else
func aiuxCopyToPasteboard(_ string: String) {}
#endif
