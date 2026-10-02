import { describe, expect, it } from "vitest";
import {
  AiuxProtocolError,
  AiuxSession,
  MockCore,
  SessionDisposedError,
  type SessionSnapshot,
} from "../src/index.js";

const CONFIG = { protocolVersion: "0.1", sessionId: "s-1" };

function makeSession(core = new MockCore()) {
  return AiuxSession.create(core, CONFIG);
}

describe("AiuxSession", () => {
  it("creates an active session and snapshots through the contract", () => {
    const core = new MockCore();
    const session = makeSession(core);
    expect(session.lifecycle).toBe("active");
    expect(core.calls.createSession).toBe(1);

    const snapshot = session.snapshot();
    expect(snapshot).toMatchObject({ mock: true, events: [] });
    session.dispose();
  });

  it("dispatches one event and returns the parsed report", () => {
    const core = new MockCore();
    const session = makeSession(core);
    const report = session.dispatch({ type: "text.delta", payload: { t: "a" } });
    expect(report).toEqual({ applied: 1, duplicatesIgnored: 0, buffered: 0 });
    expect(core.calls.dispatch).toBe(1);
    session.dispose();
  });

  it("dispatches a batch in a single core call", () => {
    const core = new MockCore();
    const session = makeSession(core);
    const report = session.dispatchBatch([
      { type: "text.delta", payload: { t: "a" } },
      { type: "text.delta", payload: { t: "b" } },
      { type: "text.delta", payload: { t: "c" } },
    ]);
    expect(report).toEqual({ applied: 3, duplicatesIgnored: 0, buffered: 0 });
    expect(core.calls.dispatchBatch).toBe(1);
    expect(core.calls.dispatch).toBe(0);
    session.dispose();
  });

  it("serializes and restores through the boundary", () => {
    const core = new MockCore();
    const session = makeSession(core);
    session.dispatch({ type: "message.created", payload: { id: "m-1" } });
    const serialized = session.serialize();

    const restored = AiuxSession.restore(core, serialized);
    expect(restored.snapshot()).toMatchObject({
      events: [{ type: "message.created", payload: { id: "m-1" } }],
    });
    expect(core.calls.restoreSession).toBe(1);
    session.dispose();
    restored.dispose();
  });

  it("reset clears state and notifies listeners", () => {
    const session = makeSession();
    session.dispatch({ type: "text.delta", payload: {} });
    const seen: SessionSnapshot[] = [];
    session.subscribe((s) => seen.push(s));
    session.reset();
    expect(seen.at(-1)).toMatchObject({ events: [] });
    session.dispose();
  });

  it("translates core failures into AiuxProtocolError", () => {
    const session = makeSession();
    let thrown: unknown;
    try {
      session.dispatch("{not json");
    } catch (error) {
      thrown = error;
    }
    expect(thrown).toBeInstanceOf(AiuxProtocolError);
    expect((thrown as AiuxProtocolError).kind).toBe("invalidEvent");
    session.dispose();
  });

  describe("subscribe", () => {
    it("emits the current snapshot immediately, then after each mutation", () => {
      const session = makeSession();
      const seen: SessionSnapshot[] = [];
      const unsubscribe = session.subscribe((s) => seen.push(s));

      expect(seen).toHaveLength(1); // immediate emit
      session.dispatch({ type: "text.delta", payload: { t: "x" } });
      session.dispatchBatch([
        { type: "text.delta", payload: { t: "y" } },
        { type: "text.delta", payload: { t: "z" } },
      ]);
      expect(seen).toHaveLength(3); // one per dispatch call, not per event
      expect(seen.at(-1)).toMatchObject({
        events: [
          { type: "text.delta" },
          { type: "text.delta" },
          { type: "text.delta" },
        ],
      });
      session.dispose();
      unsubscribe();
    });

    it("stops notifying after unsubscribe", () => {
      const session = makeSession();
      const seen: SessionSnapshot[] = [];
      const unsubscribe = session.subscribe((s) => seen.push(s));
      unsubscribe();
      session.dispatch({ type: "text.delta", payload: {} });
      expect(seen).toHaveLength(1);
      session.dispose();
    });

    it("routes listener exceptions to onListenerError without breaking dispatch", () => {
      const errors: unknown[] = [];
      const session = AiuxSession.create(new MockCore(), CONFIG, {
        onListenerError: (error) => errors.push(error),
      });
      const boom = new Error("renderer bug");
      session.subscribe(() => {
        throw boom;
      });
      expect(errors).toEqual([boom]);
      expect(() => session.dispatch({ type: "x" })).not.toThrow();
      expect(errors).toEqual([boom, boom]);
      session.dispose();
    });

    it("does not call snapshot() when there are no listeners", () => {
      const core = new MockCore();
      const session = makeSession(core);
      session.dispatch({ type: "x" });
      expect(core.calls.snapshot).toBe(0);
      session.dispose();
    });
  });

  describe("dispose", () => {
    it("frees the handle, is idempotent, and blocks further use", () => {
      const core = new MockCore();
      const session = makeSession(core);
      session.dispose();
      session.dispose();
      expect(session.lifecycle).toBe("disposed");
      expect(core.calls.freeSession).toBe(1);
      for (const op of [
        () => session.dispatch({}),
        () => session.dispatchBatch([]),
        () => session.snapshot(),
        () => session.serialize(),
        () => session.reset(),
        () => session.subscribe(() => {}),
      ]) {
        expect(op).toThrow(SessionDisposedError);
      }
    });
  });
});
