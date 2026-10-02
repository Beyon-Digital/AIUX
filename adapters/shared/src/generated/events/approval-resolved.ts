// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyondigital/aiux-protocol-types generate
/* eslint-disable */

/**
 * The decision carried by `approval.resolved`.
 */
export type ApprovalDecision = "approved" | "rejected" | "expired" | "executed";

/**
 * The canonical event envelope. `P` defaults to a raw JSON payload for dispatch-time parsing; typed instantiations (`AiuxEvent<SessionCreated>`) are used for schema generation and typed producers.
 */
export interface ApprovalResolvedEvent {
  /**
   * Unique event identifier — replays of a known id are ignored.
   */
  eventId: string;
  /**
   * Type-specific payload.
   */
  payload: ApprovalResolved;
  /**
   * Protocol version of this event.
   */
  protocolVersion?: string;
  /**
   * Monotonic sequence within the session (0-based).
   */
  sequence: number;
  /**
   * Owning session.
   */
  sessionId: string;
  /**
   * Event timestamp (ISO-8601, host-supplied — never core-generated).
   */
  timestamp: string;
  /**
   * Event type, e.g. `session.created`. Unknown values deserialize fine and fail later with `ProtocolError::Unsupported`.
   */
  type: string;
  [k: string]: unknown | undefined;
}
/**
 * `approval.resolved` — resolves a requested approval, or marks an approved one executed. Resolutions on an already-resolved approval are absorbed without effect so replays never re-execute (plan §23).
 */
export interface ApprovalResolved {
  /**
   * Approval id.
   */
  approvalId: string;
  /**
   * Protocol version carried by the payload.
   */
  protocolVersion?: string;
  /**
   * The resolution.
   */
  resolution: ApprovalResolution;
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
