# Usage guide

This guide shows the standard AIUX host integration flow across platforms.

For platform/package install commands and release availability, see
[consumer installation](./install.md).

## Integration flow

1. **Initialize a core runtime**
   - Web/Node: initialize `@beyond-digital/aiux-core/wasm`.
   - Native stacks: use the platform binding/bridge (`swift`, `kotlin`,
     `dart`, `expo`).
2. **Create or restore a session**
   - Start with `create(...)` for a new conversation.
   - Use `restore(...)` when resuming from persisted serialized state.
3. **Ingest protocol events**
   - Feed `AIUXEvent` payloads through `dispatch`/`dispatchBatch`.
   - Prefer batched delivery for streams (`EventBuffer`, event driver, or
     transport adapter).
4. **Render snapshots**
   - Renderers consume `snapshot()` output; they do not mutate state.
   - UI actions emit semantic `AIUXAction` payloads back to your host policy.
5. **Apply host policy**
   - Handle actions (send message, resolve approval, retry, open artifact, etc.).
   - Convert host decisions back into protocol events and dispatch them.
6. **Persist and teardown**
   - Persist with `serialize()` for resume/replay.
   - Dispose/close transports and session handles on teardown.

## Recommended web setup

1. Initialize WASM core.
2. Create `AiuxSession`.
3. Create `createEventDriver(session)` (or a transport adapter + batcher).
4. Render `<AIConversation session={session} onAction={...} />`.
5. Dispatch protocol events from your backend stream into the session.

Reference implementation:
- [`examples/web/src/host.ts`](../../examples/web/src/host.ts)

## Transport and adapter patterns

- `@beyond-digital/aiux-transport-js`
  - `createEventFactory(...)` for canonical event envelopes.
  - `streamToBatches(...)` for adaptive streaming flush.
  - `createWireNormalizer(...)` for provider payload normalization.
- Adapters (`sse`, `websocket`, `ai-sdk`) expose `AsyncIterable<AIUXEvent[]>`
  that can be consumed directly by your dispatch loop.

## Native platform pointers

- Expo bridge: [docs/integration/expo.md](./expo.md)
- SwiftUI renderer: [docs/integration/swiftui.md](./swiftui.md)
- Compose renderer: [docs/integration/compose.md](./compose.md)
- Flutter renderer/example: [examples/flutter/README.md](../../examples/flutter/README.md)

## Development and validation

- Core and protocol tests: `cargo test --workspace`
- JavaScript packages: `pnpm install && pnpm build && pnpm test`
- Android/Kotlin modules: `./gradlew build`
- Swift packages (macOS): `swift build && swift test`
