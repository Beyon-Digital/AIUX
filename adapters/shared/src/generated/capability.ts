// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyondigital/aiux-protocol-types generate
/* eslint-disable */

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
