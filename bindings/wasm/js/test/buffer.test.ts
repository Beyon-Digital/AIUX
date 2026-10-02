import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  DEFAULT_FLUSH_INTERVAL_MS,
  EventBuffer,
  MockCore,
  AiuxSession,
} from "../src/index.js";

const EV = { type: "text.delta", payload: { t: "x" } };

function makeSink() {
  const calls: string[] = [];
  const sink = (eventsJson: string) => {
    calls.push(eventsJson);
  };
  return { sink, calls };
}

describe("EventBuffer", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it("flushes on the time window after the first queued event", () => {
    const { sink, calls } = makeSink();
    const buffer = new EventBuffer(sink);

    buffer.push(EV);
    buffer.push(EV);
    expect(calls).toHaveLength(0); // nothing crosses per event
    expect(buffer.pending).toBe(2);

    vi.advanceTimersByTime(DEFAULT_FLUSH_INTERVAL_MS - 1);
    expect(calls).toHaveLength(0);
    vi.advanceTimersByTime(1);
    expect(calls).toHaveLength(1);
    expect(JSON.parse(calls[0]!)).toEqual([EV, EV]);
    expect(buffer.pending).toBe(0);
    buffer.close();
  });

  it("does not extend the window for later events", () => {
    const { sink, calls } = makeSink();
    const buffer = new EventBuffer(sink, { flushIntervalMs: 32 });
    buffer.push(EV);
    vi.advanceTimersByTime(30);
    buffer.push(EV); // 2 ms before the window ends
    vi.advanceTimersByTime(2);
    expect(calls).toHaveLength(1); // window anchored to first event
    buffer.close();
  });

  it("flushes immediately on the event-count threshold", () => {
    const { sink, calls } = makeSink();
    const buffer = new EventBuffer(sink, { maxEvents: 3 });
    buffer.push(EV);
    buffer.push(EV);
    expect(calls).toHaveLength(0);
    buffer.push(EV);
    expect(calls).toHaveLength(1);
    expect(JSON.parse(calls[0]!)).toHaveLength(3);

    // The pending timer was cleared — no second, empty flush later.
    vi.advanceTimersByTime(10_000);
    expect(calls).toHaveLength(1);
    buffer.close();
  });

  it("flushes immediately on the byte threshold", () => {
    const { sink, calls } = makeSink();
    const event = { type: "x", payload: { t: "y".repeat(100) } };
    const buffer = new EventBuffer(sink, { maxBytes: 32 });
    buffer.push(event);
    expect(calls).toHaveLength(1);
    buffer.close();
  });

  it("flushes explicitly via flush() and returns the sink result", () => {
    const sink = (eventsJson: string) => JSON.parse(eventsJson).length as number;
    const buffer = new EventBuffer(sink);
    expect(buffer.flush()).toBeUndefined();
    buffer.push(EV);
    buffer.push(EV);
    expect(buffer.flush()).toBe(2);
    expect(buffer.pending).toBe(0);
    buffer.close();
  });

  it("never crosses the boundary per event", () => {
    const { sink, calls } = makeSink();
    const buffer = new EventBuffer(sink, { flushIntervalMs: 50 });
    for (let i = 0; i < 63; i++) buffer.push(EV);
    expect(calls).toHaveLength(0);
    vi.advanceTimersByTime(50);
    expect(calls).toHaveLength(1);
    buffer.close();
  });

  it("requeues events and retries when the sink fails", () => {
    const calls: string[] = [];
    let failed = false;
    const sink = (eventsJson: string) => {
      if (!failed) {
        failed = true;
        throw new Error("transient");
      }
      calls.push(eventsJson);
    };
    let failures = 0;
    const buffer = new EventBuffer(sink, {
      flushIntervalMs: 16,
      onFlushError: () => {
        failures += 1;
      },
    });
    buffer.push(EV);
    expect(() => buffer.flush()).toThrow("transient");
    expect(buffer.pending).toBe(1); // requeued, order preserved

    vi.advanceTimersByTime(16); // retry on next window
    expect(calls).toHaveLength(1);
    expect(failures).toBe(0); // the retry succeeded
    buffer.close();
  });

  it("routes timer-flush sink errors to onFlushError and retries", () => {
    const seen: unknown[] = [];
    const delivered: string[] = [];
    const buffer = new EventBuffer(
      (eventsJson: string) => {
        if (delivered.length === 0 && seen.length === 0) throw new Error("nope");
        delivered.push(eventsJson);
      },
      { flushIntervalMs: 16, onFlushError: (e) => seen.push(e) },
    );
    buffer.push(EV);
    vi.advanceTimersByTime(16);
    expect(seen).toHaveLength(1);
    expect(buffer.pending).toBe(1); // still queued for retry
    vi.advanceTimersByTime(16); // retry succeeds on next window
    expect(delivered).toHaveLength(1);
    expect(buffer.pending).toBe(0);
    buffer.close();
  });

  it("close() flushes pending events and rejects further pushes", () => {
    const { sink, calls } = makeSink();
    const buffer = new EventBuffer(sink);
    buffer.push(EV);
    buffer.close();
    expect(calls).toHaveLength(1);
    expect(buffer.closed).toBe(true);
    expect(() => buffer.push(EV)).toThrow(/closed/);
    expect(buffer.close()).toBeUndefined(); // idempotent
  });

  it("tracks pendingBytes of serialized payloads", () => {
    const { sink } = makeSink();
    const buffer = new EventBuffer(sink);
    buffer.push(EV);
    expect(buffer.pendingBytes).toBe(new TextEncoder().encode(JSON.stringify(EV)).byteLength);
    buffer.close();
  });

  it("validates the flush policy", () => {
    const { sink } = makeSink();
    expect(() => new EventBuffer(sink, { flushIntervalMs: 10 })).toThrow(RangeError);
    expect(() => new EventBuffer(sink, { flushIntervalMs: 100 })).toThrow(RangeError);
    expect(() => new EventBuffer(sink, { maxEvents: 0 })).toThrow(RangeError);
    expect(() => new EventBuffer(sink, { maxBytes: 0 })).toThrow(RangeError);
    new EventBuffer(sink, { flushIntervalMs: 16, maxEvents: 1, maxBytes: 1 }).close();
  });

  it("drives AiuxSession.dispatchBatch end-to-end", () => {
    const core = new MockCore();
    const session = AiuxSession.create(core, { protocolVersion: "0.1" });
    const buffer = new EventBuffer(
      (eventsJson) => session.dispatchBatch(eventsJson),
      { flushIntervalMs: 16 },
    );
    buffer.push(EV);
    buffer.push(EV);
    vi.advanceTimersByTime(16);

    expect(core.calls.dispatchBatch).toBe(1);
    expect(core.calls.dispatch).toBe(0);
    expect(session.snapshot()).toMatchObject({ events: [EV, EV] });
    session.dispose();
  });
});
