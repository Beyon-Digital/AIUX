import type { AiuxCore, SessionHandle } from "./core.js";
import type { JsonString } from "./types.js";

/**
 * Shape of the wasm-bindgen module produced by the `aiux-wasm` build
 * (`bindings/wasm/pkg/aiux_wasm.js`, `--target web`), vendored into this
 * package by `scripts/copy-wasm.mjs` as the `./wasm` export. Consumers run
 * `pnpm --filter @beyond-digital/aiux-core build:wasm`, then `init()` the
 * generated module and hand it to {@link wasmCore}:
 *
 * ```ts
 * import init, * as wasm from "@beyond-digital/aiux-core/wasm";
 * await init();
 * const core = wasmCore(wasm);
 * const session = AiuxSession.create(core, config);
 * ```
 */
export interface AiuxWasmModule {
  createSession(configJson: JsonString): SessionHandle;
  restoreSession(serializedJson: JsonString): SessionHandle;
  dispatch(session: SessionHandle, eventJson: JsonString): JsonString;
  dispatchBatch(session: SessionHandle, eventsJson: JsonString): JsonString;
  snapshot(session: SessionHandle): JsonString;
  serialize(session: SessionHandle): JsonString;
  reset(session: SessionHandle): void;
}

interface Freeable {
  free(): void;
}

/**
 * Adapt an initialized `aiux-wasm` module to {@link AiuxCore}. Pure pass-
 * through except `freeSession`, which calls the wasm-bindgen handle's `free()`
 * so wasm memory is released at `AiuxSession.dispose()`.
 */
export function wasmCore(module: AiuxWasmModule): AiuxCore {
  return {
    createSession: (configJson) => module.createSession(configJson),
    restoreSession: (serializedJson) => module.restoreSession(serializedJson),
    dispatch: (session, eventJson) => module.dispatch(session, eventJson),
    dispatchBatch: (session, eventsJson) =>
      module.dispatchBatch(session, eventsJson),
    snapshot: (session) => module.snapshot(session),
    serialize: (session) => module.serialize(session),
    reset: (session) => module.reset(session),
    freeSession: (session) => (session as Freeable).free(),
  };
}
