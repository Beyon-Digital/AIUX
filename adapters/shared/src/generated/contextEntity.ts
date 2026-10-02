// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyondigital/aiux-protocol-types generate
/* eslint-disable */

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
