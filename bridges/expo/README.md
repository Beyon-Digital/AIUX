# @beyondigital/aiux-expo

Expo SDK 57 bridge for AIUX — the complete native conversation surface behind
one coarse boundary (docs/PLAN.md §10, ADR 0002). iOS hosts the SwiftUI
renderer; Android hosts the Compose renderer; both drive the same `AiuxSession`
facade in the Rust core. **No message UI is ever rebuilt in React Native.**

```tsx
import { AIConversation } from "@beyondigital/aiux-expo";

<AIConversation
  sessionId="s1"
  theme={theme}
  context={context}
  capabilities={capabilities}
  onAction={handleAction}
  mode="fullscreen" // or "embedded"
/>
```

## JS surface (kept minimal for the future `@beyondigital/aiux-react-native`)

- `<AIConversation/>` — native view. Props: `sessionId`, `theme`
  (`AIUXThemeInput` object or JSON string), `mode`, `showComposer`, and the
  optional bootstrap props `context`/`capabilities`/`title`. Events:
  `onAction`, `onError`, `onSnapshot` (throttled native-side ~150 ms).
- `createAIUXSession({ sessionId, title?, context?, capabilities? })` —
  creates the native session and optionally seeds a `session.created` event
  (sequence 0) when bootstrap fields are given. If a producer emits its own
  `session.created`, skip the seed props — the session entity always wins.
- `createAIUXTransport(sessionId, { policy?, onDispatch? })` — `EventBuffer`-
  backed event ingestion: pushes coalesce into `dispatchBatch` calls
  (16–50 ms flush / size threshold — ADR 0005). Accepts event objects or
  JSON strings.
- `dispatchAIUXBatch`, `serializeAIUXSession`, `restoreAIUXSession`,
  `resetAIUXSession`, `getAIUXSnapshot` — direct wrappers over the module.

`AIUXAction` payloads (`{ id, payload }`) flow native → `onAction` → the host
app; the library never executes them. `onSnapshot` delivers the canonical
render snapshot verbatim — use it for bespoke chrome, not to drive the view.

## Theme

`theme` maps plan §7 roles → `AIUXTheme` on each platform. Colors are
CSS-style strings (`#rgb`, `#rrggbb`, `#rrggbbaa`, `rgb()/rgba()`); `colors`
may be flat or `{ light, dark }` scoped. `spacing`, `radius`, `motion`
(`"reduced"` or `{ duration }`), `density`, and `colorScheme` are supported.

## Native dependencies

- **Android**: the module declares `aiux:compose` / `aiux:bindings` — resolved
  to this repo's `renderers:compose` + `bindings:kotlin` via the consuming
  app's `includeBuild` + `dependencySubstitution` (see `examples/expo/android`).
- **iOS**: the pod compiles `renderers/swiftui` + the generated UniFFI binding
  and vendors `AIUXCore.xcframework`, staged by `scripts/prepare-ios.sh`
  (`pnpm --filter @beyondigital/aiux-expo prepare:ios`, macOS only).
