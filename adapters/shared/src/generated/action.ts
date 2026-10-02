// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyondigital/aiux-protocol-types generate
/* eslint-disable */

/**
 * A semantic action emitted by interactive nodes (button, menu).
 *
 * Payloads are data only (§23); the host resolves `id` through its own policy before executing anything.
 */
export interface Action {
  /**
   * Semantic action identifier, e.g. `invoice.approve`.
   */
  id: string;
  /**
   * Arbitrary JSON payload carried to the host.
   */
  payload?: {
    [k: string]: unknown | undefined;
  };
  [k: string]: unknown | undefined;
}
