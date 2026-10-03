// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyond-digital/aiux-protocol-types generate
/* eslint-disable */

/**
 * Per-dispatch accounting returned by `dispatch`/`dispatch_batch`.
 */
export interface DispatchReport {
  /**
   * Events that mutated state.
   */
  applied: number;
  /**
   * Events buffered pending missing earlier sequences.
   */
  buffered: number;
  /**
   * Duplicate `eventId`s safely ignored (idempotency).
   */
  duplicatesIgnored: number;
  [k: string]: unknown | undefined;
}
