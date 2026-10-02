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

const DELTA = {
  eventId: "e",
  sessionId: "s",
  sequence: 0,
  timestamp: 0,
  type: "text.delta",
  payload: { text: "lorem ipsum ".repeat(4) },
};

// Pass-through sink: the bench header promises JS-side overhead only, and
// bench setup/teardown hooks run once per task (not per iteration) — a
// dispatching sink would accumulate session state across thousands of
// iterations and fold dispatch cost into the timed samples.
function bufferWith(policy: ConstructorParameters<typeof EventBuffer>[1]) {
  return new EventBuffer<string>((eventsJson) => eventsJson, policy);
}

// Buffer construction and the final close-flush live in setup/teardown so
// the timed region measures steady-state pushes only.
describe("EventBuffer flush policies (provisional defaults)", () => {
  let buffer: EventBuffer<string>;

  bench(
    "default policy (32 ms / 64 events / 64 KiB) — 64-event flushes",
    () => {
      for (let i = 0; i < 64; i++) buffer.push({ ...DELTA, sequence: i });
    },
    {
      setup: () => {
        buffer = bufferWith({ flushIntervalMs: 32 });
      },
      teardown: () => {
        buffer.close();
      },
    },
  );

  bench(
    "size-triggered flush — 64 events pushed then flushed",
    () => {
      for (let i = 0; i < 64; i++) buffer.push({ ...DELTA, sequence: i });
    },
    {
      setup: () => {
        buffer = bufferWith({ maxEvents: 64 });
      },
      teardown: () => {
        buffer.close();
      },
    },
  );

  bench(
    "push overhead only (no flush in window)",
    () => {
      buffer.push({ ...DELTA, sequence: 1 });
    },
    {
      setup: () => {
        buffer = bufferWith({
          flushIntervalMs: 50,
          maxEvents: Number.MAX_SAFE_INTEGER,
          maxBytes: Number.MAX_SAFE_INTEGER,
        });
      },
      teardown: () => {
        buffer.close();
      },
    },
  );
});
