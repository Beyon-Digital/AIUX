// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyondigital/aiux-protocol-types generate
/* eslint-disable */

/**
 * The canonical event envelope. `P` defaults to a raw JSON payload for dispatch-time parsing; typed instantiations (`AiuxEvent<SessionCreated>`) are used for schema generation and typed producers.
 */
export interface ArtifactUpdatedEvent {
  /**
   * Unique event identifier — replays of a known id are ignored.
   */
  eventId: string;
  /**
   * Type-specific payload.
   */
  payload: ArtifactUpdated;
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
 * `artifact.updated` — partial update; `revision` bumps automatically.
 */
export interface ArtifactUpdated {
  /**
   * Artifact id.
   */
  artifactId: string;
  /**
   * New inline content, if changing.
   */
  content?: string | null;
  /**
   * New metadata, if changing.
   */
  metadata?: unknown;
  /**
   * Protocol version carried by the payload.
   */
  protocolVersion?: string;
  /**
   * New title, if changing.
   */
  title?: string | null;
  /**
   * New external URI, if changing.
   */
  uri?: string | null;
  [k: string]: unknown | undefined;
}
