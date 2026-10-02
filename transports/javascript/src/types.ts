import type { AiuxEvent } from "@beyondigital/aiux-protocol-types";

/**
 * Minimal dispatch sink a host provides — one serialized `AIUXEvent[]` batch
 * per call. The aiux-core EventBuffer / `dispatchBatch(eventsJson)` entry
 * points satisfy this shape, but any function does.
 */
export type EventBatchSink = (eventsJson: string) => Promise<void> | void;

/**
 * The wire-adapter contract: an async-iterable source of `AIUXEvent[]`
 * batches. Adapters (`@beyondigital/aiux-adapter-*`) implement this; hosts may
 * also roll their own source and still use `streamToBatches`.
 */
export interface EventBatchSource extends AsyncIterable<AiuxEvent[]> {
  /** Stop producing and release the underlying connection, if any. */
  close?(): void;
}

/** A non-fatal adapter observation — bad wire data the stream survived. */
export interface AdapterIssue {
  kind: "malformed" | "unhandled" | "transport";
  /** Short machine-readable reason, e.g. `invalid-json`, `unknown-shape`. */
  reason: string;
  /** The offending raw item, when available. Never logged by default. */
  raw?: unknown;
}

/** Event types that end a run — adapters stop reconnecting after emitting one. */
export const TERMINAL_EVENT_TYPES = new Set([
  "run.completed",
  "run.failed",
  "run.cancelled",
]);

export const isTerminalEvent = (event: { type: string }): boolean =>
  TERMINAL_EVENT_TYPES.has(event.type);
