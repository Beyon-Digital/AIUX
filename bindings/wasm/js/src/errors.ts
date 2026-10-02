import type { ProtocolErrorKind, ProtocolErrorPayload } from "./types.js";

const ERROR_KINDS: ReadonlySet<string> = new Set([
  "invalidEvent",
  "sequenceGap",
  "unsupported",
  "corruptState",
]);

function isProtocolErrorPayload(value: unknown): value is ProtocolErrorPayload {
  return (
    typeof value === "object" &&
    value !== null &&
    "kind" in value &&
    typeof (value as { kind: unknown }).kind === "string" &&
    ERROR_KINDS.has((value as { kind: string }).kind)
  );
}

/**
 * A recoverable, explicitly-typed failure from the Rust core
 * (`aiux_protocol::ProtocolError`). Out-of-order and
 * unknown-required-semantics cases map to `kind`; nothing silently corrupts
 * state (ADR 0001, plan §4/§21).
 */
export class AiuxProtocolError extends Error {
  readonly kind: ProtocolErrorKind;
  readonly payload: ProtocolErrorPayload;

  constructor(payload: ProtocolErrorPayload) {
    super(payload.detail ?? payload.kind);
    this.name = "AiuxProtocolError";
    this.kind = payload.kind;
    this.payload = payload;
  }
}

/**
 * Convert whatever the core threw into an `AiuxProtocolError` when possible.
 *
 * `aiux-wasm` sends `ProtocolError` across the boundary as a `JsError` whose
 * message is the error's canonical JSON (`{"kind": "..."}`). Anything else
 * (bugs, traps) is returned unchanged.
 */
export function toCoreError(thrown: unknown): unknown {
  const message =
    thrown instanceof Error
      ? thrown.message
      : typeof thrown === "string"
        ? thrown
        : undefined;
  if (message === undefined) return thrown;
  try {
    const parsed: unknown = JSON.parse(message);
    if (isProtocolErrorPayload(parsed)) return new AiuxProtocolError(parsed);
  } catch {
    // Not a serialized ProtocolError — rethrow untouched.
  }
  return thrown;
}

/** Call `fn`, translating boundary errors via {@link toCoreError}. */
export function translateCoreErrors<T>(fn: () => T): T {
  try {
    return fn();
  } catch (thrown) {
    throw toCoreError(thrown);
  }
}

/** Thrown when the core returned something the contract says it never should. */
export class MalformedCoreOutputError extends Error {
  constructor(what: string, cause: unknown) {
    super(`aiux-core: malformed ${what} returned by core`);
    this.name = "MalformedCoreOutputError";
    this.cause = cause;
  }
}

/** Parse JSON the core handed back; contract violations become MalformedCoreOutputError. */
export function parseCoreJson(json: string, what: string): unknown {
  try {
    return JSON.parse(json);
  } catch (cause) {
    throw new MalformedCoreOutputError(what, cause);
  }
}
