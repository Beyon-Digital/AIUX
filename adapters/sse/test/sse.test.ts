import { describe, expect, it } from "vitest";

import type { AdapterIssue } from "@beyond-digital/aiux-transport-js";

import type { AiuxEvent } from "../../shared/src/index";
import { createEventValidator } from "../../shared/src/testing";
import { createSseAdapter, type SseAdapterOptions } from "../src/index";

const validator = createEventValidator();

const sseResponse = (body: string, init: ResponseInit = { status: 200 }) =>
  new Response(
    new ReadableStream<Uint8Array>({
      start(c) {
        c.enqueue(new TextEncoder().encode(body));
        c.close();
      },
    }),
    init,
  );

const canonical = (over: Record<string, unknown> = {}) =>
  JSON.stringify({
    eventId: "e0",
    sessionId: "s1",
    sequence: 0,
    timestamp: "2026-01-01T00:00:00Z",
    type: "run.completed",
    payload: { protocolVersion: "0.1", runId: "r1" },
    ...over,
  });

const collect = async (
  opts: SseAdapterOptions,
): Promise<{ events: AiuxEvent[]; issues: AdapterIssue[] }> => {
  const issues: AdapterIssue[] = [];
  const adapter = createSseAdapter({
    ...opts,
    onIssue: (i) => {
      issues.push(i);
      opts.onIssue?.(i);
    },
  });
  const events: AiuxEvent[] = [];
  for await (const batch of adapter) events.push(...batch);
  for (const e of events) validator.assertValid(e);
  return { events, issues };
};

const baseOpts = {
  sessionId: "s1",
  target: { runId: "r1", messageId: "m1", partId: "p1" },
};

describe("createSseAdapter", () => {
  it("passes canonical envelopes through untouched", async () => {
    const body = `data: ${canonical()}\n\n`;
    const { events, issues } = await collect({
      ...baseOpts,
      url: "https://x/sse",
      fetchFn: async () => sseResponse(body),
      reconnect: false,
    });
    expect(events).toHaveLength(1);
    expect(events[0]!.eventId).toBe("e0");
    expect(issues).toHaveLength(0);
  });

  it("normalizes provider token shapes into text.delta", async () => {
    const body = [
      `data: ${JSON.stringify({ choices: [{ delta: { content: "Hello, " } }] })}`,
      ``,
      `data: ${JSON.stringify({ choices: [{ delta: { content: "world" } }] })}`,
      ``,
      `data: [DONE]`,
      "",
    ].join("\n");
    const { events } = await collect({
      ...baseOpts,
      url: "https://x/sse",
      fetchFn: async () => sseResponse(body),
      reconnect: false,
    });
    expect(events.map((e) => e.type)).toEqual([
      "text.delta",
      "text.delta",
      "run.completed",
    ]);
    expect(events[0]!.payload).toMatchObject({
      messageId: "m1",
      partId: "p1",
      delta: "Hello, ",
    });
  });

  it("supports multi-line data and the event: field as a type hint", async () => {
    const body = [
      `event: text.delta`,
      `data: {"delta": "a`,
      `data: b"}`,
      `id: 42`,
      ``,
      `event: finish`,
      `data: {}`,
      ``,
    ].join("\n");
    const { events } = await collect({
      ...baseOpts,
      url: "https://x/sse",
      fetchFn: async () => sseResponse(body),
      reconnect: false,
    });
    expect(events.map((e) => e.type)).toEqual(["text.delta", "run.completed"]);
    expect(events[0]!.payload).toMatchObject({ delta: "a\nb" });
  });

  it("skips malformed data JSON, reports it, and keeps streaming", async () => {
    const body = [
      `data: {not json`,
      ``,
      `data: ${JSON.stringify({ type: "text.delta", delta: "ok" })}`,
      ``,
    ].join("\n");
    const { events, issues } = await collect({
      ...baseOpts,
      url: "https://x/sse",
      fetchFn: async () => sseResponse(body),
      reconnect: false,
    });
    expect(events.map((e) => e.type)).toEqual(["text.delta"]);
    expect(issues).toEqual([
      expect.objectContaining({ kind: "malformed", reason: "invalid-json" }),
    ]);
  });

  it("reconnects after a drop and resends Last-Event-ID", async () => {
    const calls: RequestInit[] = [];
    const fetchFn: typeof fetch = async (_url, init = {}) => {
      calls.push(init);
      if (calls.length === 1) {
        // First connection: one event with id, then an EOF drop (no terminal).
        return sseResponse(`id: evt-9\ndata: ${JSON.stringify({ type: "text.delta", delta: "x" })}\n\n`);
      }
      return sseResponse(
        `data: ${JSON.stringify({ type: "run.completed", runId: "r1" })}\n\n`,
      );
    };
    const { events, issues } = await collect({
      ...baseOpts,
      url: "https://x/sse",
      fetchFn,
      reconnect: { initialDelayMs: 1, maxRetries: 3 },
    });
    expect(calls).toHaveLength(2);
    expect(new Headers(calls[1]!.headers).get("Last-Event-ID")).toBe("evt-9");
    expect(events.map((e) => e.type)).toEqual(["text.delta", "run.completed"]);
    expect(issues.some((i) => i.reason === "reconnecting")).toBe(true);
  });

  it("does not reconnect after a terminal run event", async () => {
    let calls = 0;
    const { events } = await collect({
      ...baseOpts,
      url: "https://x/sse",
      fetchFn: async () => {
        calls += 1;
        return sseResponse(`data: ${JSON.stringify({ type: "run.failed", error: { code: "x", message: "m" } })}\n\n`);
      },
      reconnect: true,
    });
    expect(events.map((e) => e.type)).toEqual(["run.failed"]);
    expect(calls).toBe(1);
  });

  it("gives up after the retry budget and throws the transport error", async () => {
    let calls = 0;
    const issues: AdapterIssue[] = [];
    const adapter = createSseAdapter({
      ...baseOpts,
      url: "https://x/sse",
      fetchFn: async () => {
        calls += 1;
        return new Response("nope", { status: 503 });
      },
      reconnect: { initialDelayMs: 1, maxRetries: 2 },
      onIssue: (i) => issues.push(i),
    });
    await expect(async () => {
      for await (const _b of adapter) void _b;
    }).rejects.toThrow(/budget exhausted/);
    expect(calls).toBe(3); // initial + 2 retries
    expect(issues.some((i) => i.reason === "transport-failure")).toBe(true);
  });
});
