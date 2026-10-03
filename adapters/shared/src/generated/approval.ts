// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyond-digital/aiux-protocol-types generate
/* eslint-disable */

/**
 * The decision carried by `approval.resolved`.
 */
export type ApprovalDecision = "approved" | "rejected" | "expired" | "executed";
/**
 * Approval lifecycle status (plan §23). `approved` → `executed` is the only permitted terminal-to-terminal transition; resolutions on an already resolved approval are absorbed as no-ops so replays never re-execute.
 */
export type ApprovalStatus = "requested" | "approved" | "rejected" | "expired" | "executed";

/**
 * An approval request tracked by the session.
 */
export interface Approval {
  /**
   * Semantic action executed on approval (data only — §23).
   */
  action?: Action | null;
  /**
   * Longer description.
   */
  description?: string | null;
  /**
   * Expiry timestamp (ISO-8601, host-supplied).
   */
  expiresAt?: string | null;
  /**
   * Stable identifier.
   */
  id: string;
  /**
   * What is being approved.
   */
  prompt: string;
  /**
   * Recorded resolution, once resolved.
   */
  resolution?: ApprovalResolution | null;
  /**
   * Lifecycle status.
   */
  status: ApprovalStatus;
  /**
   * Tool invocation this approval gates, if any.
   */
  toolId?: string | null;
  [k: string]: unknown | undefined;
}
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
/**
 * Recorded resolution of an approval.
 */
export interface ApprovalResolution {
  /**
   * Resolution outcome.
   */
  decision: ApprovalDecision;
  /**
   * Optional note attached to the resolution.
   */
  note?: string | null;
  /**
   * Resolution timestamp (ISO-8601, host-supplied).
   */
  resolvedAt?: string | null;
  /**
   * Who/what resolved it (`user`, `host`, `timeout`, ...).
   */
  resolvedBy?: string | null;
  [k: string]: unknown | undefined;
}
