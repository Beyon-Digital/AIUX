import { describe, expect, it } from "vitest";

import {
  createEventValidator,
} from "../../../adapters/shared/src/testing";
import { createEventFactory } from "../src/index";

const validator = createEventValidator();
const NOW = "2026-01-01T00:00:00Z";

const factory = () =>
  createEventFactory("s1", { now: () => NOW });

describe("createEventFactory", () => {
  it("mints schema-valid envelopes for every v1 event type", () => {
    const f = factory();
    const events = [
      f.sessionCreated({ id: "s1", title: "t" }),
      f.runStarted({ id: "r1", status: "running", startedAt: NOW }),
      f.messageCreated({ id: "m1", role: "assistant", status: "streaming" }),
      f.partAdded("m1", { id: "p1", type: "text", text: "" }),
      f.textDelta("m1", "p1", "hello"),
      f.partUpdated("m1", "p1", { id: "p1", type: "text", text: "hello" }),
      f.messageUpdated("m1", { status: "complete" }),
      f.toolStarted({ id: "t1", name: "search", status: "running" }),
      f.toolProgress("t1", { current: 1, total: 2 }),
      f.toolCompleted("t1", { hits: 3 }),
      f.toolStarted({ id: "t2", name: "write", status: "running" }),
      f.toolFailed("t2", { code: "io", message: "disk full" }),
      f.approvalRequested({ id: "a1", prompt: "Run rm -rf?", status: "requested" }),
      f.approvalResolved("a1", { decision: "approved", resolvedBy: "user" }),
      f.artifactCreated({ id: "art1", kind: "code", title: "x.ts" }),
      f.artifactUpdated("art1", { title: "y.ts" }),
      f.runCompleted("r1", { ok: true }),
      f.runCancelled("r2", "user asked"),
      f.runFailed("r3", { code: "boom", message: "failed" }),
      f.surfaceCreated({ id: "sf1", revision: 0, root: { type: "surface", id: "sf1" } }),
    ];
    expect(events).toHaveLength(20);
    for (const e of events) validator.assertValid(e);
  });

  it("auto-increments sequence, timestamps, and keeps eventIds unique", () => {
    const f = factory();
    const a = f.textDelta("m1", "p1", "a");
    const b = f.textDelta("m1", "p1", "b");
    expect(a.sequence).toBe(0);
    expect(b.sequence).toBe(1);
    expect(a.timestamp).toBe(NOW);
    expect(a.eventId).not.toBe(b.eventId);
    expect(a.protocolVersion).toBe("0.1");
    expect(a.payload.protocolVersion).toBe("0.1");
    expect(f.peekSequence()).toBe(2);
  });

  it("honors startSequence and a custom eventId minter", () => {
    const f = createEventFactory("s9", {
      now: () => NOW,
      startSequence: 41,
      eventId: (seq) => `custom-${seq}`,
    });
    const e = f.runCancelled("r1");
    expect(e.sequence).toBe(41);
    expect(e.eventId).toBe("custom-41");
    validator.assertValid(e);
  });
});
