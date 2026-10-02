import {
  createContext,
  useContext,
  useMemo,
  type JSX,
  type ReactNode,
} from "react";
import type { AiuxSessionLike } from "./types.js";

/**
 * Session registry — lets `<AIConversation sessionId="…">` resolve a live
 * `AiuxSession` the host created elsewhere. Map keyed by session id.
 */
const SessionsContext = createContext<ReadonlyMap<string, AiuxSessionLike>>(
  new Map(),
);

export function AiuxSessionProvider({
  sessions,
  children,
}: {
  sessions: ReadonlyMap<string, AiuxSessionLike> | Record<string, AiuxSessionLike>;
  children: ReactNode;
}): JSX.Element {
  const map = useMemo(
    () =>
      sessions instanceof Map
        ? sessions
        : new Map<string, AiuxSessionLike>(Object.entries(sessions)),
    [sessions],
  );
  return (
    <SessionsContext.Provider value={map}>{children}</SessionsContext.Provider>
  );
}

/** Resolve a session by id from the nearest `AiuxSessionProvider`. */
export function useAiuxSession(
  sessionId: string | undefined,
): AiuxSessionLike | undefined {
  const sessions = useContext(SessionsContext);
  return sessionId === undefined ? undefined : sessions.get(sessionId);
}
