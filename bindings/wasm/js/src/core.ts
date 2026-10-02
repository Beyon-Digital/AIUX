import type { JsonString } from "./types.js";

/**
 * Opaque session handle owned by the core implementation (a wasm-bindgen
 * object for `aiux-wasm`, a plain object for `MockCore`). Callers never
 * inspect it — they only pass it back to the same `AiuxCore`.
 */
export type SessionHandle = unknown;

/**
 * The frozen session-facade surface every core implementation must satisfy —
 * exactly the `aiux-wasm` export list (docs/PLAN.md §4, ADR 0005):
 *
 * ```text
 * createSession(configJson) / restoreSession(serializedJson) -> handle
 * dispatch(handle, eventJson) / dispatchBatch(handle, eventsJson) -> reportJson
 * snapshot(handle) / serialize(handle) -> jsonString
 * reset(handle)
 * ```
 *
 * JSON strings in/out; implementations add no semantics of their own.
 */
export interface AiuxCore {
  createSession(configJson: JsonString): SessionHandle;
  restoreSession(serializedJson: JsonString): SessionHandle;
  dispatch(session: SessionHandle, eventJson: JsonString): JsonString;
  dispatchBatch(session: SessionHandle, eventsJson: JsonString): JsonString;
  snapshot(session: SessionHandle): JsonString;
  serialize(session: SessionHandle): JsonString;
  reset(session: SessionHandle): void;
  /**
   * Release the handle's backing resources (wasm-bindgen `free()`). Optional —
   * implementations backed by plain JS objects may omit it.
   */
  freeSession?(session: SessionHandle): void;
}
