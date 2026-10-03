// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyond-digital/aiux-protocol-types generate
/* eslint-disable */

/**
 * Structured error payload (entity name `error` on the wire).
 */
export interface AiuxError {
  /**
   * Stable machine-readable code.
   */
  code: string;
  /**
   * Additional detail for debugging.
   */
  detail?: unknown;
  /**
   * Human-readable message.
   */
  message: string;
  /**
   * Whether the operation may be retried.
   */
  retryable?: boolean | null;
  [k: string]: unknown | undefined;
}
