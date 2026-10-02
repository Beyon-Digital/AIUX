/* tslint:disable */
/* eslint-disable */

/**
 * Opaque session handle owned by the core; JS holds it between calls and
 * releases it with `free()` (or GC finalization) when done.
 */
export class WasmSession {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
}

/**
 * Create a session from a JSON config payload.
 */
export function createSession(config_json: string): WasmSession;

/**
 * Reduce one event (JSON) into session state. Returns the `DispatchReport`
 * as a JSON string.
 */
export function dispatch(session: WasmSession, event_json: string): string;

/**
 * Reduce an ordered JSON array of events in one FFI call (plan §22: streaming
 * deltas batch here, never one call per token).
 */
export function dispatchBatch(session: WasmSession, events_json: string): string;

/**
 * Clear all session state.
 */
export function reset(session: WasmSession): void;

/**
 * Restore a session from a `serialize()` payload.
 */
export function restoreSession(serialized_json: string): WasmSession;

/**
 * Canonical-JSON serialized session state (persistence/replay/conformance).
 */
export function serialize(session: WasmSession): string;

/**
 * Canonical-JSON render snapshot for the current state.
 */
export function snapshot(session: WasmSession): string;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly __wbg_wasmsession_free: (a: number, b: number) => void;
    readonly createSession: (a: number, b: number) => [number, number, number];
    readonly dispatch: (a: number, b: number, c: number) => [number, number, number, number];
    readonly dispatchBatch: (a: number, b: number, c: number) => [number, number, number, number];
    readonly reset: (a: number) => void;
    readonly restoreSession: (a: number, b: number) => [number, number, number];
    readonly serialize: (a: number) => [number, number, number, number];
    readonly snapshot: (a: number) => [number, number, number, number];
    readonly __wbindgen_externrefs: WebAssembly.Table;
    readonly __wbindgen_malloc: (a: number, b: number) => number;
    readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
    readonly __externref_table_dealloc: (a: number) => void;
    readonly __wbindgen_free: (a: number, b: number, c: number) => void;
    readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

/**
 * Instantiates the given `module`, which can either be bytes or
 * a precompiled `WebAssembly.Module`.
 *
 * @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
 *
 * @returns {InitOutput}
 */
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
 * If `module_or_path` is {RequestInfo} or {URL}, makes a request and
 * for everything else, calls `WebAssembly.instantiate` directly.
 *
 * @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
 *
 * @returns {Promise<InitOutput>}
 */
export default function __wbg_init (module_or_path: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
