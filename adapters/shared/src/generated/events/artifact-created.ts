// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyondigital/aiux-protocol-types generate
/* eslint-disable */

/**
 * The canonical event envelope. `P` defaults to a raw JSON payload for dispatch-time parsing; typed instantiations (`AiuxEvent<SessionCreated>`) are used for schema generation and typed producers.
 */
export interface ArtifactCreatedEvent {
  /**
   * Unique event identifier — replays of a known id are ignored.
   */
  eventId: string;
  /**
   * Type-specific payload.
   */
  payload: ArtifactCreated;
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
 * `artifact.created`.
 */
export interface ArtifactCreated {
  /**
   * The artifact.
   */
  artifact: Artifact;
  /**
   * Protocol version carried by the payload.
   */
  protocolVersion?: string;
  [k: string]: unknown | undefined;
}
/**
 * A versioned artifact produced during the session.
 */
export interface Artifact {
  /**
   * Inline content (text/code/JSON).
   */
  content?: string | null;
  /**
   * Stable identifier.
   */
  id: string;
  /**
   * Semantic kind, e.g. `code`, `document`, `dashboard`.
   */
  kind: string;
  /**
   * Free-form host metadata.
   */
  metadata?: unknown;
  /**
   * Monotonic revision; bumps on every `artifact.updated`.
   */
  revision?: number;
  /**
   * Display title.
   */
  title?: string | null;
  /**
   * External content URI (host-mediated).
   */
  uri?: string | null;
  [k: string]: unknown | undefined;
}
