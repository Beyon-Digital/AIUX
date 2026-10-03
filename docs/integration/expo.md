# Expo SDK 57 Integration

`@beyond-digital/aiux-expo` mounts the **real** SwiftUI (iOS) and Compose
(Android) renderers behind one coarse native boundary — no message UI is
rebuilt in React Native (§1/§10, ADR 0002). Full API reference:
`bridges/expo/README.md`; runnable demo: `examples/expo`.

## Install & link

```bash
pnpm add @beyond-digital/aiux-expo
pnpm --filter @beyond-digital/aiux-expo prepare:ios   # macOS: stage XCFramework + bindings
```

- **iOS**: the pod compiles `renderers/swiftui` + generated UniFFI sources
  and vendors `AIUXCore.xcframework` (staged by `scripts/prepare-ios.sh`,
  macOS only).
- **Android**: the module declares `in.beyondigital.aiux:{compose,bindings}`;
  resolve via `includeBuild` + `dependencySubstitution` (see
  `examples/expo/android`), or the published AARs.
- Requires a dev client (`expo prebuild` / EAS dev build) — native code, not
  Expo Go.

## Usage

```tsx
import { AIConversation, createAIUXSession, createAIUXTransport } from "@beyond-digital/aiux-expo";

// one session per conversation
await createAIUXSession({ sessionId: "s1", title: "Demo", context, capabilities });

// transport coalesces events into dispatchBatch (16–50 ms flush, ADR 0005)
const transport = createAIUXTransport("s1", {
  onDispatch: (report) => console.log(report.applied),
});
transport.push(eventJson);            // objects or raw JSON strings

<AIConversation
  sessionId="s1"
  mode="fullscreen"                    // or "embedded"
  theme={theme}                        // object or JSON string
  onAction={({ id, payload }) => routeAction(id, payload)}
  onSnapshot={(snap) => {/* throttled ~150ms — bespoke chrome only */}}
  onError={(e) => {/* AiuxError */}}
/>
```

Also exported: `dispatchAIUXBatch`, `getAIUXSnapshot`,
`serializeAIUXSession`, `restoreAIUXSession`, `resetAIUXSession` — direct
wrappers over the frozen facade.

## Notes

- `createAIUXSession`'s bootstrap props seed `session.created` (seq 0). If
  your producer emits its own `session.created`, omit `title`/`context`/
  `capabilities` — the producer's event wins.
- `onSnapshot` is for bespoke chrome, not to drive the view — the native
  renderer already owns rendering; round-tripping state back in defeats the
  boundary (§1).
- Theme: `AIUXThemeInput` — flat or `{light, dark}` colors; serialized once
  across the bridge (see `docs/renderers/theme-contract.md`).
- SDK 57 pin: `react-native` peer range + `react` 19.2.x — keep the app's
  `react`/`react-dom` aligned (the workspace pins `19.2.3`; a floating
  `react-dom` pulled `19.3.0` and broke jsdom tests — see
  `docs/integration/compatibility-matrix.md`).
