// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyond-digital/aiux-protocol-types generate
/* eslint-disable */

/**
 * Run lifecycle status.
 */
export type RunStatus = "running" | "completed" | "failed" | "cancelled";

/**
 * The canonical event envelope. `P` defaults to a raw JSON payload for dispatch-time parsing; typed instantiations (`AiuxEvent<SessionCreated>`) are used for schema generation and typed producers.
 */
export interface RunStartedEvent {
  /**
   * Unique event identifier — replays of a known id are ignored.
   */
  eventId: string;
  /**
   * Type-specific payload.
   */
  payload: RunStarted;
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
 * `run.started` — begins an agent execution span.
 */
export interface RunStarted {
  /**
   * Context entities injected with this run.
   */
  context?: ContextEntity[];
  /**
   * Protocol version carried by the payload.
   */
  protocolVersion?: string;
  /**
   * The run.
   */
  run: Run;
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
/**
 * A run: one agent execution span within a session.
 */
export interface Run {
  /**
   * End timestamp (ISO-8601, host-supplied).
   */
  completedAt?: string | null;
  /**
   * Error on failure.
   */
  error?: AiuxError | null;
  /**
   * Stable identifier.
   */
  id: string;
  /**
   * Message the run responds to, if any.
   */
  inputMessageId?: string | null;
  /**
   * Result on success.
   */
  result?: unknown;
  /**
   * Previous run this run retries, if any.
   */
  retryOf?: string | null;
  /**
   * Start timestamp (ISO-8601, host-supplied).
   */
  startedAt?: string | null;
  /**
   * Lifecycle status.
   */
  status: RunStatus;
  [k: string]: unknown | undefined;
}
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
