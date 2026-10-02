// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyondigital/aiux-protocol-types generate
/* eslint-disable */

/**
 * The canonical event envelope. `P` defaults to a raw JSON payload for dispatch-time parsing; typed instantiations (`AiuxEvent<SessionCreated>`) are used for schema generation and typed producers.
 */
export interface SessionCreatedEvent {
  /**
   * Unique event identifier — replays of a known id are ignored.
   */
  eventId: string;
  /**
   * Type-specific payload.
   */
  payload: SessionCreated;
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
 * `session.created` — establishes session metadata.
 */
export interface SessionCreated {
  /**
   * Protocol version carried by the payload.
   */
  protocolVersion?: string;
  /**
   * The session entity.
   */
  session: Session;
  [k: string]: unknown | undefined;
}
/**
 * An AI interaction session.
 */
export interface Session {
  /**
   * Declared capabilities.
   */
  capabilities?: Capability[];
  /**
   * Context entities bound to the session.
   */
  context?: ContextEntity[];
  /**
   * Creation timestamp (ISO-8601, supplied by the host).
   */
  createdAt?: string | null;
  /**
   * Session identifier — matches the event envelope `sessionId`.
   */
  id: string;
  /**
   * Free-form host metadata.
   */
  metadata?: unknown;
  /**
   * Display title.
   */
  title?: string | null;
  [k: string]: unknown | undefined;
}
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
/**
 * A contextual entity injected into the session (file, record, URL, ...).
 */
export interface ContextEntity {
  /**
   * Free-form structured data for the host/renderer.
   */
  data?: unknown;
  /**
   * Longer description.
   */
  description?: string | null;
  /**
   * Stable identifier.
   */
  id: string;
  /**
   * Semantic kind, e.g. `file`, `issue`, `customer`.
   */
  kind: string;
  /**
   * Display label.
   */
  label: string;
  /**
   * Link target for the renderer.
   */
  uri?: string | null;
  [k: string]: unknown | undefined;
}
