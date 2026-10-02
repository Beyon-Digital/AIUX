import { beforeEach, describe, expect, it, vi } from "vitest";

const dispatchBatch = vi.fn((_sessionId: string, _eventsJson: string) =>
  Promise.resolve({ applied: 1 }),
);

vi.mock("../src/AIUXNative", () => ({
  getNativeModule: () => ({
    dispatchBatch,
    createSession: vi.fn(() => Promise.resolve()),
    serialize: vi.fn(() => Promise.resolve("{}")),
    restore: vi.fn(() => Promise.resolve()),
    reset: vi.fn(() => Promise.resolve()),
    snapshot: vi.fn(() => Promise.resolve("{}")),
    isNativeReady: () => true,
    addListener: vi.fn(),
  }),
}));

const { createAIUXTransport } = await import("../src/transport");

function event(n: number) {
  return {
    eventId: `e${n}`,
    sessionId: "s1",
    sequence: n,
    timestamp: "2026-01-01T00:00:00Z",
    type: "text.delta",
    payload: { delta: `${n}` },
  };
}

describe("createAIUXTransport", () => {
  beforeEach(() => {
    dispatchBatch.mockClear();
  });

  it("coalesces pushed events into one dispatchBatch call", async () => {
    const transport = createAIUXTransport("s1");
    transport.push(event(0));
    transport.push(event(1));
    transport.push(event(2));
    await transport.flush();
    expect(dispatchBatch).toHaveBeenCalledTimes(1);
    const [sessionId, eventsJson] = dispatchBatch.mock.calls[0]!;
    expect(sessionId).toBe("s1");
    expect(JSON.parse(eventsJson)).toHaveLength(3);
    await transport.close();
  });

  it("accepts pre-serialized JSON strings and objects alike", async () => {
    const transport = createAIUXTransport("s1");
    transport.push(JSON.stringify(event(0)));
    transport.push(event(1));
    await transport.flush();
    const [, eventsJson] = dispatchBatch.mock.calls[0]!;
    expect(JSON.parse(eventsJson)).toHaveLength(2);
    await transport.close();
  });

  it("requeues the batch when the native sink rejects", async () => {
    dispatchBatch
      .mockRejectedValueOnce(new Error("ffi boom"))
      .mockResolvedValue({ applied: 1 });
    const errors: unknown[] = [];
    const transport = createAIUXTransport("s1", {
      policy: { onFlushError: (e) => errors.push(e) },
    });
    transport.push(event(0));
    await transport.flush();
    expect(errors).toHaveLength(1);
    await transport.flush();
    expect(dispatchBatch).toHaveBeenCalledTimes(2);
    await transport.close();
  });
});
