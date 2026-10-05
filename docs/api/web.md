# Web renderer — `@beyond-digital/aiux-web`

React DOM renderer for AIUX snapshots. Source: [`renderers/web`](../../renderers/web).
Pairs with [`@beyond-digital/aiux-core`](js-core.md) (WASM session) and needs
`react`/`react-dom` 18.3+ (validated on 19.2.3). Always import the stylesheet:

```ts
import '@beyond-digital/aiux-web/styles.css';
```

## `<AIConversation>`

The root surface — renders context bar, message feed, unreferenced tools/
approvals/artifacts/surfaces, and the composer.

```tsx
<AIConversation
  session={session}                  // AiuxSessionLike — or sessionId via provider
  theme={{ colorScheme: 'auto', colors: { accent: '#7c3aed' } }}
  context={extraContextEntities}
  capabilities={[{ id: 'attachments', enabled: true }]}
  customNodes={{ 'finance.card': FinanceCard }}
  mode="fullscreen"
  onAction={handleAction}
/>
```

| Prop | Type | Notes |
| --- | --- | --- |
| `session` | `AiuxSessionLike` | Live session object (the `@beyond-digital/aiux-core` `AiuxSession` satisfies it). Boundary is `snapshot(): unknown` + `subscribe`. |
| `sessionId` | `string` | Alternative — resolved through `AiuxSessionProvider`. |
| `theme` | `AiuxTheme` | Partial overrides → [theming guide](../guides/theming.md). |
| `context` | `readonly ContextEntity[]` | Extra entities merged into the context bar. |
| `capabilities` | `readonly Capability[]` | Gating declarations — undeclared capabilities default to enabled. |
| `onAction` | `AiuxActionHandler` | `(action: AiuxAction) => void`. Every interaction emits a semantic action — the renderer never executes. |
| `customNodes` | `Record<string, AiuxCustomNodeComponent>` | Registry for `custom` surface nodes — key is the node's `kind`. |
| `mode` | `"fullscreen" \| "embedded"` | `fullscreen` fills its container; `embedded` flows inline. |

### Behavior notes

- Messages, tools, approvals, artifacts and surfaces render from the flat
  snapshot. Entities not referenced by any message part (`tool:`/`approval:`/
  `artifact:`/`surface:` ids) render in a trailing "unreferenced" section —
  so artifacts produced outside a message still surface.
- Keyboard: arrow-key navigation across message articles
  (`.aiux-msg`); Enter submits the composer, Shift+Enter newlines, Escape
  clears.
- File drops on the feed emit attachment actions (drag/drop wired through
  `useFileDrop`).
- Reduced motion is auto-detected (`prefers-color-scheme` for scheme,
  media query for motion) and can be forced via `theme.motion.reduce`.

## Session provider

```tsx
<AiuxSessionProvider sessions={{ s1: sessionA, s2: sessionB }}>
  <AIConversation sessionId="s1" onAction={…} />
</AiuxSessionProvider>
```

- `AiuxSessionProvider({sessions, children})` — `Map` or record of id →
  `AiuxSessionLike`.
- `useAiuxSession(sessionId)` → `AiuxSessionLike | undefined`.
- `useSessionSnapshot(session)` → `AiuxSnapshot` — subscribes and returns the
  parsed render projection (re-renders on every session mutation).

## `createEventDriver`

```ts
const driver = createEventDriver(session, { flushIntervalMs: 32 });

driver.queue(aiuxEvent);   // buffer for batched dispatchBatch (streaming path)
driver.dispatch(event);    // immediate single dispatch (rare)
driver.flush();            // → DispatchReport | undefined
driver.close();            // flush + stop
driver.pending;            // queued count
```

`policy` is `EventBufferPolicy` from aiux-core (16–50 ms flush window,
`maxEvents` 64, `maxBytes` 64 KiB). `createEventDriver(session, policy?)` →
`AiuxEventDriver { dispatch, queue, flush, close, pending }`.

## Leaf components

Drop-in pieces for custom layouts — each consumes one entity:

| Component | Prop | Renders |
| --- | --- | --- |
| `AIMessage` | `{ message }` | A message with all 13 part kinds (text, markdown, code, image, attachment, citation, tool, approval, artifact, status, progress, surface, error). Forward-ref. |
| `AIComposer` | `AIComposerProps` | Composer input. `onAction`, `attachmentsEnabled`, `disabled`, `placeholder`. Emits `aiux.composer.submit` / `aiux.composer.attach`. |
| `AIContextBar` | `{ context, … }` | Session + injected context chips. |
| `AIToolStatus` | `{ tool }` | Tool call card: name, args, status, progress, result/error. |
| `AIApproval` | `{ approval }` | Approval gate card — approve/reject emit `aiux.approval.*` actions. |
| `AIArtifactPreview` | `{ artifact }` | Artifact preview card → `aiux.artifact.open`. |
| `AISurface` | `{ surface }` | A surface tree — all 31 schema nodes; form state folded into submit actions; custom kinds via the render context registry. |
| `PartView` | `{ part, … }` | A single message part — for fully custom message layouts. |
| `AiuxMarkdown` | `{ children/markdown }` | The markdown renderer (GFM, code blocks, link allowlist). |
| `AiuxIcon` | `{ name, size?, label? }` | Icon vocabulary used by parts and surfaces. |

## Hooks

| Hook | Returns | Purpose |
| --- | --- | --- |
| `useFilePicker(options)` | `{ open, inputProps }` | Hidden file input + open() — wire to the composer attach action. `onFiles(PickedFile[])`. |
| `useFileDrop(options)` | `{ active, props }` | Drag/drop zone props; `onFiles(PickedFile[])`, `enabled` gate. |
| `useCopyToClipboard()` | `{ copied, copy }` | Copy code/artifact text. |
| `useSessionSnapshot(session)` | `AiuxSnapshot` | Subscribe a session to React state. |

`PickedFile`: `{ file, name, size, type, uri }`-style wrapper for picked/
dropped files (see `hooks.ts`).

## Theming exports

`resolveTheme(theme)` → `ResolvedAiuxTheme`, `themeCssVars(resolved)` →
`Record<string,string>` of `--aiux-*` custom properties, `LIGHT_COLORS`,
`DARK_COLORS`, and types `AiuxTheme`, `AiuxThemeColors`, `AiuxThemeTypography`,
`AiuxTypeRole`, `AiuxThemeSpacing`, `AiuxThemeRadius`, `AiuxThemeMotion`,
`AiuxDensity` (`"compact" | "comfortable"`), `AiuxColorScheme`
(`"light" | "dark" | "auto"`), `ResolvedAiuxTheme`.

Details and token tables: [theming guide](../guides/theming.md).

## Types

`AIUX_ACTIONS` (semantic action id constants), `AiuxAction`,
`AiuxSnapshot`, `AiuxSessionLike`, all entity types (`Message`, `Tool`,
`Approval`, `Artifact`, `Session`, `ContextEntity`, `Capability`,
`Attachment`, `Citation`, `Progress`, `AiuxError`, `Run`, `SurfaceTree`,
`SurfaceNode`, `MenuItem`, `SelectOption`, `KeyValueItem`), all 13 `AiuxPart`
types, `AiuxActionHandler`, `EntityIndex`,
`AiuxCustomNodeComponent` (`ComponentType<{ node: SurfaceNode }>`).

Full action vocabulary: [actions guide](../guides/actions.md).
