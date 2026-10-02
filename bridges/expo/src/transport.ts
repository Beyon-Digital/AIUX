import { EventBuffer } from "@beyondigital/aiux-core/buffer";
import type { EventBufferPolicy } from "@beyondigital/aiux-core/buffer";

import { getNativeModule } from "./AIUXNative";
import type { AIUXDispatchReport, AIUXEventLike } from "./types";

/** Buffer policy — `flushIntervalMs` is validated to the 16–50 ms band. */
export type AIUXTransportPolicy = EventBufferPolicy;

/**
 * Batched event transport: protocol events pushed from JS coalesce in
 * `EventBuffer` (16–50 ms flush / size threshold), cross the boundary as
 * ordered `dispatchBatch` calls — never per token (plan §22, ADR 0005).
 *
 * `EventBuffer`'s sink is synchronous by contract, so dispatch itself runs
 * through an internal FIFO drained serially: batches reach the native
 * session strictly in push order, a failed batch stays queued (protocol
 * `eventId`s make a later replay safe via core dedup), and delivery resumes
 * on the next push or `flush()`.
 */
export interface AIUXTransport {
  /** Queue one event (object or JSON string). Throws once closed. */
  push(event: AIUXEventLike): void;
  /** Force a buffer flush + drain kick. */
  flush(): void;
  /** Flush, stop accepting events, and let the drain finish. */
  close(): void;
  /** Events waiting in the buffer (unserialized by a flush yet). */
  readonly pending: number;
  /** Batch payloads still awaiting native delivery. */
  readonly inflight: number;
  readonly closed: boolean;
}

/**
 * Create an `EventBuffer`-backed transport for a session already created via
 * `createAIUXSession` (or restored via `restoreAIUXSession`).
 *
 * `onDispatch` receives each parsed `DispatchReport`; `policy.onFlushError`
 * receives sink/dispatch failures (buffer policy errors still propagate to
 * the caller of `push`/`flush`).
 */
export function createAIUXTransport(
  sessionId: string,
  options: {
    policy?: AIUXTransportPolicy;
    onDispatch?: (report: AIUXDispatchReport) => void;
  } = {},
): AIUXTransport {
  const native = getNativeModule();
  if (!native) {
    throw new Error(
      "@beyondigital/aiux-expo: native module not linked. " +
        "Run `expo prebuild` (or open the app in a dev client build).",
    );
  }

  const { policy = {}, onDispatch } = options;
  const queue: string[] = [];
  let draining = false;

  const drain = async (): Promise<void> => {
    if (draining) return;
    draining = true;
    try {
      while (queue.length > 0) {
        const batch = queue[0]!;
        try {
          const report = await native.dispatchBatch(sessionId, batch);
          queue.shift();
          onDispatch?.(report);
        } catch (error) {
          // Keep the batch queued; a later push()/flush() resumes the drain.
          policy.onFlushError?.(error);
          break;
        }
      }
    } finally {
      draining = false;
    }
  };

  const buffer = new EventBuffer<void>(
    (eventsJson) => {
      queue.push(eventsJson);
      void drain();
    },
    policy,
  );

  return {
    push: (event) =>
      buffer.push(
        typeof event === "string" ? event : JSON.stringify(event),
      ),
    flush: () => {
      buffer.flush();
      void drain();
    },
    close: () => {
      buffer.close();
    },
    get pending() {
      return buffer.pending;
    },
    get inflight() {
      return queue.length;
    },
    get closed() {
      return buffer.closed;
    },
  };
}
