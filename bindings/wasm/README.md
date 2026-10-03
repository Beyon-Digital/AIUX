# aiux-wasm

wasm-bindgen surface over the Rust core for `@beyond-digital/aiux-core` (plan §5,
ADR 0005). Phase 5.

The crate exports the frozen session facade as free functions — JSON strings
in/out, no logic of its own:

```text
createSession(configJson) / restoreSession(serializedJson)  -> WasmSession
dispatch(session, eventJson) / dispatchBatch(session, eventsJson) -> reportJson
snapshot(session) / serialize(session) -> jsonString
reset(session)
```

`ProtocolError` crosses the boundary as `JsError` whose message is the error's
canonical JSON (`{"kind": "..."}`). Reducer semantics are owned by
`aiux-session` (ADR 0001) — while the Phase 1 core lands in parallel the facade
is still a stub, so behavior here is signature-only.

## Build the artifact

```sh
rustup target add wasm32-unknown-unknown
cargo install wasm-bindgen-cli   # must match Cargo.lock's wasm-bindgen version
./build.sh                       # writes pkg/ (gitignored)
```

## JS package

`js/` contains `@beyond-digital/aiux-core`: the `AiuxSession` wrapper, the
streaming `EventBuffer` (plan §10/§22), `MockCore`, and vitest tests. It is a
pnpm workspace member; `pnpm install && pnpm -r test` from the repo root.
