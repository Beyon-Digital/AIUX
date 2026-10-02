import type { AiuxEvent, JsonString } from "./types.js";

/**
 * Flush-policy knobs for {@link EventBuffer} (docs/PLAN.md §10/§22).
 *
 * The chosen defaults are provisional starting values pending real-device
 * benchmarks (plan §10: "Benchmark before permanently selecting a value").
 */
export interface EventBufferPolicy {
  /**
   * Wall-clock window after the first queued event before the buffer flushes.
   * Recommended band: {@link MIN_FLUSH_INTERVAL_MS}–
   * {@link MAX_FLUSH_INTERVAL_MS}. Default {@link DEFAULT_FLUSH_INTERVAL_MS}.
   */
  flushIntervalMs?: number;
  /**
   * Flush immediately once this many events are queued.
   * Default {@link DEFAULT_MAX_EVENTS}.
   */
  maxEvents?: number;
  /**
   * Flush immediately once the queued payload reaches this many bytes
   * (serialized UTF-8 JSON). Default {@link DEFAULT_MAX_BYTES}.
   */
  maxBytes?: number;
  /**
   * Sink for errors thrown by the sink on a *timer-triggered* flush. Sync
   * flushes (`flush()`, a size-triggered flush inside `push()`, `close()`)
   * propagate the error to the caller instead. Defaults to rethrowing
   * asynchronously so a failed flush can never be lost silently; events stay
   * queued and are retried on the next window either way.
   */
  onFlushError?: (error: unknown) => void;
}

/** Default time window: mid-band of the plan's suggested 16–50 ms. */
export const DEFAULT_FLUSH_INTERVAL_MS = 32;
/** Lowest allowed `flushIntervalMs` (plan §10 band). */
export const MIN_FLUSH_INTERVAL_MS = 16;
/** Highest allowed `flushIntervalMs` (plan §10 band). */
export const MAX_FLUSH_INTERVAL_MS = 50;
/** Default event-count threshold. */
export const DEFAULT_MAX_EVENTS = 64;
/** Default payload-size threshold (64 KiB of serialized events). */
export const DEFAULT_MAX_BYTES = 64 * 1024;

export interface ResolvedEventBufferPolicy {
  flushIntervalMs: number;
  maxEvents: number;
  maxBytes: number;
  onFlushError?: ((error: unknown) => void) | undefined;
}

function resolvePolicy(policy: EventBufferPolicy): ResolvedEventBufferPolicy {
  const flushIntervalMs = policy.flushIntervalMs ?? DEFAULT_FLUSH_INTERVAL_MS;
  if (
    !Number.isFinite(flushIntervalMs) ||
    flushIntervalMs < MIN_FLUSH_INTERVAL_MS ||
    flushIntervalMs > MAX_FLUSH_INTERVAL_MS
  ) {
    throw new RangeError(
      `aiux-core: flushIntervalMs must be within ${MIN_FLUSH_INTERVAL_MS}–${MAX_FLUSH_INTERVAL_MS} ms (got ${flushIntervalMs})`,
    );
  }
  const maxEvents = policy.maxEvents ?? DEFAULT_MAX_EVENTS;
  if (!Number.isInteger(maxEvents) || maxEvents < 1) {
    throw new RangeError(
      `aiux-core: maxEvents must be a positive integer (got ${maxEvents})`,
    );
  }
  const maxBytes = policy.maxBytes ?? DEFAULT_MAX_BYTES;
  if (!Number.isFinite(maxBytes) || maxBytes < 1) {
    throw new RangeError(
      `aiux-core: maxBytes must be a positive number (got ${maxBytes})`,
    );
  }
  return { flushIntervalMs, maxEvents, maxBytes, onFlushError: policy.onFlushError };
}

// UTF-8 byte length without TextEncoder — this module also runs in
// non-DOM engines (RN Hermes), so it can't rely on DOM-lib globals.
function utf8Length(s: string): number {
  let n = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c < 0x80) n += 1;
    else if (c < 0x800) n += 2;
    else if (c >= 0xd800 && c <= 0xdbff && i + 1 < s.length) {
      const c2 = s.charCodeAt(i + 1);
      if (c2 >= 0xdc00 && c2 <= 0xdfff) {
        n += 4;
        i++;
      } else {
        n += 3;
      }
    } else n += 3;
  }
  return n;
}

/**
 * Streaming event buffer (docs/PLAN.md §10/§22): accumulates protocol events
 * and flushes them as one JSON array so streaming deltas never cross the FFI
 * boundary per token.
 *
 * Flush triggers, whichever comes first:
 * - `flushIntervalMs` elapsed since the first queued event (time window), or
 * - `maxEvents` queued events / `maxBytes` queued payload bytes (size).
 *
 * Events are serialized once at `push()` — the same bytes drive both the size
 * accounting and the batched payload, so a flush is a single string join.
 */
export class EventBuffer<T = void> {
  readonly #sink: (eventsJson: JsonString) => T;
  readonly #policy: ResolvedEventBufferPolicy;
  /** Serialized event payloads, in arrival order. */
  #pending: string[] = [];
  /** Total serialized bytes of `#pending` (event payloads only). */
  #bytes = 0;
  #timer: ReturnType<typeof setTimeout> | undefined;
  #closed = false;

  constructor(sink: (eventsJson: JsonString) => T, policy: EventBufferPolicy = {}) {
    this.#sink = sink;
    this.#policy = resolvePolicy(policy);
  }

  /** Number of queued (not yet flushed) events. */
  get pending(): number {
    return this.#pending.length;
  }

  /** Serialized bytes currently queued (event payloads only). */
  get pendingBytes(): number {
    return this.#bytes;
  }

  get closed(): boolean {
    return this.#closed;
  }

  /**
   * Queue one event. May flush synchronously when a size threshold is hit;
   * otherwise schedules a flush at the time window.
   */
  push(event: AiuxEvent | JsonString): void {
    if (this.#closed) {
      throw new Error("aiux-core: EventBuffer is closed");
    }
    const json = typeof event === "string" ? event : JSON.stringify(event);
    this.#pending.push(json);
    this.#bytes += utf8Length(json);
    if (
      this.#pending.length >= this.#policy.maxEvents ||
      this.#bytes >= this.#policy.maxBytes
    ) {
      this.flush();
      return;
    }
    this.#schedule();
  }

  /**
   * Flush all queued events as one JSON array to the sink, or return
   * `undefined` when empty. On sink failure the events are requeued (order
   * preserved) and retried on the next window; the error propagates.
   */
  flush(): T | undefined {
    if (this.#pending.length === 0) {
      this.#clearTimer();
      return undefined;
    }
    const drained = this.#pending;
    const drainedBytes = this.#bytes;
    this.#pending = [];
    this.#bytes = 0;
    this.#clearTimer();
    try {
      return this.#sink(`[${drained.join(",")}]`);
    } catch (error) {
      this.#pending = drained.concat(this.#pending);
      this.#bytes += drainedBytes;
      this.#schedule();
      throw error;
    }
  }

  /** Flush anything queued and stop accepting new events. */
  close(): T | undefined {
    if (this.#closed) return undefined;
    const result = this.flush();
    this.#closed = true;
    this.#clearTimer();
    return result;
  }

  #schedule(): void {
    if (this.#timer !== undefined || this.#pending.length === 0) return;
    this.#timer = setTimeout(() => {
      this.#timer = undefined;
      try {
        this.flush();
      } catch (error) {
        const onFlushError = this.#policy.onFlushError;
        if (onFlushError) {
          onFlushError(error);
        } else {
          // rethrow on a microtask — no queueMicrotask (DOM-only global)
          Promise.resolve().then(() => {
            throw error;
          });
        }
      }
    }, this.#policy.flushIntervalMs);
  }

  #clearTimer(): void {
    if (this.#timer === undefined) return;
    clearTimeout(this.#timer);
    this.#timer = undefined;
  }
}
