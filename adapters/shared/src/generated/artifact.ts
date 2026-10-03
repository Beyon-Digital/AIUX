// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyond-digital/aiux-protocol-types generate
/* eslint-disable */

/**
 * A versioned artifact produced during the session.
 */
export interface Artifact {
  /**
   * Inline content (text/code/JSON).
   */
  content?: string | null;
  /**
   * Stable identifier.
   */
  id: string;
  /**
   * Semantic kind, e.g. `code`, `document`, `dashboard`.
   */
  kind: string;
  /**
   * Free-form host metadata.
   */
  metadata?: unknown;
  /**
   * Monotonic revision; bumps on every `artifact.updated`.
   */
  revision?: number;
  /**
   * Display title.
   */
  title?: string | null;
  /**
   * External content URI (host-mediated).
   */
  uri?: string | null;
  [k: string]: unknown | undefined;
}
