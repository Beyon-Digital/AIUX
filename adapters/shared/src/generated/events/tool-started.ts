// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyond-digital/aiux-protocol-types generate
/* eslint-disable */

/**
 * Tool lifecycle status.
 */
export type ToolStatus = "running" | "completed" | "failed";

/**
 * The canonical event envelope. `P` defaults to a raw JSON payload for dispatch-time parsing; typed instantiations (`AiuxEvent<SessionCreated>`) are used for schema generation and typed producers.
 */
export interface ToolStartedEvent {
  /**
   * Unique event identifier — replays of a known id are ignored.
   */
  eventId: string;
  /**
   * Type-specific payload.
   */
  payload: ToolStarted;
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
 * `tool.started`.
 */
export interface ToolStarted {
  /**
   * Protocol version carried by the payload.
   */
  protocolVersion?: string;
  /**
   * The tool invocation.
   */
  tool: Tool;
  [k: string]: unknown | undefined;
}
/**
 * A tool invocation tracked by the session.
 */
export interface Tool {
  /**
   * Completion timestamp (ISO-8601, host-supplied).
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
   * Invocation input.
   */
  input?: unknown;
  /**
   * Tool name.
   */
  name: string;
  /**
   * Latest progress.
   */
  progress?: Progress | null;
  /**
   * Result on success.
   */
  result?: unknown;
  /**
   * Start timestamp (ISO-8601, host-supplied).
   */
  startedAt?: string | null;
  /**
   * Lifecycle status.
   */
  status: ToolStatus;
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
