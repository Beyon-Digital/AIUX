import type { AiuxEvent } from "@beyondigital/aiux-protocol-types";

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

  const flush = async (): Promise<void> => {
    if (buffer.length === 0) return;
    const batch = buffer;
    buffer = [];
    try {
      await sink(JSON.stringify(batch));
    } catch (error) {
      onError?.(error, "sink");
      throw error;
    }
    batches += 1;
    events += batch.length;
  };

  let pendingNext: Promise<IteratorResult<EventOrBatch>> | null = null;
  try {
    for (;;) {
      if (signal?.aborted) break;
      if (buffer.length >= maxBatchSize) {
        await flush();
        continue;
      }
      pendingNext ??= it.next();
      let result: IteratorResult<EventOrBatch> | "flush-tick";
      if (buffer.length > 0 && flushIntervalMs > 0) {
        result = await Promise.race([pendingNext, delay(flushIntervalMs).then(() => "flush-tick" as const)]);
      } else {
        result = await pendingNext;
      }
      if (result === "flush-tick") {
        // The iterator next() is still in flight — keep it for the next loop.
        await flush();
        continue;
      }
      pendingNext = null;
      if (result.done) break;
      const value = result.value;
      if (Array.isArray(value)) buffer.push(...value);
      else buffer.push(value as AiuxEvent);
    }
  } catch (error) {
    onError?.(error, "source");
    throw error;
  } finally {
    // Tell finite sources to release. Never block on a pending next().
    const released = it.return?.();
    if (pendingNext === null) await released?.catch(() => undefined);
    else void released?.catch(() => undefined);
  }
  await flush();
  return { batches, events };
}
