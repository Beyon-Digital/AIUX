import { render, type RenderResult } from "@testing-library/react";
import type { ReactElement } from "react";
import {
  AiuxRenderContext,
  EMPTY_ENTITIES,
  type AiuxRenderContextValue,
  type EntityIndex,
} from "../src/context.js";
import { resolveTheme } from "../src/theme.js";
import type {
  AiuxAction,
  AiuxSessionLike,
  AiuxSnapshot,
} from "../src/types.js";

/** Mutable `AiuxSessionLike` stub — `emit()` replaces the snapshot + notifies. */
export function stubSession(initial: AiuxSnapshot): AiuxSessionLike & {
  emit(next: AiuxSnapshot): void;
} {
  let current = initial;
  const listeners = new Set<(s: unknown) => void>();
  return {
    snapshot: () => current,
    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    emit(next) {
      current = next;
      for (const l of listeners) l(next);
    },
  };
}

export function renderWithContext(
  ui: ReactElement,
  options: {
    onAction?: (action: AiuxAction) => void;
    entities?: EntityIndex;
    capabilities?: Record<string, boolean>;
  } = {},
): RenderResult {
  const value: AiuxRenderContextValue = {
    theme: resolveTheme(),
    onAction: options.onAction,
    entities: options.entities ?? EMPTY_ENTITIES,
    customNodes: {},
    capabilityEnabled: (id) => options.capabilities?.[id] ?? true,
  };
  return render(
    <AiuxRenderContext.Provider value={value}>
      {ui}
    </AiuxRenderContext.Provider>,
  );
}
