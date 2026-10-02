import type { AiuxCore, SessionHandle } from "./core.js";
import { AiuxProtocolError } from "./errors.js";
import type { JsonString } from "./types.js";

interface MockSessionHandle {
  configJson: JsonString;
  /** Events the mock has appended, in arrival order. */
  events: unknown[];
}

/** Per-function call counts — lets tests verify batching (no per-token calls). */
export interface MockCoreCalls {
  createSession: number;
  restoreSession: number;
  dispatch: number;
  dispatchBatch: number;
  snapshot: number;
  serialize: number;
  reset: number;
  freeSession: number;
}

function invalidEvent(detail: string): AiuxProtocolError {
  return new AiuxProtocolError({ kind: "invalidEvent", detail });
}

function parseJsonOrThrow(json: JsonString, what: string): unknown {
  try {
    return JSON.parse(json);
  } catch (cause) {
    throw invalidEvent(`malformed ${what} JSON: ${(cause as Error).message}`);
  }
}

function requireHandle(session: SessionHandle): MockSessionHandle {
  if (
    typeof session !== "object" ||
    session === null ||
    !("events" in session) ||
    !("configJson" in session)
  ) {
    throw invalidEvent("unknown session handle");
  }
  return session as MockSessionHandle;
}

/**
 * In-memory `AiuxCore` for JS-side tests and pre-wasm development.
 *
 * It only *appends and tracks*: events are validated as JSON at the boundary,
 * stored in order, and replayed through `snapshot()`/`serialize()`. It does
 * NOT reproduce reducer semantics — no ordering, dedup, buffering, or
 * lifecycle rules. Behavioral conformance lives in the Rust core (ADR 0001,
 * plan §17); anything asserted here beyond JSON validity is structural only.
 */
export class MockCore implements AiuxCore {
  /** Invocation counts per facade function, for batching/FFI assertions. */
  readonly calls: MockCoreCalls = {
    createSession: 0,
    restoreSession: 0,
    dispatch: 0,
    dispatchBatch: 0,
    snapshot: 0,
    serialize: 0,
    reset: 0,
    freeSession: 0,
  };

  createSession(configJson: JsonString): SessionHandle {
    this.calls.createSession += 1;
    parseJsonOrThrow(configJson, "config");
    return { configJson, events: [] } satisfies MockSessionHandle;
  }

  restoreSession(serializedJson: JsonString): SessionHandle {
    this.calls.restoreSession += 1;
    const parsed = parseJsonOrThrow(serializedJson, "serialized state");
    if (
      typeof parsed !== "object" ||
      parsed === null ||
      !("configJson" in parsed) ||
      !("events" in parsed) ||
      !Array.isArray((parsed as { events: unknown }).events)
    ) {
      throw new AiuxProtocolError({
        kind: "corruptState",
        detail: "payload is not a MockCore-serialized session",
      });
    }
    const state = parsed as { configJson: JsonString; events: unknown[] };
    return { configJson: state.configJson, events: [...state.events] };
  }

  dispatch(session: SessionHandle, eventJson: JsonString): JsonString {
    this.calls.dispatch += 1;
    const handle = requireHandle(session);
    handle.events.push(parseJsonOrThrow(eventJson, "event"));
    return JSON.stringify({ applied: 1, duplicatesIgnored: 0, buffered: 0 });
  }

  dispatchBatch(session: SessionHandle, eventsJson: JsonString): JsonString {
    this.calls.dispatchBatch += 1;
    const handle = requireHandle(session);
    const events = parseJsonOrThrow(eventsJson, "event batch");
    if (!Array.isArray(events)) {
      throw invalidEvent("dispatchBatch payload must be a JSON array");
    }
    handle.events.push(...events);
    return JSON.stringify({
      applied: events.length,
      duplicatesIgnored: 0,
      buffered: 0,
    });
  }

  snapshot(session: SessionHandle): JsonString {
    this.calls.snapshot += 1;
    const handle = requireHandle(session);
    return JSON.stringify({
      mock: true,
      config: JSON.parse(handle.configJson),
      events: handle.events,
    });
  }

  serialize(session: SessionHandle): JsonString {
    this.calls.serialize += 1;
    const handle = requireHandle(session);
    return JSON.stringify({
      configJson: handle.configJson,
      events: handle.events,
    });
  }

  reset(session: SessionHandle): void {
    this.calls.reset += 1;
    requireHandle(session).events = [];
  }

  freeSession(session: SessionHandle): void {
    this.calls.freeSession += 1;
    requireHandle(session);
  }
}
