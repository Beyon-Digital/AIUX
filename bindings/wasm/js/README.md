# @beyond-digital/aiux-core

JS session package over the AIUX WASM core (docs/PLAN.md §5/§10/§12, ADR 0005).
Consumed by `@beyond-digital/aiux-web` and the JS transport adapters.

MIT. `npm install @beyond-digital/aiux-core` after registry publication.
The release package includes compiled JS/types and WASM; consumers need no Rust
toolchain. See [availability and installation](https://github.com/Beyon-Digital/AIUX/blob/main/docs/integration/install.md).

```ts
import { AiuxSession, EventBuffer, MockCore, wasmCore } from "@beyond-digital/aiux-core";
import init, * as wasm from "@beyond-digital/aiux-core/wasm";
import wasmUrl from "@beyond-digital/aiux-core/wasm/aiux_wasm_bg.wasm?url"; // Vite

await init({ module_or_path: wasmUrl });
const core = wasmCore(wasm);              // or new MockCore() in tests
const session = AiuxSession.create(core, "{}");
const unsub = session.subscribe((snapshot) => render(snapshot));

const buffer = new EventBuffer((eventsJson) => session.dispatchBatch(eventsJson));
stream.on("event", (e) => buffer.push(e)); // batches; never per-token FFI
```

- `AiuxSession` — `dispatch` / `dispatchBatch` / `snapshot` / `serialize` /
  `reset`, `subscribe(listener)` snapshot observation, `dispose()`.
- `EventBuffer` — flush on a 16–50 ms window (default 32) **or** size
  thresholds (default 64 events / 64 KiB), whichever first. Defaults are
  provisional pending real-device benchmarks; `pnpm bench` measures JS-side
  overhead.
- `MockCore` — in-memory `AiuxCore` for tests/pre-wasm work. It only appends
  and tracks; conformance semantics live in the Rust core.
- `wasmCore(module)` — adapts the `aiux-wasm` exports (thin shim; JSON
  strings in/out, `ProtocolError` as serialized JSON in the thrown message).

Opaque payloads (`SessionConfig`, `AiuxEvent`, `SessionSnapshot`) are
`Record<string, unknown>` until generated types land from
`protocol/schemas/v1`.
