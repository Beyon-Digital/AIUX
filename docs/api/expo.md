# Expo bridge — `@beyond-digital/aiux-expo`

One coarse JS↔native boundary: `<AIConversation>` hosts the platform's native
renderer (SwiftUI on iOS, Jetpack Compose on Android) and the underlying
`AiuxSession`. JS configures the session, streams protocol events through the
batched transport and receives semantic actions — it never lays out message
UI. Source: [`bridges/expo`](../../bridges/expo). Expo SDK 57, RN 0.86,
new architecture; requires a dev client (not Expo Go).

## `<AIConversation>`

```tsx
<AIConversation
  sessionId="s1"                                  // required
  title="Assistant"
  theme={{ colorScheme: 'system', colors: { accent: '#7c3aed' } }}
  context={[{ id: 'ctx-1', kind: 'repo', label: 'Beyon-Digital/AIUX' }]}
  capabilities={[{ id: 'attachments', enabled: true }]}
  mode="fullscreen"
  showComposer
  composerToolbar={{ dictate: false, extra: [{ id: 'aiux.composer.docs', label: 'Docs', glyph: 'doc' }] }}
  onAction={(action) => route(action)}
  onError={(e) => console.warn(e.code, e.message)}
  onSnapshot={(snap) => console.log(snap)}
  fallback={<Spinner />}
/>
```

| Prop | Type | Notes |
| --- | --- | --- |
| `sessionId` | `string` **required** | The session created via `createAIUXSession`. The view calls it once on mount. |
| `theme` | `AIUXThemeInput \| string` | Object or serialized JSON — forwarded natively. [Theming](../guides/theming.md). |
| `context` | `AIUXContextEntity[]` | Entities merged into the context bar. |
| `capabilities` | `AIUXCapability[]` | `{id, description?, enabled?}` — gates affordances. |
| `title` | `string` | Header title fallback (the session's `title` wins once loaded). |
| `mode` | `"fullscreen" \| "embedded"` | Layout mode. |
| `showComposer` | `boolean` | Hide to render read-only transcripts. |
| `composerToolbar` | `AIUXComposerToolbarSpec \| string` | `{attach?, tools?, dictate?, extra?}` — [toolbar guide](../guides/composer-toolbar.md). |
| `onAction` | `(action: AIUXAction) => void` | `{id, payload}` — see [actions](../guides/actions.md). |
| `onError` | `(error: AIUXErrorInfo) => void` | `{code, message}` — session/create/dispatch failures. |
| `onSnapshot` | `(snapshot: AIUXSnapshot) => void` | Parsed snapshot on each mutation (throttled ~150 ms native-side). |
| `style` / `fallback` / `children` | RN props | `fallback` renders until the native module is ready. |

## Session helpers

```ts
await createAIUXSession({ sessionId: 's1', title: 'Demo', context, capabilities });
await dispatchAIUXBatch('s1', events);                 // object[] — → AIUXDispatchReport
const snap = await getAIUXSnapshot('s1');              // parsed render projection
const persisted = await serializeAIUXSession('s1');    // string — persist verbatim
await restoreAIUXSession(persisted);                   // resume (id + state inside)
await resetAIUXSession('s1');
const native = getNativeModule();                      // raw expo module (escape hatch)
```

`createAIUXSession(bootstrap)`:

- `bootstrap`: `{sessionId, title?, context?, capabilities?, sequence?}`.
- With `title`/`context`/`capabilities` it also dispatches a seed
  `session.created` — consuming **`sequence: 0`** of the stream. A producer
  emitting its own `session.created` must start sequences after the seed.
- Idempotent: a second call for a session that already holds a session entity
  skips the seed. Concurrent calls serialize per `sessionId`.

## `createAIUXTransport`

The batched event boundary — `EventBuffer` (16–50 ms flush) coalesces pushes;
an internal FIFO drains ordered `dispatchBatch` calls onto the native session.

```ts
const transport = createAIUXTransport('s1', {
  policy: { flushIntervalMs: 32, maxEvents: 64 },
  onDispatch: (report) => console.log(report.applied),
  maxBatchRetries: 8,
});

transport.push(eventOrJson);    // queue one event; throws once closed
transport.flush();              // force buffer flush + kick the drain
await transport.close();        // flush, stop accepting, drain — rejects if
                                // batches remain undelivered
transport.pending;              // events buffered, not yet serialized
transport.inflight;             // batch payloads awaiting native delivery
transport.closed;
```

Delivery semantics:

- A **permanently rejected** batch (prefix-matched `invalid event:` /
  `sequence gap:` / replayed ids after a remount) retries up to
  `maxBatchRetries` (default 8) then drops the head so the FIFO can't freeze
  the conversation. Transient failures keep the head forever — events are
  never silently lost.
- A failed batch stays queued: protocol `eventId`s make replay safe via core
  dedup.
- `flush()` also kicks the drain — call it at end-of-stream.

## Types

`AIUXThemeInput` (`{colors, spacing, radius, motion, density, colorScheme}`),
`AIUXColorRole` (17 roles incl. native-only `inputSurface`, `codeSurface`,
`codeForeground`, `mutedForeground`, `destructiveForeground`),
`AIUXColorRoles`/`AIUXColorValue` (`#rgb`, `#rrggbb`, `#rrggbbaa` strings),
`AIUXContextEntity`, `AIUXCapability`, `AIUXAction`, `AIUXErrorInfo`,
`AIUXDispatchReport`, `AIUXSnapshot`, `AIUXEventLike` (object or JSON string),
`AIConversationMode`, `AIUXComposerToolbarSpec`, `AIUXComposerToolSpec`
(`{id, label, glyph?}`), `AIUXComposerGlyphName`
(`"sparkle" | "doc" | "photo" | "gear" | "globe" | "mic" | "search" | "plus" | "star"`),
`AIUXSessionBootstrap`, `AIUXTransport`, `AIUXTransportPolicy`
(= `EventBufferPolicy` from aiux-core).

## Working references

- [`examples/expo/src/App.tsx`](../../examples/expo/src/App.tsx) — mounting,
  theme switching, live/mock toggles.
- [`examples/expo/src/DemoController.ts`](../../examples/expo/src/DemoController.ts)
  — the complete action→event→transport→snapshot loop, incl. approval parking,
  cancellation and a real OpenRouter streaming path.
