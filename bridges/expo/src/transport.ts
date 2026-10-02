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
  /**
   * Flush, stop accepting events, and let the drain finish. Rejects when
   * batches remain undelivered after the drain — `push` can no longer
   * retrigger it (call `flush()` to retry the queue manually).
   */
  close(): Promise<void>;
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
  let activeDrain: Promise<void> | undefined;

  const drain = (): Promise<void> => {
    if (activeDrain) return activeDrain;
    // An empty queue must not mint `activeDrain` — the IIFE would finish
    // synchronously, clear the flag, then reassign the completed promise,
    // and every later drain() would reuse it without touching the queue.
    if (queue.length === 0) return Promise.resolve();
    const run = (async () => {
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
        activeDrain = undefined;
      }
    })();
    activeDrain = run;
    return run;
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
    close: async () => {
      buffer.close();
      // `push` can no longer retrigger the drain — if it stops on a failure
      // the final batches sit stranded. Await the drain and reject so the
      // undelivered count reaches the closer even with no onFlushError set
      // (flush() still retries the queue).
      await drain();
      if (queue.length > 0) {
        const error = new Error(
          `@beyondigital/aiux-expo: closed with ${queue.length} undelivered batch(es)`,
        );
        policy.onFlushError?.(error);
        throw error;
      }
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
