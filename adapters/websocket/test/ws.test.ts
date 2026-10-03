import { describe, expect, it } from "vitest";

import type { AdapterIssue } from "@beyond-digital/aiux-transport-js";

import type { AiuxEvent } from "../../shared/src/index";
import { createEventValidator } from "../../shared/src/testing";
import {
  createWebSocketAdapter,
  type WebSocketLike,
  type WsAdapterOptions,
} from "../src/index";

const validator = createEventValidator();

class FakeSocket implements WebSocketLike {
  static instances: FakeSocket[] = [];
  readonly readyState = 0;
  onopen: ((event: unknown) => void) | null = null;
  onmessage: ((event: { data: unknown }) => void) | null = null;
  onclose: ((event: { code: number; reason?: string }) => void) | null = null;
  onerror: ((event: unknown) => void) | null = null;
  sent: string[] = [];
  constructor(
    public url: string,
    public protocols?: string | string[],
  ) {
    FakeSocket.instances.push(this);
  }
  send(data: string) {
    this.sent.push(data);
  }
  close(code = 1000, reason = "") {
    this.onclose?.({ code, reason });
  }
  // test drivers
  emitOpen() {
    this.onopen?.({});
  }
  emitMessage(data: unknown) {
    this.onmessage?.({ data });
  }
  emitClose(code: number) {
    this.onclose?.({ code });
  }
}

/** Wait until the Nth socket exists — reconnect backoff is a real timer. */
const waitForSocket = async (n: number): Promise<FakeSocket> => {
  for (let i = 0; i < 200; i++) {
    const s = FakeSocket.instances[n];
    if (s) return s;
    await new Promise((r) => setTimeout(r, 1));
  }
  throw new Error(`socket #${n} never connected`);
};

const baseOpts = (over: Partial<WsAdapterOptions> = {}): WsAdapterOptions => ({
  url: "wss://x/ws",
  webSocketFactory: (url, protocols) => new FakeSocket(url, protocols),
  sessionId: "s1",
  target: { runId: "r1", messageId: "m1", partId: "p1" },
  reconnect: { initialDelayMs: 1, maxRetries: 3 },
  ...over,
});

describe("createWebSocketAdapter", () => {
  it("yields normalized batches in wire order", async () => {
    FakeSocket.instances = [];
    const issues: AdapterIssue[] = [];
    const adapter = createWebSocketAdapter(baseOpts({ onIssue: (i) => issues.push(i) }));
    const it = adapter[Symbol.asyncIterator]();
    const sock = FakeSocket.instances[0]!;
    sock.emitOpen();
    sock.emitMessage(JSON.stringify({ type: "text.delta", delta: "a" }));
    sock.emitMessage(JSON.stringify({ type: "text.delta", delta: "b" }));
    sock.emitMessage("garbage{");
    sock.emitMessage(JSON.stringify({ type: "run.completed" }));
    sock.emitClose(1000);

    const events: AiuxEvent[] = [];
    for (;;) {
      const r = await it.next();
      if (r.done) break;
      events.push(...r.value);
    }
    expect(events.map((e) => e.type)).toEqual([
      "text.delta",
      "text.delta",
      "run.completed",
    ]);
    for (const e of events) validator.assertValid(e);
    expect(issues).toEqual([
      expect.objectContaining({ kind: "malformed", reason: "invalid-json" }),
    ]);
  });

  it("reconnects on abnormal close", async () => {
    FakeSocket.instances = [];
    const adapter = createWebSocketAdapter(baseOpts());
    const it = adapter[Symbol.asyncIterator]();
    const first = FakeSocket.instances[0]!;
    first.emitOpen();
    first.emitMessage(JSON.stringify({ type: "text.delta", delta: "x" }));
    first.emitClose(1006); // abnormal — should reconnect

    const second = await waitForSocket(1); // backoff fired → reconnected
    second.emitOpen();
    second.emitMessage(JSON.stringify({ type: "run.completed" }));
    second.emitClose(1000);

    const types: string[] = [];
    for (;;) {
      const r = await it.next();
      if (r.done) break;
      types.push(...r.value.map((e) => e.type));
    }
    expect(types).toEqual(["text.delta", "run.completed"]);
    expect(adapter.connections).toBe(2);
  });

  it("delivers sealed tool starts before surfacing a terminal failure", async () => {
    FakeSocket.instances = [];
    const adapter = createWebSocketAdapter(baseOpts({ reconnect: false }));
    const it = adapter[Symbol.asyncIterator]();
    const sock = FakeSocket.instances[0]!;
    sock.emitOpen();
    sock.emitMessage(
      JSON.stringify({
        choices: [
          {
            delta: {
              tool_calls: [
                { id: "call_1", function: { name: "f", arguments: '{"q":' } },
              ],
            },
          },
        ],
      }),
    );
    sock.emitClose(1006); // abnormal, no retries → terminal failure

    // The truncated call's sealed start arrives first, then the failure.
    const first = await it.next();
    expect(first.done).toBe(false);
    expect(first.value?.map((e: AiuxEvent) => e.type)).toEqual(["tool.started"]);
    await expect(it.next()).rejects.toThrow(/closed abnormally/);
  });

  it("delivers already-buffered batches before surfacing a terminal failure", async () => {
    FakeSocket.instances = [];
    const adapter = createWebSocketAdapter(baseOpts({ reconnect: false }));
    const it = adapter[Symbol.asyncIterator]();
    const sock = FakeSocket.instances[0]!;
    sock.emitOpen();
    // A complete batch lands before the abnormal close — it must not be
    // discarded just because the transport failed.
    sock.emitMessage(JSON.stringify({ type: "text.delta", delta: "x" }));
    sock.emitMessage(JSON.stringify({ type: "text.delta", delta: "y" }));
    sock.emitClose(1006);

    const first = await it.next();
    expect(first.done).toBe(false);
    expect(first.value?.map((e: AiuxEvent) => e.type)).toEqual(["text.delta"]);
    const second = await it.next();
    expect(second.done).toBe(false);
    expect(second.value?.map((e: AiuxEvent) => e.type)).toEqual(["text.delta"]);
    await expect(it.next()).rejects.toThrow(/closed abnormally/);
  });

  it("exhausts the retry budget and fails the iterator", async () => {
    FakeSocket.instances = [];
    const adapter = createWebSocketAdapter(
      baseOpts({ reconnect: { initialDelayMs: 1, maxRetries: 2 } }),
    );
    const it = adapter[Symbol.asyncIterator]();
    FakeSocket.instances[0]!.emitClose(1006);
    (await waitForSocket(1)).emitClose(1006);
    (await waitForSocket(2)).emitClose(1006);
    expect(FakeSocket.instances).toHaveLength(3);
    await expect(it.next()).rejects.toThrow(/budget exhausted/);
  });

  it("passes canonical envelopes through", async () => {
    FakeSocket.instances = [];
    const canonicalEvent = {
      eventId: "e1",
      sessionId: "s1",
      sequence: 7,
      timestamp: "2026-01-01T00:00:00Z",
      type: "run.completed",
      payload: { protocolVersion: "0.1", runId: "r1" },
    };
    const adapter = createWebSocketAdapter(baseOpts());
    const it = adapter[Symbol.asyncIterator]();
    const sock = FakeSocket.instances[0]!;
    sock.emitMessage(JSON.stringify(canonicalEvent));
    sock.emitClose(1000);
    const r = await it.next();
    expect(r.value?.[0]).toEqual(canonicalEvent);
    validator.assertValid(r.value![0]!);
  });
});
