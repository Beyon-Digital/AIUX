import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
/// Scalars render verbatim — `JSONSerialization` only accepts top-level
/// objects/arrays, so a bare `true`, `42`, or `null` result needs its own
/// path rather than disappearing.
func aiuxJSONDescription(_ value: AIUXJSONValue?) -> String? {
    guard let value else { return nil }
    switch value {
    case .string(let s):
        return s
    case .int(let i):
        return String(i)
    case .uint(let u):
        return String(u)
    case .number(let n):
        // Integral doubles print without the `.0`; below 2^53 every whole
        // Double converts exactly and stays far inside Int64.
        if n.truncatingRemainder(dividingBy: 1) == 0,
           n.magnitude < 9_007_199_254_740_992 {
            return String(Int64(n))
        }
        return String(n)
    case .bool(let b):
        return b ? "true" : "false"
    case .null:
        return "null"
    case .array, .object:
        break
    }
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

/// Decode an inline `data:image/…;base64,…` URI — rendered locally, never
/// fetched (the same surface the web `<img>` gets for free). Nil for
/// non-image, non-base64, oversized, or un-decodable URIs: payloads are
/// agent-controlled, so the source is capped at ~11 MB of base64 (~8 MB
/// decoded) before any allocation happens.
func aiuxDecodeDataImage(_ url: URL) -> Image? {
    let raw = url.absoluteString
    guard raw.lowercased().hasPrefix("data:image/"),
          let comma = raw.firstIndex(of: ",") else { return nil }
    let meta = raw[raw.startIndex..<comma].lowercased()
    guard meta.hasSuffix(";base64") else { return nil }
    let payload = raw[raw.index(after: comma)...]
    guard payload.count <= 11_000_000,
          let data = Data(base64Encoded: String(payload)),
          data.count <= 8 * 1024 * 1024
    else { return nil }
    #if canImport(UIKit)
    guard let image = UIImage(data: data) else { return nil }
    return Image(uiImage: image)
    #elseif canImport(AppKit)
    guard let image = NSImage(data: data) else { return nil }
    return Image(nsImage: image)
    #else
    return nil
    #endif
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
