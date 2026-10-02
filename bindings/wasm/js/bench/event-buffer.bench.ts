/**
 * Tiny throughput benchmark for EventBuffer flush policies.
 *
 * The shipped defaults (32 ms window / 64 events / 64 KiB) are PROVISIONAL
 * starting values per docs/PLAN.md §10/§22 — revisit them once real-device
 * numbers exist (mobile bridge latency, large stream throughput). This bench
 * measures JS-side overhead only; it does not include wasm/FFI call cost.
 */
import { bench, describe } from "vitest";
import { EventBuffer } from "../src/buffer.js";
import { MockCore } from "../src/mock.js";
import { AiuxSession } from "../src/session.js";

const DELTA = {
  eventId: "e",
  sessionId: "s",
  sequence: 0,
  timestamp: 0,
  type: "text.delta",
  payload: { text: "lorem ipsum ".repeat(4) },
};

function sessionWithBuffer(policy: ConstructorParameters<typeof EventBuffer>[1]) {
  const core = new MockCore();
  const session = AiuxSession.create(core, { protocolVersion: "0.1" });
  const buffer = new EventBuffer<string>(
    (eventsJson) => {
      session.dispatchBatch(eventsJson);
      return eventsJson;
    },
    policy,
  );
  return { buffer, session };
}

describe("EventBuffer flush policies (provisional defaults)", () => {
  bench("default policy (32 ms / 64 events / 64 KiB) — 64-event flushes", () => {
    const { buffer } = sessionWithBuffer({ flushIntervalMs: 32 });
    for (let i = 0; i < 64; i++) buffer.push({ ...DELTA, sequence: i });
    buffer.close();
  });

  bench("size-triggered flush — 64 events pushed then flushed", () => {
    const { buffer } = sessionWithBuffer({ maxEvents: 64 });
    for (let i = 0; i < 64; i++) buffer.push({ ...DELTA, sequence: i });
    buffer.close();
  });

  bench("push overhead only (no flush in window)", () => {
    const { buffer } = sessionWithBuffer({
      flushIntervalMs: 50,
      maxEvents: Number.MAX_SAFE_INTEGER,
      maxBytes: Number.MAX_SAFE_INTEGER,
    });
    buffer.push({ ...DELTA, sequence: 1 });
    buffer.close();
  });
});
