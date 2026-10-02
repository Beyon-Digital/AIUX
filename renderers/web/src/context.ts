import { createContext, useContext } from "react";
import type {
  AiuxAction,
  Approval,
  Artifact,
  Capability,
  SurfaceTree,
  Tool,
} from "./types.js";
import type { ResolvedAiuxTheme } from "./theme.js";

/** `onAction` sink — the host resolves every semantic action (§23). */
export type AiuxActionHandler = (action: AiuxAction) => void;

/** Session-entity index for part → entity lookups (tool/approval/artifact/surface). */
export interface EntityIndex {
  tools: Map<string, Tool>;
  approvals: Map<string, Approval>;
  artifacts: Map<string, Artifact>;
  surfaces: Map<string, SurfaceTree>;
}

export const EMPTY_ENTITIES: EntityIndex = {
  tools: new Map(),
  approvals: new Map(),
  artifacts: new Map(),
  surfaces: new Map(),
};

export function buildEntityIndex(snapshot: {
  tools?: Tool[];
  approvals?: Approval[];
  artifacts?: Artifact[];
  surfaces?: SurfaceTree[];
}): EntityIndex {
  return {
    tools: new Map((snapshot.tools ?? []).map((t) => [t.id, t])),
    approvals: new Map((snapshot.approvals ?? []).map((a) => [a.id, a])),
    artifacts: new Map((snapshot.artifacts ?? []).map((a) => [a.id, a])),
    surfaces: new Map((snapshot.surfaces ?? []).map((s) => [s.id, s])),
  };
}

export interface AiuxRenderContextValue {
  theme: ResolvedAiuxTheme;
  onAction: AiuxActionHandler | undefined;
  entities: EntityIndex;
  /** capabilityId → enabled; undeclared capabilities default to enabled. */
  capabilityEnabled(id: string): boolean;
}

export const AiuxRenderContext = createContext<AiuxRenderContextValue | null>(
  null,
);

export function useAiuxRenderContext(): AiuxRenderContextValue {
  const ctx = useContext(AiuxRenderContext);
  if (!ctx) {
    throw new Error("aiux-web: component used outside <AIConversation>");
  }
  return ctx;
}

/** Merge prop capabilities over session-declared ones (prop wins). */
export function capabilityResolver(
  capabilities: readonly Capability[] | undefined,
): (id: string) => boolean {
  const map = new Map<string, boolean>();
  for (const c of capabilities ?? []) {
    map.set(c.id, c.enabled !== false);
  }
  return (id) => map.get(id) ?? true;
}
