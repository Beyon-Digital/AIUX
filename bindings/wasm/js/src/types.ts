/**
 * Public types for `@beyondigital/aiux-core`.
 *
 * The wire contract is JSON end-to-end (docs/PLAN.md §4, ADR 0001): the Rust
 * core owns every semantic, and no internal core type ever crosses the
 * boundary. Protocol entity shapes (event payloads, session config, snapshot
 * bodies) are therefore opaque JSON here.
 *
 * TODO: replace the opaque aliases with generated types once
 * `protocol/schemas/v1` lands (Phase 1).
 */

/** A JSON string as it crosses the session boundary. */
export type JsonString = string;

/** Any JSON-serializable object. */
export type JsonObject = Record<string, unknown>;

/** Opaque session config payload (`protocolVersion`, sessionId, capabilities…). */
export type SessionConfig = JsonObject;

/** Opaque protocol event (must carry eventId/sessionId/sequence/type/payload). */
export type AiuxEvent = JsonObject;

/** Opaque canonical render snapshot produced by `AiuxSession.snapshot()`. */
export type SessionSnapshot = JsonObject;

/**
 * Per-dispatch accounting returned by `dispatch`/`dispatchBatch`.
 * Mirrors `aiux_protocol::DispatchReport` (camelCase serde).
 */
export interface DispatchReport {
  /** Events that mutated state. */
  applied: number;
  /** Duplicate `eventId`s safely ignored (idempotency). */
  duplicatesIgnored: number;
  /** Events buffered pending missing earlier sequences. */
  buffered: number;
}

/** `kind` tag of `aiux_protocol::ProtocolError` (camelCase serde). */
export type ProtocolErrorKind =
  | "invalidEvent"
  | "sequenceGap"
  | "unsupported"
  | "corruptState";

/** Parsed shape of the JSON `ProtocolError` payload crossing the boundary. */
export interface ProtocolErrorPayload {
  kind: ProtocolErrorKind;
  detail?: string;
  expected?: number;
  received?: number;
}
