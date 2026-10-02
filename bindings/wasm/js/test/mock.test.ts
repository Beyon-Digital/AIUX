import { describe, expect, it } from "vitest";
import { AiuxProtocolError, MockCore } from "../src/index.js";

describe("MockCore", () => {
  it("counts facade calls for batching assertions", () => {
    const core = new MockCore();
    const session = core.createSession("{}");
    core.dispatch(session, "{}");
    core.dispatchBatch(session, "[{},{}]");
    core.snapshot(session);
    core.serialize(session);
    core.reset(session);
    core.freeSession?.(session);
    expect(core.calls).toEqual({
      createSession: 1,
      restoreSession: 0,
      dispatch: 1,
      dispatchBatch: 1,
      snapshot: 1,
      serialize: 1,
      reset: 1,
      freeSession: 1,
    });
  });

  it("appends events in order and replays them via snapshot/serialize", () => {
    const core = new MockCore();
    const session = core.createSession('{"a":1}');
    core.dispatch(session, '{"e":1}');
    core.dispatchBatch(session, '[{"e":2},{"e":3}]');
    expect(JSON.parse(core.snapshot(session))).toMatchObject({
      events: [{ e: 1 }, { e: 2 }, { e: 3 }],
    });
    expect(JSON.parse(core.serialize(session))).toMatchObject({
      configJson: '{"a":1}',
      events: [{ e: 1 }, { e: 2 }, { e: 3 }],
    });
  });

  it("round-trips through serialize/restore", () => {
    const core = new MockCore();
    const session = core.createSession("{}");
    core.dispatchBatch(session, '[{"e":1},{"e":2}]');
    const restored = core.restoreSession(core.serialize(session));
    expect(JSON.parse(core.snapshot(restored))).toMatchObject({
      events: [{ e: 1 }, { e: 2 }],
    });
  });

  it("rejects malformed JSON at the boundary", () => {
    const core = new MockCore();
    const session = core.createSession("{}");
    for (const op of [
      () => core.dispatch(session, "{oops"),
      () => core.dispatchBatch(session, "{oops"),
      () => core.restoreSession("{oops"),
      () => core.createSession("{oops"),
    ]) {
      expect(op).toThrow(AiuxProtocolError);
    }
  });

  it("rejects a non-array batch and unknown handles", () => {
    const core = new MockCore();
    const session = core.createSession("{}");
    expect(() => core.dispatchBatch(session, '{"e":1}')).toThrow(
      AiuxProtocolError,
    );
    expect(() => core.dispatch({}, "{}")).toThrow(AiuxProtocolError);
  });

  it("rejects restore payloads that were not serialized by a MockCore", () => {
    const core = new MockCore();
    try {
      core.restoreSession('{"foo":1}');
      expect.unreachable();
    } catch (error) {
      expect(error).toBeInstanceOf(AiuxProtocolError);
      expect((error as AiuxProtocolError).kind).toBe("corruptState");
    }
  });
});
