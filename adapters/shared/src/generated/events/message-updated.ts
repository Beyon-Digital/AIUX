// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyondigital/aiux-protocol-types generate
/* eslint-disable */

/**
 * Message author role.
 */
export type MessageRole = "user" | "assistant" | "system" | "tool";
/**
 * Message lifecycle status.
 */
export type MessageStatus = "streaming" | "complete" | "failed" | "cancelled";

/**
 * The canonical event envelope. `P` defaults to a raw JSON payload for dispatch-time parsing; typed instantiations (`AiuxEvent<SessionCreated>`) are used for schema generation and typed producers.
 */
export interface MessageUpdatedEvent {
  /**
   * Unique event identifier — replays of a known id are ignored.
   */
  eventId: string;
  /**
   * Type-specific payload.
   */
  payload: MessageUpdated;
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
 * `message.updated` — partial update; absent fields are untouched and parts are never modified here (they accumulate via `part.added`/`part.updated`).
 */
export interface MessageUpdated {
  /**
   * Message id.
   */
  messageId: string;
  /**
   * New metadata, if changing.
   */
  metadata?: unknown;
  /**
   * Protocol version carried by the payload.
   */
  protocolVersion?: string;
  /**
   * New role, if changing.
   */
  role?: MessageRole | null;
  /**
   * New status, if changing.
   */
  status?: MessageStatus | null;
  [k: string]: unknown | undefined;
}
