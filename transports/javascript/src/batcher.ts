import type { AiuxEvent } from "@beyond-digital/aiux-protocol-types";

import type { EventBatchSink } from "./types";

export interface StreamToBatchesOptions {
  /**
   * Flush as soon as the buffer reaches this many events. Default 100 — the
   * plan §22 benchmark batch size.
   */
  maxBatchSize?: number;
  /**
   * Flush a non-empty buffer after this many ms even if `maxBatchSize`
   * wasn't hit. Default 25 ms — inside the plan §10 suggested 16–50 ms
   * window. Pass 0 to flush only on size/end-of-stream.
   */
  flushIntervalMs?: number;
  /**
   * Called when the sink rejects or the source throws. A sink failure also
   * rethrows (stream stops) — the sink owns delivery policy; a source failure
   * propagates after this hook.
   */
  onError?: (error: unknown, context: "sink" | "source") => void;
  /** Abort pumping early; buffered events are flushed before returning. */
  signal?: AbortSignal;
}

export interface StreamToBatchesResult {
  batches: number;
  events: number;
}

type EventOrBatch = AiuxEvent | readonly AiuxEvent[];

type AnySource =
  | AsyncIterable<EventOrBatch>
  | Iterable<EventOrBatch>
  | AsyncIterator<EventOrBatch>;

const toAsyncIterator = (source: AnySource): AsyncIterator<EventOrBatch> => {
  const asAsync = source as AsyncIterable<EventOrBatch>;
  if (typeof asAsync[Symbol.asyncIterator] === "function") {
    return asAsync[Symbol.asyncIterator]();
  }
  const asSync = source as Iterable<EventOrBatch>;
  if (typeof asSync[Symbol.iterator] === "function") {
    const it = asSync[Symbol.iterator]();
    return { next: () => Promise.resolve(it.next()) };
  }
  const asIter = source as AsyncIterator<EventOrBatch>;
  if (typeof asIter.next === "function") return asIter;
  throw new TypeError("source must be an AsyncIterable, Iterable, or AsyncIterator");
};

const delay = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Pair an adapter (any `EventBatchSource`) with a `dispatchBatch`-style sink.
 * Events stream through in order; the sink gets one `JSON.stringify`ed
 * `AIUXEvent[]` per flush — bounded by size or the flush interval, per the
 * plan §10 batching guidance. Awaits the sink after each batch so delivery
 * ordering and backpressure hold.
 */
export async function streamToBatches(
  source: AnySource,
  sink: EventBatchSink,
  options: StreamToBatchesOptions = {},
): Promise<StreamToBatchesResult> {
  const maxBatchSize = options.maxBatchSize ?? 100;
  const flushIntervalMs = options.flushIntervalMs ?? 25;
  const onError = options.onError;
  const signal = options.signal;

  const it = toAsyncIterator(source);
  let buffer: AiuxEvent[] = [];
  let batches = 0;
  let events = 0;
  // Whether the propagating error came from the sink — lets the outer
  // catch avoid re-reporting a sink failure as a source failure. A boolean
  // rather than the error value itself: a source may legitimately throw
  // `undefined`, which would collide with an uninitialized sentinel.
  let sinkFailed = false;

  const flush = async (): Promise<void> => {
    if (buffer.length === 0) return;
    const batch = buffer;
    buffer = [];
    try {
      await sink(JSON.stringify(batch));
    } catch (error) {
      onError?.(error, "sink");
      sinkFailed = true;
      throw error;
    }
    batches += 1;
    events += batch.length;
  };

  // Resolves once when `signal` aborts; raced against a pending `next()` so
  // a source blocked forever still lets the pump exit. The listener is
  // detached in `finally` — `once` only cleans up if it fires, so a
  // normally-completing stream would otherwise leave it registered on a
  // long-lived AbortSignal.
  let abortListener: (() => void) | undefined;
  const aborted: Promise<"abort" | null> | null = signal
    ? new Promise((resolve) => {
        if (signal.aborted) resolve("abort");
        else {
          abortListener = () => resolve("abort");
          signal.addEventListener("abort", abortListener, {
            once: true,
          });
        }
      })
    : null;

  let pendingNext: Promise<IteratorResult<EventOrBatch>> | null = null;
  try {
    for (;;) {
      if (signal?.aborted) break;
      if (buffer.length >= maxBatchSize) {
        await flush();
        continue;
      }
      pendingNext ??= it.next();
      const racers: Promise<IteratorResult<EventOrBatch> | "flush-tick" | "abort" | null>[] =
        [pendingNext];
      if (buffer.length > 0 && flushIntervalMs > 0) {
        racers.push(delay(flushIntervalMs).then(() => "flush-tick" as const));
      }
      if (aborted) racers.push(aborted);
      const result = await Promise.race(racers);
      if (result === "abort") break;
      if (result === "flush-tick") {
        // The iterator next() is still in flight — keep it for the next loop.
        await flush();
        continue;
      }
      pendingNext = null;
      if (result === null || result.done) break;
      const value = result.value;
      const items = Array.isArray(value) ? value : [value];
      // Push one event at a time so an oversized yield still flushes at
      // maxBatchSize boundaries instead of producing an oversized batch.
      for (const item of items) {
        buffer.push(item as AiuxEvent);
        if (buffer.length >= maxBatchSize) await flush();
      }
    }
  } catch (error) {
    // A sink failure was already reported (and its batch cleared) inside
    // flush() — reporting it again as "source" would double-count.
    if (!sinkFailed) {
      onError?.(error, "source");
      // Still deliver already-consumed events before propagating — a
      // source failure must not strand a partial batch.
      try {
        await flush();
      } catch (flushError) {
        onError?.(flushError, "sink");
      }
    }
    throw error;
  } finally {
    if (abortListener !== undefined) {
      signal?.removeEventListener("abort", abortListener);
    }
    // Tell finite sources to release. Never block on a pending next().
    const released = it.return?.();
    if (pendingNext === null) await released?.catch(() => undefined);
    else void released?.catch(() => undefined);
  }
  await flush();
  return { batches, events };
}
