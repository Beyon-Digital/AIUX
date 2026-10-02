import SwiftUI

// MARK: - Shared display helpers
//
// Small internal utilities used across views: tone→color mapping, markdown
// rendering, byte formatting, and the non-fatal "unsupported" placeholder.
// Nothing here invents styling — everything resolves through `AIUXTheme`.

extension AIUXResolvedColors {
    /// Map a semantic tone onto a palette color.
    func tone(_ tone: AIUXTone?) -> Color {
        switch tone {
        case .accent: return accent
        case .muted, .none, .default: return muted
        case .success: return success
        case .warning: return warning
        case .destructive: return destructive
        }
    }

    /// Map a status severity onto a palette color.
    func statusLevel(_ level: AIUXStatusLevel?) -> Color {
        switch level {
        case .info, .none: return accent
        case .success: return success
        case .warning: return warning
        case .error: return destructive
        }
    }
}

/// Render markdown into a `Text`, falling back to the literal source when the
/// markdown fails to parse. Uses `AttributedString(markdown:)` — native, and
/// it inherits the surrounding `font`/`foregroundStyle`.
func aiuxMarkdownText(_ source: String) -> Text {
    if let attributed = try? AttributedString(markdown: source) {
        return Text(attributed)
    }
    return Text(verbatim: source)
}

/// Human-readable byte count ("12 KB") for attachment rows.
func aiuxByteCount(_ bytes: UInt64?) -> String? {
    guard let bytes else { return nil }
    return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
}

/// Compact JSON string for free-form payloads (tool input/result, metadata).
func aiuxJSONDescription(_ value: AIUXJSONValue?) -> String? {
    guard let value else { return nil }
    if case .string(let s) = value { return s }
    let object = value.object
    guard JSONSerialization.isValidJSONObject(object),
          let data = try? JSONSerialization.data(
              withJSONObject: object,
              options: [.prettyPrinted, .sortedKeys]
          ),
          let string = String(data: data, encoding: .utf8)
    else { return nil }
    return string
}

/// A small icon keyed to a semantic attachment `mimeType` prefix.
func aiuxAttachmentIcon(mimeType: String?) -> String {
    guard let mimeType else { return "paperclip" }
    if mimeType.hasPrefix("image/") { return "photo" }
    if mimeType.hasPrefix("audio/") { return "waveform" }
    if mimeType.hasPrefix("video/") { return "film" }
    if mimeType.contains("pdf") { return "doc.richtext" }
    if mimeType.hasPrefix("text/") { return "doc.plaintext" }
    if mimeType.contains("zip") || mimeType.contains("archive") { return "archivebox" }
    return "paperclip"
}

/// A semantic icon name for a context entity `kind`.
func aiuxContextIcon(kind: String) -> String {
    switch kind.lowercased() {
    case "file", "document": return "doc"
    case "url", "link", "web": return "link"
    case "record", "entity", "object": return "shippingbox"
    case "user", "person", "contact": return "person"
    case "code", "repo", "repository": return "chevron.left.forwardslash.chevron.right"
    case "image": return "photo"
    default: return "tag"
    }
}

/// The non-fatal placeholder for unknown parts/nodes/references (plan §21 —
/// an unrecognized element degrades, never crashes the render).
struct AIUXUnsupported: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let kind: String
    let detail: String?

    init(kind: String, detail: String? = nil) {
        self.kind = kind
        self.detail = detail
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        HStack(spacing: theme.space(.sm)) {
            Image(systemName: "puzzlepiece.extension")
            Text(detail.map { "Unsupported \(kind): \($0)" } ?? "Unsupported \(kind)")
                .font(theme.typography.caption)
        }
        .foregroundStyle(colors.muted)
        .padding(.horizontal, theme.space(.md))
        .padding(.vertical, theme.space(.sm))
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.sm)))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.radius(.sm))
                .strokeBorder(colors.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
        )
        .accessibilityLabel("Unsupported content: \(kind)")
    }
}
