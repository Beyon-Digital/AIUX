import { describe, expect, it } from "vitest";

import type { AiuxEvent } from "../../../adapters/shared/src/index";
import {
  createEventValidator,
  loadFixture,
} from "../../../adapters/shared/src/testing";
import { createEventFactory, streamToBatches } from "../src/index";

const validator = createEventValidator();
const NOW = "2026-01-01T00:00:00Z";

const collect = () => {
  const batches: AiuxEvent[][] = [];
  return {
    batches,
    sink: async (eventsJson: string) => {
      batches.push(JSON.parse(eventsJson) as AiuxEvent[]);
    },
  };
};

const makeEvents = (n: number, sessionId = "s1"): AiuxEvent[] => {
  const f = createEventFactory(sessionId, { now: () => NOW });
  return Array.from({ length: n }, () => f.textDelta("m1", "p1", "x"));
};

describe("streamToBatches", () => {
  it("sends one JSON.stringify'ed batch for a short stream", async () => {
    const { batches, sink } = collect();
    const result = await streamToBatches(makeEvents(5), sink);
    expect(result).toEqual({ batches: 1, events: 5 });
    expect(batches).toHaveLength(1);
    expect(batches[0]).toHaveLength(5);
  });

  it("respects maxBatchSize boundaries", async () => {
    const { batches, sink } = collect();
    const events = makeEvents(10);
    const result = await streamToBatches(events, sink, { maxBatchSize: 4 });
    expect(result).toEqual({ batches: 3, events: 10 });
    expect(batches.map((b) => b.length)).toEqual([4, 4, 2]);
    expect(batches.flat()).toEqual(events);
  });

  it("accepts async iterables yielding batches or single events", async () => {
    const { batches, sink } = collect();
    const events = makeEvents(6);
    async function* source() {
      yield events[0]!;
      yield [events[1]!, events[2]!];
      yield events[3]!;
      yield [events[4]!, events[5]!];
    }
    const result = await streamToBatches(source(), sink, { maxBatchSize: 3 });
    expect(result).toEqual({ batches: 2, events: 6 });
    expect(batches.flat()).toEqual(events);
  });

  it("flushes a partial batch after flushIntervalMs while stalled", async () => {
    const { batches, sink } = collect();
    const events = makeEvents(2);
    async function* source() {
      yield events[0]!;
      await new Promise((r) => setTimeout(r, 40));
      yield events[1]!;
    }
    const result = await streamToBatches(source(), sink, {
      maxBatchSize: 50,
      flushIntervalMs: 5,
    });
    // First event flushes on the timer, second at end-of-stream.
    expect(result).toEqual({ batches: 2, events: 2 });
    expect(batches.map((b) => b.length)).toEqual([1, 1]);
  });

  it("propagates sink failures after reporting them", async () => {
    const seen: string[] = [];
    await expect(
      streamToBatches(
        makeEvents(3),
        async () => {
          throw new Error("sink exploded");
        },
        { onError: (e, ctx) => seen.push(`${ctx}:${(e as Error).message}`) },
      ),
    ).rejects.toThrow("sink exploded");
    expect(seen).toEqual(["sink:sink exploded"]);
  });

  it("propagates source failures after reporting them", async () => {
    const seen: string[] = [];
    async function* bad() {
      yield makeEvents(1)[0]!;
      throw new Error("stream died");
    }
    await expect(
      streamToBatches(bad(), async () => undefined, {
        onError: (e, ctx) => seen.push(`${ctx}:${(e as Error).message}`),
      }),
    ).rejects.toThrow("stream died");
    expect(seen).toEqual(["source:stream died"]);
  });
});

describe("conformance replay", () => {
  it.each([
    "streaming-response",
    "tool-success",
    "approval-accepted",
    "cancel",
    "duplicate-events",
    "out-of-order-events",
  ])(
    "%s survives the sink byte-for-byte with intact batch integrity",
    async (name) => {
      const fixture = loadFixture(name);
      const { batches, sink } = collect();
      const result = await streamToBatches(fixture.events as AiuxEvent[], sink, {
        maxBatchSize: 4,
      });
      // Every emitted JSON payload parses back to exactly the fixture events —
      // order, ids, and sequences preserved (the core owns dedup/reorder).
      const replayed = batches.flat();
      expect(replayed).toEqual(fixture.events);
      expect(result.events).toBe(fixture.events.length);
      for (const b of batches) {
        expect(b.length).toBeGreaterThan(0);
        expect(b.length).toBeLessThanOrEqual(4);
        for (const e of b) validator.assertValid(e);
      }
    },
  );
});
