import { createContext, useContext, type ComponentType } from "react";
import type {
  AiuxAction,
  Approval,
  Artifact,
  Capability,
  SurfaceNode,
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

/** Host-registered renderer for a `custom` node kind (ADR 0007). */
export type AiuxCustomNodeComponent = ComponentType<{
  node: SurfaceNode;
}>;

export interface AiuxRenderContextValue {
  theme: ResolvedAiuxTheme;
  onAction: AiuxActionHandler | undefined;
  entities: EntityIndex;
  /** custom `kind` → host renderer; unregistered kinds fall back. */
  customNodes: Readonly<Record<string, AiuxCustomNodeComponent>>;
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
