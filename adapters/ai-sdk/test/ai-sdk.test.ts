import { describe, expect, it } from "vitest";

import type { AdapterIssue } from "@beyond-digital/aiux-transport-js";

import type { AiuxEvent } from "../../shared/src/index";
import { createEventValidator } from "../../shared/src/testing";
import {
  createAiSdkAdapter,
  mapAiSdkPart,
  type AiSdkStreamPart,
} from "../src/index";
import { createEventFactory } from "@beyond-digital/aiux-transport-js";

const validator = createEventValidator();

const target = { runId: "r1", messageId: "m1", partId: "p1" };

const collect = async (
  parts: AiSdkStreamPart[],
): Promise<{ events: AiuxEvent[]; issues: AdapterIssue[] }> => {
  const issues: AdapterIssue[] = [];
  async function* stream() {
    for (const p of parts) yield p;
  }
  const adapter = createAiSdkAdapter(stream(), {
    sessionId: "s1",
    target,
    onIssue: (i) => issues.push(i),
  });
  const events: AiuxEvent[] = [];
  for await (const batch of adapter) events.push(...batch);
  for (const e of events) validator.assertValid(e);
  return { events, issues };
};

describe("createAiSdkAdapter", () => {
  it("maps v4 fullStream parts to the AIUX lifecycle", async () => {
    const { events, issues } = await collect([
      { type: "text-delta", textDelta: "Hello, " },
      { type: "text-delta", textDelta: "world" },
      {
        type: "tool-call",
        toolCallId: "tc1",
        toolName: "search",
        args: { q: "aiux" },
      },
      {
        type: "tool-result",
        toolCallId: "tc1",
        result: { hits: 2 },
      },
      { type: "finish", finishReason: "stop" },
    ]);
    expect(events.map((e) => e.type)).toEqual([
      "text.delta",
      "text.delta",
      "tool.started",
      "tool.completed",
      "run.completed",
    ]);
    expect(events[0]!.payload).toMatchObject({
      messageId: "m1",
      partId: "p1",
      delta: "Hello, ",
    });
    expect(events[2]!.payload).toMatchObject({
      tool: { id: "tc1", name: "search", status: "running", input: { q: "aiux" } },
    });
    expect(events[3]!.payload).toMatchObject({ toolId: "tc1", result: { hits: 2 } });
    expect(events[4]!.payload).toMatchObject({
      runId: "r1",
      result: { finishReason: "stop" },
    });
    // sequences are contiguous and ids unique
    expect(events.map((e) => e.sequence)).toEqual([0, 1, 2, 3, 4]);
    expect(new Set(events.map((e) => e.eventId)).size).toBe(5);
    expect(issues).toHaveLength(0);
  });

  it("maps v5 UIMessageChunk tool parts", async () => {
    const { events } = await collect([
      { type: "text-delta", delta: "hi" },
      { type: "tool-input-start", toolCallId: "t9", toolName: "fetch" },
      {
        type: "tool-input-available",
        toolCallId: "t9",
        toolName: "fetch",
        input: { url: "https://a" },
      },
      { type: "tool-output-available", toolCallId: "t9", output: "ok" },
      { type: "finish" },
    ]);
    expect(events.map((e) => e.type)).toEqual([
      "text.delta",
      "tool.started",
      "tool.completed",
      "run.completed",
    ]);
    // tool-input-start must not double-emit tool.started — the reducer
    // rejects the second start for the same tool id; the single start
    // carries the completed input from tool-input-available.
    const started = events.find((e) => e.type === "tool.started")!;
    expect((started.payload as { tool: { input: unknown } }).tool.input).toEqual(
      { url: "https://a" },
    );
  });

  it("maps error parts to run.failed with a schema-valid AiuxError", async () => {
    const { events } = await collect([
      { type: "text-delta", delta: "partial" },
      { type: "error", error: new Error("provider blew up") },
    ]);
    expect(events.map((e) => e.type)).toEqual(["text.delta", "run.failed"]);
    expect(events[1]!.payload).toMatchObject({
      runId: "r1",
      error: { code: "stream_error", message: "provider blew up" },
    });
  });

  it("maps abort to run.cancelled", async () => {
    const { events } = await collect([{ type: "abort", reason: "user stop" }]);
    expect(events[0]!.type).toBe("run.cancelled");
    expect(events[0]!.payload).toMatchObject({ runId: "r1", reason: "user stop" });
  });

  it("reports (and skips) unmapped part types without throwing", async () => {
    const { events, issues } = await collect([
      { type: "start" },
      { type: "reasoning-delta", delta: "hmm" },
      { type: "text-delta", delta: "visible" },
      { type: "finish" },
    ]);
    expect(events.map((e) => e.type)).toEqual(["text.delta", "run.completed"]);
    expect(issues).toEqual([
      expect.objectContaining({ kind: "unhandled", reason: "no-protocol-event" }),
      expect.objectContaining({ kind: "unhandled", reason: "unhandled-part" }),
    ]);
  });

  it("stops the stream after a terminal event", async () => {
    const { events } = await collect([
      { type: "finish" },
      { type: "text-delta", delta: "late" },
    ]);
    expect(events.map((e) => e.type)).toEqual(["run.completed"]);
  });
});

describe("mapAiSdkPart", () => {
  it("is usable standalone for custom pipelines", () => {
    const factory = createEventFactory("s2", { now: () => "2026-01-01T00:00:00Z" });
    const issues: AdapterIssue[] = [];
    const [event] = mapAiSdkPart(
      { type: "tool-call", toolCallId: "x", toolName: "n", args: {} },
      factory,
      target,
      (i) => issues.push(i),
    );
    validator.assertValid(event!);
    expect(event!.type).toBe("tool.started");
  });
});
