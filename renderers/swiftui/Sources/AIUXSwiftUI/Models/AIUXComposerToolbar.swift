import Foundation

// MARK: - Composer toolbar contract (plan §8, §23)
//
// `AIUXComposerToolbar` customizes the composer controls row: hosts can
// hide the built-in controls (attach / tools / dictate) and append custom
// tools. Every control reports upward as an `AIUXAction` — a custom tool
// emits the `id` it was declared with (`aiux.composer.<name>` by
// convention); the host owns the behavior.
//
// ```swift
// AIConversation(
//     store: store,
//     composerToolbar: AIUXComposerToolbar(
//         dictate: false,
//         extra: [
//             AIUXComposerTool(
//                 id: "aiux.composer.docs",
//                 accessibilityLabel: "Attach docs",
//                 systemImage: "doc.text"
//             ),
//         ]
//     )
// )
// ```

/// One custom control in the composer toolbar.
public struct AIUXComposerTool: Identifiable, Sendable {
    /// Action id emitted on tap (prefix `aiux.composer.` by convention).
    public var id: String
    /// Accessibility label (and the UI-test selector).
    public var accessibilityLabel: String
    /// SF Symbol name rendered inside the 40pt control slot.
    public var systemImage: String

    public init(id: String, accessibilityLabel: String, systemImage: String) {
        self.id = id
        self.accessibilityLabel = accessibilityLabel
        self.systemImage = systemImage
    }
}

/// Which controls render in the composer toolbar, plus custom tools.
public struct AIUXComposerToolbar: Sendable {
    /// Show the `+` attach control (emits `aiux.composer.attach`).
    public var attach: Bool
    /// Show the accent-ringed tools toggle (emits `aiux.composer.tools`).
    public var tools: Bool
    /// Show the outline mic (emits `aiux.composer.dictate`).
    public var dictate: Bool
    /// Custom tools appended between the built-ins and the action circle.
    public var extra: [AIUXComposerTool]

    public init(
        attach: Bool = true,
        tools: Bool = true,
        dictate: Bool = true,
        extra: [AIUXComposerTool] = []
    ) {
        self.attach = attach
        self.tools = tools
        self.dictate = dictate
        self.extra = extra
    }

    /// All built-ins shown, no custom tools.
    public static let `default` = AIUXComposerToolbar()
}
