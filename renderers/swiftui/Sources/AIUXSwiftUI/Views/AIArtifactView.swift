import SwiftUI

// MARK: - Artifact (plan §8)
//
// `AIArtifactPreview` renders an artifact card (kind icon, title, revision)
// that opens a detail sheet on tap. Opening the artifact's URI emits
// `aiux.attachment.open` upward — navigation is host-mediated (§23).

/// Artifact card → detail sheet.
public struct AIArtifactPreview: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit

    public let artifact: AIUXArtifact

    @State private var detailPresented = false

    public init(artifact: AIUXArtifact) {
        self.artifact = artifact
    }

    public var body: some View {
        let colors = theme.colors(for: colorScheme)
        Button {
            detailPresented = true
            var payload: [String: AIUXJSONValue] = [
                "artifactId": .string(artifact.id),
            ]
            if let mode = artifact.workspace?.mode {
                payload["mode"] = .string(mode.rawValue)
            }
            emit(AIUXAction(id: AIUXAction.artifactOpen, payload: payload))
        } label: {
            VStack(alignment: .leading, spacing: theme.space(.xs)) {
                HStack(spacing: theme.space(.sm)) {
                    Image(systemName: icon)
                        .foregroundStyle(colors.accent)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(artifact.title ?? artifact.kind)
                            .font(theme.typography.label)
                            .lineLimit(1)
                        Text("\(artifact.kind) · rev \(artifact.revision)")
                            .font(theme.typography.caption)
                            .foregroundStyle(colors.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(colors.muted)
                }
                if let summary = artifact.preview?.summary {
                    Text(summary)
                        .font(theme.typography.caption)
                        .foregroundStyle(colors.muted)
                }
                if let descriptor = artifact.preview?.surface {
                    AISurface(tree: AIUXSurfaceTree(id: descriptor.id, root: descriptor.root))
                }
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
        .accessibilityLabel("Artifact: \(artifact.title ?? artifact.kind), revision \(artifact.revision)")
        .sheet(isPresented: $detailPresented) {
            AIArtifactDetail(artifact: artifact)
        }
    }

    private var icon: String {
        switch artifact.kind {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "document", "doc", "report": return "doc.text"
        case "diff", "patch": return "doc.badge.gearshape"
        case "plan": return "list.bullet.clipboard"
        case "image": return "photo"
        case "table", "spreadsheet": return "tablecells"
        default: return "doc"
        }
    }
}

/// Full artifact detail sheet — title, revision, scrollable content, and a
/// host-mediated "Open" affordance when the artifact carries a URI.
struct AIArtifactDetail: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit
    @Environment(\.dismiss) private var dismiss

    let artifact: AIUXArtifact

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.space(.md)) {
                    if let workspace = artifact.workspace,
                       let descriptor = workspace.surface {
                        AISurface(tree: AIUXSurfaceTree(id: descriptor.id, root: descriptor.root))
                    }
                    if let content = artifact.content {
                        Group {
                            if artifact.kind == "markdown" || artifact.kind == "document" {
                                aiuxMarkdownText(content)
                                    .font(theme.typography.body)
                            } else {
                                Text(content)
                                    .font(theme.typography.code)
                            }
                        }
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let metadata = aiuxJSONDescription(artifact.metadata) {
                        Text(metadata)
                            .font(theme.typography.caption)
                            .foregroundStyle(colors.muted)
                    }
                }
                .padding(theme.space(.lg))
            }
            .background(colors.background)
            .navigationTitle(artifact.title ?? artifact.kind)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if artifact.uri != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            emit(AIUXAction(id: AIUXAction.attachmentOpen, payload: [
                                "uri": artifact.uri.map(AIUXJSONValue.string) ?? .null,
                                "artifactId": .string(artifact.id),
                            ]))
                        } label: {
                            Label("Open", systemImage: "arrow.up.forward")
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
