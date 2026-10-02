import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  type JSX,
  type KeyboardEvent,
} from "react";
import { AIContextBar } from "./AIContextBar.jsx";
import { AIApproval } from "./AIApproval.jsx";
import { AIArtifactPreview } from "./AIArtifactPreview.jsx";
import { AIComposer } from "./AIComposer.jsx";
import { AIMessage } from "./AIMessage.jsx";
import { AISurface } from "./AISurface.jsx";
import { AIToolStatus } from "./AIToolStatus.jsx";
import {
  AiuxRenderContext,
  buildEntityIndex,
  capabilityResolver,
  type AiuxActionHandler,
  type AiuxCustomNodeComponent,
} from "./context.js";
import { useFileDrop, useSessionSnapshot } from "./hooks.js";
import { useAiuxSession } from "./session.jsx";
import { resolveTheme, themeCssVars, type AiuxTheme } from "./theme.js";
import {
  AIUX_ACTIONS,
  type AiuxSessionLike,
  type AiuxSnapshot,
  type Capability,
  type ContextEntity,
} from "./types.js";

export type AIConversationMode = "fullscreen" | "embedded";

export interface AIConversationProps {
  /** Live session object (from `@beyondigital/aiux-core`). */
  session?: AiuxSessionLike | undefined;
  /** Or a session id resolved via `AiuxSessionProvider`. */
  sessionId?: string | undefined;
  /** Theme overrides — roles map to CSS custom properties (plan §7). */
  theme?: AiuxTheme | undefined;
  /** Extra context entities merged into the context bar. */
  context?: readonly ContextEntity[] | undefined;
  /** Capability declarations gating affordances (undeclared = enabled). */
  capabilities?: readonly Capability[] | undefined;
  /** Host action sink — every interaction emits a semantic action. */
  onAction?: AiuxActionHandler | undefined;
  /** Host registry for `custom` surface nodes (ADR 0007). */
  customNodes?: Readonly<Record<string, AiuxCustomNodeComponent>> | undefined;
  /** Presentation mode (plan §14): `fullscreen` fills its container. */
  mode?: AIConversationMode | undefined;
}

const ARTICLE_SELECTOR = ".aiux-msg";

function collectUnreferenced(snapshot: AiuxSnapshot) {
  const referenced = new Set<string>();
  for (const message of snapshot.messages ?? []) {
    for (const part of message.parts ?? []) {
      if (part.type === "tool") referenced.add(`tool:${part.toolId}`);
      if (part.type === "approval") referenced.add(`approval:${part.approvalId}`);
      if (part.type === "artifact")
        referenced.add(`artifact:${part.artifactId}`);
      if (part.type === "surface") referenced.add(`surface:${part.surfaceId}`);
    }
  }
  return {
    tools: (snapshot.tools ?? []).filter(
      (t) => !referenced.has(`tool:${t.id}`),
    ),
    approvals: (snapshot.approvals ?? []).filter(
      (a) => !referenced.has(`approval:${a.id}`),
    ),
    artifacts: (snapshot.artifacts ?? []).filter(
      (a) => !referenced.has(`artifact:${a.id}`),
    ),
    surfaces: (snapshot.surfaces ?? []).filter(
      (s) => !referenced.has(`surface:${s.id}`),
    ),
  };
}

/**
 * The web renderer (plan §12): React subscription over the session snapshot
 * → DOM/ARIA output. Reads state, never mutates it — all user intent travels
 * through `onAction` so the host applies its policy and dispatches events.
 */
export function AIConversation({
  session: sessionProp,
  sessionId,
  theme: themeProp,
  context,
  capabilities,
  onAction,
  customNodes,
  mode = "fullscreen",
}: AIConversationProps): JSX.Element {
  // `useAiuxSession` must run unconditionally — it is a hook.
  const resolvedById = useAiuxSession(sessionId);
  const resolvedSession = sessionProp ?? resolvedById;
  if (!resolvedSession) {
    return (
      <MissingSession sessionId={sessionId} theme={themeProp} mode={mode} />
    );
  }
  return (
    <AIConversationLive
      session={resolvedSession}
      theme={themeProp}
      context={context}
      capabilities={capabilities}
      onAction={onAction}
      customNodes={customNodes}
      mode={mode}
    />
  );
}

function MissingSession({
  sessionId,
  theme,
  mode,
}: {
  sessionId?: string | undefined;
  theme?: AiuxTheme | undefined;
  mode: AIConversationMode;
}) {
  const resolved = resolveTheme(theme);
  return (
    <div
      className={`aiux aiux--${mode} aiux--empty`}
      data-aiux-theme={resolved.colorScheme}
      style={themeCssVars(resolved)}
    >
      <div className="aiux-empty" role="status">
        {sessionId
          ? `Waiting for session ${sessionId}…`
          : "No AIUX session connected."}
      </div>
    </div>
  );
}

function AIConversationLive({
  session,
  theme: themeProp,
  context,
  capabilities,
  onAction,
  customNodes,
  mode,
}: {
  session: AiuxSessionLike;
} & Omit<AIConversationProps, "session" | "sessionId">): JSX.Element {
  const snapshot = useSessionSnapshot(session);
  const theme = useMemo(() => resolveTheme(themeProp), [themeProp]);
  const entities = useMemo(() => buildEntityIndex(snapshot), [snapshot]);
  const contextValue = useMemo(
    () => ({
      theme,
      onAction,
      entities,
      customNodes: customNodes ?? {},
      capabilityEnabled: capabilityResolver([
        ...(snapshot.session?.capabilities ?? []),
        ...(capabilities ?? []),
      ]),
    }),
    [theme, onAction, entities, customNodes, capabilities, snapshot.session],
  );

  const unreferenced = useMemo(() => collectUnreferenced(snapshot), [snapshot]);
  const hasActivity =
    unreferenced.tools.length +
      unreferenced.approvals.length +
      unreferenced.artifacts.length +
      unreferenced.surfaces.length >
    0;
  const contextEntities = useMemo(() => {
    const seen = new Set<string>();
    const merged = [
      ...(snapshot.session?.context ?? []),
      ...(snapshot.context ?? []),
      ...(context ?? []),
    ];
    return merged.filter((e) =>
      seen.has(e.id) ? false : (seen.add(e.id), true),
    );
  }, [snapshot.session, snapshot.context, context]);
  const streaming = (snapshot.messages ?? []).some(
    (m) => m.status === "streaming",
  );
  const running = snapshot.activeRunId !== undefined;

  /* Scroll pin: follow new content unless the user scrolled up. */
  const feedRef = useRef<HTMLDivElement>(null);
  const stickToBottom = useRef(true);
  useEffect(() => {
    const feed = feedRef.current;
    if (feed && stickToBottom.current) feed.scrollTop = feed.scrollHeight;
  }, [snapshot]);

  const onFeedScroll = useCallback(() => {
    const feed = feedRef.current;
    if (!feed) return;
    stickToBottom.current =
      feed.scrollHeight - feed.scrollTop - feed.clientHeight < 48;
  }, []);

  /* Feed keyboard navigation: PageUp/PageDown step between articles,
   * Home/End jump to first/last (ARIA feed pattern). */
  const onFeedKeyDown = useCallback(
    (e: KeyboardEvent<HTMLDivElement>) => {
      const feed = feedRef.current;
      if (!feed) return;
      const articles = Array.from(
        feed.querySelectorAll<HTMLElement>(ARTICLE_SELECTOR),
      );
      if (articles.length === 0) return;
      const currentIndex = articles.findIndex(
        (a) => a === document.activeElement,
      );
      const move = (index: number) => {
        const clamped = Math.min(Math.max(index, 0), articles.length - 1);
        articles[clamped]?.focus();
      };
      // Keys from editable controls (surface fields, composer) stay local.
      const target = e.target as HTMLElement;
      if (target.closest?.("input, textarea, select, [contenteditable]")) return;
      switch (e.key) {
        case "PageDown":
          e.preventDefault();
          move(currentIndex + 1);
          break;
        case "PageUp":
          e.preventDefault();
          move(currentIndex <= 0 ? 0 : currentIndex - 1);
          break;
        case "Home":
        case "End": {
          e.preventDefault();
          move(e.key === "Home" ? 0 : articles.length - 1);
          break;
        }
      }
    },
    [],
  );

  const attachmentsEnabled = contextValue.capabilityEnabled("files.upload");
  const drop = useFileDrop(
    (files) =>
      onAction?.({ id: AIUX_ACTIONS.composerAttach, payload: { files } }),
    attachmentsEnabled,
  );

  const title = snapshot.session?.title ?? "Conversation";

  return (
    <AiuxRenderContext.Provider value={contextValue}>
      <div
        className={`aiux aiux--${mode}${drop.active ? " aiux--drop" : ""}`}
        data-aiux-theme={theme.colorScheme}
        data-aiux-density={theme.density}
        style={themeCssVars(theme)}
        {...drop.props}
      >
        <header className="aiux-header">
          <h2 className="aiux-header__title">{title}</h2>
          {running ? (
            <span className="aiux-header__status" role="status">
              Working…
            </span>
          ) : null}
        </header>

        <AIContextBar entities={contextEntities} />

        <div
          ref={feedRef}
          className="aiux-feed"
          role="feed"
          aria-label="Conversation"
          aria-busy={streaming || running}
          tabIndex={0}
          aria-keyshortcuts="PageDown PageUp Home End"
          onKeyDown={onFeedKeyDown}
          onScroll={onFeedScroll}
        >
          {(snapshot.messages ?? []).length === 0 && !hasActivity ? (
            <p className="aiux-empty">No messages yet.</p>
          ) : null}
          {(snapshot.messages ?? []).map((message) => (
            <AIMessage key={message.id} message={message} />
          ))}
          {hasActivity ? (
            <section
              className="aiux-activity"
              aria-label="Session activity"
            >
              {unreferenced.tools.map((tool) => (
                <AIToolStatus key={tool.id} tool={tool} />
              ))}
              {unreferenced.approvals.map((approval) => (
                <AIApproval key={approval.id} approval={approval} />
              ))}
              {unreferenced.artifacts.map((artifact) => (
                <AIArtifactPreview key={artifact.id} artifact={artifact} />
              ))}
              {unreferenced.surfaces.map((surface) => (
                <AISurface key={surface.id} surface={surface} />
              ))}
            </section>
          ) : null}
        </div>

        {drop.active ? (
          <div className="aiux-drop" aria-hidden>
            Drop files to attach
          </div>
        ) : null}

        <AIComposer
          onAction={onAction}
          attachmentsEnabled={attachmentsEnabled}
          placeholder="Message…"
        />
      </div>
    </AiuxRenderContext.Provider>
  );
}
