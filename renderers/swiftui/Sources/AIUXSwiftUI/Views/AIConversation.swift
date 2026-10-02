import SwiftUI

// MARK: - Conversation (plan §8, §14)
//
// `AIConversation` is the root renderer view: a scrollable stream of
// messages and their parts, auto-scrolling with streaming output. Two
// presentation modes (§14):
//   - `.fullscreen` — takes over the surface: context bar, message stream,
//     composer pinned at the bottom.
//   - `.embedded`   — just the message stream for embedding in host chrome
//                     (the host may place its own `AIComposer`).
//
// The view is driven by an `AIUXSessionStore` and emits actions via the
// `aiuxAction` environment — it holds no business logic.

/// Presentation mode for `AIConversation` (§14).
public enum AIUXConversationMode: String, Sendable {
    /// Owns the whole surface: context bar + stream + composer.
    case fullscreen
    /// Stream only, for embedding inside host layout.
    case embedded
}

/// The AIUX conversation surface.
public struct AIConversation: View {
    @ObservedObject public var store: AIUXSessionStore

    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var mode: AIUXConversationMode
    /// Optional override for the composer's placeholder text.
    public var composerPlaceholder: String
    /// Whether the composer renders in fullscreen mode (default true).
    public var showsComposer: Bool

    public init(
        store: AIUXSessionStore,
        mode: AIUXConversationMode = .fullscreen,
        composerPlaceholder: String = "Message…",
        showsComposer: Bool = true
    ) {
        self.store = store
        self.mode = mode
        self.composerPlaceholder = composerPlaceholder
        self.showsComposer = showsComposer
    }

    public var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(spacing: 0) {
            if mode == .fullscreen, !store.snapshot.context.isEmpty {
                AIContextBar(entities: store.snapshot.context)
            }

            messageStream
                .background(colors.background)

            if mode == .fullscreen && showsComposer {
                AIComposer(
                    runActive: store.snapshot.activeRunId != nil,
                    placeholder: composerPlaceholder
                )
            }
        }
        .background(colors.background)
        // Republish the resolved entity index to every child view.
        .environment(\.aiuxRenderModel, store.renderModel)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Message stream

    private var messageStream: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: theme.space(.md)) {
                    if store.snapshot.messages.isEmpty {
                        emptyState
                    }
                    ForEach(store.snapshot.messages) { message in
                        AIMessage(message: message)
                            .id(message.id)
                    }
                    // Bottom anchor for auto-scroll.
                    Color.clear
                        .frame(height: 1)
                        .id(scrollAnchorID)
                }
                .padding(.horizontal, theme.space(.md))
                .padding(.vertical, theme.space(.sm))
            }
            .onAppear {
                scrollToBottom(proxy, animated: false)
            }
            .onChange(of: store.renderModel) { _ in
                scrollToBottom(proxy, animated: true)
            }
        }
    }

    private var scrollAnchorID: String { "aiux-scroll-bottom" }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        let perform = { proxy.scrollTo(scrollAnchorID, anchor: .bottom) }
        if animated, !reduceMotion {
            withAnimation(theme.motion.standard, perform)
        } else {
            perform()
        }
    }

    private var emptyState: some View {
        let colors = theme.colors(for: colorScheme)
        return VStack(spacing: theme.space(.sm)) {
            Image(systemName: "sparkles")
                .font(theme.typography.title)
                .foregroundStyle(colors.accent)
            Text(store.snapshot.session?.title ?? "How can I help?")
                .font(theme.typography.heading)
            Text("Send a message to start the conversation.")
                .font(theme.typography.caption)
                .foregroundStyle(colors.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(theme.space(.xl))
        .accessibilityElement(children: .combine)
    }
}
