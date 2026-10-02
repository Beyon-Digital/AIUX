# @beyondigital/aiux-web

The AIUX web renderer (plan §12): a React DOM adapter over the frozen session
facade. Reads the session snapshot → DOM/ARIA output; every user interaction
emits a semantic action the host resolves — the component never mutates state
directly (§23).

```tsx
import { AiuxSession, wasmCore } from "@beyondigital/aiux-core";
import init, * as wasm from "@beyondigital/aiux-core/wasm";
import wasmUrl from "@beyondigital/aiux-core/wasm/aiux_wasm_bg.wasm?url";
import { AIConversation } from "@beyondigital/aiux-web";
import "@beyondigital/aiux-web/styles.css";

await init({ module_or_path: wasmUrl });
const session = AiuxSession.create(wasmCore(wasm), "{}");

<AIConversation
  session={session}          // or sessionId + <AiuxSessionProvider>
  theme={{ colorScheme: "auto" }}
  mode="fullscreen"          // or "embedded"
  onAction={handleAction}    // host policy: turn actions into protocol events
/>
```

## What's inside

- **`AIConversation`** — header, context bar, `role="feed"` message list
  (PageUp/PageDown/Home/End article navigation, scroll-pinning), activity
  rail for snapshot entities not referenced by any message part, composer,
  drag/drop attach overlay. `session` prop takes a live `AiuxSession`;
  `sessionId` resolves via `AiuxSessionProvider`.
- **All 13 part types** — text, markdown (AST-only via react-markdown +
  `skipHtml`, URL scheme allowlist, `target=_blank rel=noopener` — never
  `dangerouslySetInnerHTML`), code with copy-to-clipboard, image, attachment
  (real link), citation, tool, approval (`role="alertdialog"` + resolve
  actions), artifact preview, status, progress, surface, error + retry.
- **`AISurface`** — all 26 §6 surface primitives mapped to semantic DOM/ARIA
  (card→`section`, list→`ul/ol`, keyValue→`dl`, table→scoped `th`, menu→
  `details`+`role=menu`, inputs with per-surface field state merged into
  action payloads).
- **Theme** — `AiuxTheme` → `--aiux-*` CSS custom properties scoped to the
  component root; light + dark + `auto`, `density` scales spacing tokens.
- **`createEventDriver(session)`** — web transport adapter queueing events
  into `EventBuffer` so streaming deltas batch into `dispatchBatch` (§22).
- **Browser-native semantics** — ARIA roles/labels, keyboard nav, focus
  management, real links, text selection, clipboard API + execCommand
  fallback, file picker + drag/drop hooks (`useFilePicker`/`useFileDrop`
  exported for custom composers), responsive + `prefers-reduced-motion`.

## Tests

`pnpm --filter @beyondigital/aiux-web test` — vitest + Testing Library for
every part renderer, surface primitive, keyboard/focus behaviors, and the
Phase-5 conformance gate: all fixtures replayed through the real wasm core
with byte-identical `serialize()` (skipped when `bindings/wasm/pkg/` is
absent — build it with `pnpm --filter @beyondigital/aiux-core build:wasm`).

See `examples/web` for the full fixture-replay app.
