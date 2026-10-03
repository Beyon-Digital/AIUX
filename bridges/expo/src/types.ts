/**
 * Public types for `@beyond-digital/aiux-expo` (plan §10).
 *
 * The wire contract across the JS↔native boundary is JSON: protocol payloads
 * (context entities, capabilities, snapshots, action payloads) stay opaque
 * objects/JSON strings — the Rust core owns their semantics (ADR 0001/0005).
 */

/** Presentation mode for the native conversation surface (plan §14). */
export type AIConversationMode = "fullscreen" | "embedded";

/** Color role names from the theme contract (plan §7). */
export type AIUXColorRole =
  | "background"
  | "surface"
  | "surfaceElevated"
  | "userSurface"
  | "assistantSurface"
  | "accent"
  | "accentForeground"
  | "muted"
  | "mutedForeground"
  | "border"
  | "destructive"
  | "destructiveForeground"
  | "success"
  | "warning"
  | "foreground"
  | "inputSurface"
  | "codeSurface"
  | "codeForeground";

/**
 * A CSS-style color string the native side parses: `#rgb`, `#rrggbb`,
 * `#rrggbbaa`, `rgb(r,g,b)` or `rgba(r,g,b,a)`.
 */
export type AIUXColorValue = string;

/** Per-scheme role palette. */
export type AIUXColorRoles = Partial<Record<AIUXColorRole, AIUXColorValue>>;

/**
 * Theme roles supplied by the host (plan §7 — roles, not component styling).
 * `colors` may be flat (same palette for both appearances) or keyed by
 * `light`/`dark`.
 */
export interface AIUXThemeInput {
  colors?: AIUXColorRoles | { light?: AIUXColorRoles; dark?: AIUXColorRoles };
  spacing?: Partial<Record<"xs" | "sm" | "md" | "lg" | "xl", number>>;
  radius?: Partial<Record<"sm" | "md" | "lg" | "full", number>>;
  /** Base transition duration (seconds), or `"reduced"` to disable motion. */
  motion?: { duration?: number } | "reduced";
  density?: "compact" | "regular" | "spacious";
  /** Force an appearance regardless of the OS scheme. */
  colorScheme?: "light" | "dark" | "system";
}

/** Context entity bound to the session (protocol `contextEntity`). */
export interface AIUXContextEntity {
  id: string;
  kind: string;
  label: string;
  description?: string | null;
  uri?: string | null;
  data?: unknown;
}

/** Declared session capability (protocol `capability`). */
export interface AIUXCapability {
  id: string;
  description?: string | null;
  enabled?: boolean;
}

/** A semantic action emitted by the native surface (plan §23). */
export interface AIUXAction {
  id: string;
  payload: Record<string, unknown>;
}

/** Error surfaced by the native surface (`onError`). */
export interface AIUXErrorInfo {
  code: string;
  message: string;
}

/**
 * Opaque render snapshot (`AiuxSession.snapshot()` payload, parsed). Its shape
 * is the protocol's canonical snapshot — hosts should treat it as read-only
 * and versioned (plan §21).
 */
export type AIUXSnapshot = Record<string, unknown>;

/** A protocol event (opaque JSON envelope) or its JSON string form. */
export type AIUXEventLike = Record<string, unknown> | string;

/** Stock glyph names for custom composer tools (cross-boundary vocabulary). */
export type AIUXComposerGlyphName =
  | "sparkle"
  | "doc"
  | "photo"
  | "gear"
  | "globe"
  | "mic"
  | "search"
  | "plus"
  | "star";

/**
 * One custom control in the composer toolbar. Tapping it emits an
 * `AIUXAction` with `id` — the host owns the behavior (`aiux.composer.`
 * prefix by convention).
 */
export interface AIUXComposerToolSpec {
  /** Action id emitted on tap. */
  id: string;
  /** Accessibility label. */
  label: string;
  /** Stock glyph (defaults to `"sparkle"`). */
  glyph?: AIUXComposerGlyphName;
}

/**
 * Composer toolbar customization: hide built-in controls and/or append
 * custom tools. Serialized to JSON at the native boundary (like `theme`).
 */
export interface AIUXComposerToolbarSpec {
  /** Show the `+` attach control (default true). */
  attach?: boolean;
  /** Show the accent-ringed tools toggle (default false — opt-in). */
  tools?: boolean;
  /** Show the outline mic (default true). */
  dictate?: boolean;
  /** Custom tools appended between the built-ins and the action circle. */
  extra?: AIUXComposerToolSpec[];
}

/** Dispatch report returned by `dispatchBatch` (protocol `dispatchReport`). */
export interface AIUXDispatchReport {
  applied?: number;
  duplicatesIgnored?: number;
  buffered?: number;
}
