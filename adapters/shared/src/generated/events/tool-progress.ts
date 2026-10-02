// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyondigital/aiux-protocol-types generate
/* eslint-disable */

/**
 * The canonical event envelope. `P` defaults to a raw JSON payload for dispatch-time parsing; typed instantiations (`AiuxEvent<SessionCreated>`) are used for schema generation and typed producers.
 */
export interface ToolProgressEvent {
  /**
   * Unique event identifier — replays of a known id are ignored.
   */
  eventId: string;
  /**
   * Type-specific payload.
   */
  payload: ToolProgress;
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
 * `tool.progress`.
 */
export interface ToolProgress {
  /**
   * Latest progress.
   */
  progress: Progress;
  /**
   * Protocol version carried by the payload.
   */
  protocolVersion?: string;
  /**
   * Tool id.
   */
  toolId: string;
  [k: string]: unknown | undefined;
}
/**
 * Normalized progress value.
 */
export interface Progress {
  /**
   * Units complete.
   */
  current?: number | null;
  /**
   * Progress label.
   */
  label?: string | null;
  /**
   * Total units.
   */
  total?: number | null;
  [k: string]: unknown | undefined;
}
