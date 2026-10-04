# API reference

This reference documents the primary public APIs exposed in the AIUX repo.

## Core session contract (all bindings)

AIUX centers on one session facade (`AiuxSession`) implemented in Rust and
exposed through all bindings.

### Constructor entry points

- `create(configJson)` → session handle
- `restore(serializedJson)` → session handle

### Session methods

- `dispatch(eventJson)` → `DispatchReport`
- `dispatchBatch(eventsJson)` → `DispatchReport`
- `snapshot()` → current render snapshot JSON
- `serialize()` → persistence envelope JSON
- `reset()` → clears state

The canonical lifecycle and envelope details are specified in:
- [architecture overview](../architecture/overview.md)
- [protocol specification](./specification.md)

## JavaScript package APIs

## `@beyond-digital/aiux-core`

Primary exports:

- `AiuxSession`
  - `AiuxSession.create(core, config, options?)`
  - `AiuxSession.restore(core, serializedJson, options?)`
  - Instance methods:
    `dispatch`, `dispatchBatch`, `snapshot`, `serialize`, `reset`,
    `subscribe`, `dispose`
- `wasmCore(wasmModule)` to bind wasm exports to `AiuxCore`
- `EventBuffer` for bounded, timed batching
- Errors/types: `AiuxProtocolError`, `SessionDisposedError`,
  `DispatchReport`, `SessionSnapshot`, `AiuxEvent`

## `@beyond-digital/aiux-web`

Primary exports:

- Components:
  `AIConversation`, `AIComposer`, `AIContextBar`, `AIMessage`, `AISurface`,
  `AIApproval`, `AIArtifactPreview`, `AIToolStatus`
- Session/context:
  `AiuxSessionProvider`, `useAiuxSession`, `useSessionSnapshot`
- Host integration:
  `createEventDriver(session, policy?)`
- Hooks:
  `useFileDrop`, `useFilePicker`, `useCopyToClipboard`
- Theme/types:
  `resolveTheme`, `themeCssVars`, `AIUX_ACTIONS`, `AiuxAction`, snapshot/entity
  types

## `@beyond-digital/aiux-transport-js`

Primary exports:

- `createEventFactory(sessionId, options?)`
- `streamToBatches(source, options?)`
- `createWireNormalizer(options)`
- `TERMINAL_EVENT_TYPES`, `isTerminalEvent`
- Types:
  `EventFactory`, `WireNormalizer`, `EventBatchSource`, `EventBatchSink`,
  `AdapterIssue`

## `@beyond-digital/aiux-adapter-sse`

- `createSseAdapter(options)` → `SseAdapter` (`AsyncIterable<AIUXEvent[]>`)
- `SseAdapterOptions`:
  `url`, `init`, `fetchFn`, `sessionId`, `target`, `factory`, `normalize`,
  `reconnect`, `signal`, `onIssue`

## `@beyond-digital/aiux-adapter-websocket`

- `createWebSocketAdapter(options)` → `WsAdapter`
- `WsAdapterOptions`:
  `url`, `protocols`, `webSocketFactory`, `sessionId`, `target`, `factory`,
  `normalize`, `reconnect`, `signal`, `onIssue`

## `@beyond-digital/aiux-adapter-ai-sdk`

- `createAiSdkAdapter(stream, options)` → `EventBatchSource`
- `mapAiSdkPart(part, factory, target, onIssue)` helper
- `AiSdkAdapterOptions`:
  `sessionId`, `target`, `factory`, `onIssue`

## `@beyond-digital/aiux-expo`

Primary exports:

- Native view:
  `AIConversation`
- Session helpers:
  `createAIUXSession`, `dispatchAIUXBatch`, `getAIUXSnapshot`,
  `serializeAIUXSession`, `restoreAIUXSession`, `resetAIUXSession`
- Transport:
  `createAIUXTransport(sessionId, options?)`
- Native access:
  `getNativeModule()`

## Types and schemas

- Protocol type package: `@beyond-digital/aiux-protocol-types`
- JSON schema sources: [`protocol/schemas`](../../protocol/schemas)
- Event and surface model docs:
  - [event lifecycle](./event-lifecycle.md)
  - [surface schema](./surface-schema.md)
