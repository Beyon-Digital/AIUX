// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyond-digital/aiux-protocol-types generate
/* eslint-disable */

/**
 * An AI interaction session.
 */
export interface Session {
  /**
   * Declared capabilities.
   */
  capabilities?: Capability[];
  /**
   * Context entities bound to the session.
   */
  context?: ContextEntity[];
  /**
   * Creation timestamp (ISO-8601, supplied by the host).
   */
  createdAt?: string | null;
  /**
   * Session identifier — matches the event envelope `sessionId`.
   */
  id: string;
  /**
   * Free-form host metadata.
   */
  metadata?: unknown;
  /**
   * Display title.
   */
  title?: string | null;
  [k: string]: unknown | undefined;
}
/**
 * A declared session capability (e.g. `tools.execute`, `files.upload`).
 */
export interface Capability {
  /**
   * Human-readable description.
   */
  description?: string | null;
  /**
   * Whether the capability is enabled (default true).
   */
  enabled?: boolean;
  /**
   * Capability identifier.
   */
  id: string;
  [k: string]: unknown | undefined;
}
/**
 * A contextual entity injected into the session (file, record, URL, ...).
 */
export interface ContextEntity {
  /**
   * Free-form structured data for the host/renderer.
   */
  data?: unknown;
  /**
   * Longer description.
   */
  description?: string | null;
  /**
   * Stable identifier.
   */
  id: string;
  /**
   * Semantic kind, e.g. `file`, `issue`, `customer`.
   */
  kind: string;
  /**
   * Display label.
   */
  label: string;
  /**
   * Link target for the renderer.
   */
  uri?: string | null;
  [k: string]: unknown | undefined;
}
