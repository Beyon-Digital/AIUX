# Quickstart

Get a working AIUX conversation rendering in a few minutes. Each section is
self-contained — pick your platform. For exact package names, versions, and
native prerequisites see [consumer installation](../integration/install.md).

Every platform follows the same loop:

1. **Create a session** — `create(config)` (or `restore(serialized)`).
2. **Dispatch events** — protocol `AIUXEvent` envelopes from your backend.
3. **Render the snapshot** — a renderer component consumes `snapshot()`.
4. **Handle actions** — interactions emit semantic `AIUXAction`s back to you.

---

## Web (React + WASM)

```sh
npm install @beyond-digital/aiux-core@0.1.1 @beyond-digital/aiux-web@0.1.1 \
    @beyond-digital/aiux-adapter-sse@0.1.1 react react-dom
```

Initialize the bundled WASM core once, create a session, render
`<AIConversation>`:

```ts
// aiux.ts — run once before creating sessions
import init, * as wasm from '@beyond-digital/aiux-core/wasm';
import wasmUrl from '@beyond-digital/aiux-core/wasm/aiux_wasm_bg.wasm?url';
import { AiuxSession, wasmCore } from '@beyond-digital/aiux-core';

await init({ module_or_path: wasmUrl });          // Vite: ?url import
const core = wasmCore(wasm);
export const session = AiuxSession.create(core, {
  protocolVersion: '0.1',
  sessionId: 's1',
});
```

```tsx
import '@beyond-digital/aiux-web/styles.css';
import { AIConversation, createEventDriver } from '@beyond-digital/aiux-web';
import { session } from './aiux';

const driver = createEventDriver(session);

export function Chat() {
  return (
    <AIConversation
      session={session}
      onAction={(action) => {
        if (action.id === 'aiux.composer.submit') {
          const text = String(action.payload.text ?? '');
          void sendToBackend(text, driver); // your code: stream → driver.push(...)
        }
      }}
    />
  );
}
```

`createEventDriver` returns an `EventBuffer`-backed sink: `driver.push(event)`
queues protocol events and flushes them as ordered `dispatchBatch` calls —
never dispatch per token.

Working reference: [`examples/web/src/host.ts`](../../examples/web/src/host.ts).

## Expo / React Native (SDK 57)

```sh
npx expo install @beyond-digital/aiux-expo@0.1.1
npx expo prebuild          # custom native module — Expo Go cannot load it
npx expo run:ios           # macOS + Xcode
npx expo run:android
```

```tsx
import {
  AIConversation,
  createAIUXSession,
  createAIUXTransport,
} from '@beyond-digital/aiux-expo';

await createAIUXSession({
  sessionId: 's1',
  title: 'Assistant',
  context: [{ id: 'ctx-1', kind: 'repo', label: 'Beyon-Digital/AIUX' }],
});
const transport = createAIUXTransport('s1');

<AIConversation
  sessionId="s1"
  theme={{ colorScheme: 'system' }}
  onAction={(action) => {
    if (action.id === 'aiux.composer.send') {
      void sendToBackend(String(action.payload.text ?? ''), transport);
    }
  }}
/>;
```

The published package already contains the iOS XCFramework + Android Maven
artifacts — do not run `prepare:ios` or add repository `includeBuild`s.
Working reference: [`examples/expo/src/App.tsx`](../../examples/expo/src/App.tsx)
and [`DemoController.ts`](../../examples/expo/src/DemoController.ts) (full
lifecycle: actions → events → transport → snapshot).

## SwiftUI

```sh
mkdir -p Vendor/AIUX
tar -xzf aiux-swift-package.tar.gz -C Vendor/AIUX   # from the v0.1.1 release
```

Add `.package(path: "Vendor/AIUX")` to your package dependencies and products
`AIUXCore` + `AIUXSwiftUI` to your app target (iOS 16+ / macOS 13+).

```swift
import AIUXCore
import AIUXSwiftUI

let backend = try UniFFIBackend.create(configJson: #"{"sessionId":"s1"}"#)
let store = AIUXSessionStore(backend: backend)

struct RootView: View {
    var body: some View {
        AIConversation(store: store)
            .onAIUXAction { action in
                if action.id == "aiux.composer.send" {
                    Task { await sendToBackend(text: action.text, store: store) }
                }
            }
    }
}
```

`UniFFIBackend` is a ~35-line adapter that conforms the generated
`AiuxSession` (`AiuxSession.create(configJson:)` / `dispatch(eventJson:)` …)
to the renderer's `AIUXSessionBackend` protocol (JSON in → JSON out). A copy
ships in
[`examples/ios-native/Sources/AIUXExampleApp/UniFFIBackend.swift`](../../examples/ios-native/Sources/AIUXExampleApp/UniFFIBackend.swift).

## Jetpack Compose

Extract `aiux-android-maven.tar.gz` to `Vendor/AIUX` and add
`maven { url = uri("Vendor/AIUX/maven") }` to your repositories.

```kotlin
implementation("in.beyondigital.aiux:compose:0.1.1")
implementation("in.beyondigital.aiux:bindings:0.1.1")
```

```kotlin
val store = AIUXSessionStore.create("""{"sessionId":"s1"}""")

setContent {
    AIUXThemeProvider {
        val snapshot by store.snapshot.collectAsState()
        AIConversation(
            snapshot = snapshot,
            onAction = { action ->
                if (action.id == AIUXActions.COMPOSER_SEND) {
                    val text = action.payload["text"]?.jsonPrimitive?.content ?: ""
                    sendToBackend(text)   // stream events → store.dispatchBatch
                }
            },
        )
    }
}
```

`AIUXSessionStore` wraps the UniFFI `AiuxSession` in `StateFlow`s and runs
dispatch on `Dispatchers.IO`. `AIUXActions` holds the semantic action ids as
constants; `action.payload` is a kotlinx `JsonObject`.

## Flutter

```sh
flutter pub add --override \
  'aiux_ffi:{git: {url: https://github.com/Beyon-Digital/AIUX, ref: v0.1.1, path: bindings/dart}}'
flutter pub add \
  'beyond_aiux:{git: {url: https://github.com/Beyon-Digital/AIUX, ref: v0.1.1, path: renderers/flutter}}'
```

You must also ship the native `libaiux_capi` for your target (see
[install](../integration/install.md#dart--flutter)).

```dart
final store = AiuxSessionStore(
  backend: AiuxFfiBackend(AiuxCapi(libraryPath: 'libaiux_capi.dylib')
      .createSession(jsonEncode({'sessionId': 's1'}))),
);

AiuxTheme(
  data: AiuxThemeData.light(),
  child: AIConversation(
    store: store,
    onAction: (action) {/* route semantic actions to your backend */},
  ),
);
```

## Rust (core only)

```sh
cargo add aiux-session --git https://github.com/Beyon-Digital/AIUX --tag v0.1.1
```

```rust
use aiux_session::AiuxSession;

let mut session = AiuxSession::create(r#"{"sessionId":"s1"}"#)?;
let report = session.dispatch_batch(events_json)?;   // JSON array in
let snapshot = session.snapshot()?;                  // render projection out
let persisted = session.serialize()?;                // for resume
```

The full contract is in [the session contract](../api/session-contract.md).

## Your first event stream

A minimal script that renders a message — dispatch these envelopes in order
(one `session.created` seeds the session, then user + assistant messages):

```jsonc
[
  { "eventId": "e0", "sessionId": "s1", "sequence": 0,
    "timestamp": "2026-01-01T00:00:00Z", "type": "session.created",
    "payload": { "protocolVersion": "0.1",
      "session": { "id": "s1", "title": "Demo", "createdAt": "2026-01-01T00:00:00Z", "context": [] } } },
  { "eventId": "e1", "sessionId": "s1", "sequence": 1, "type": "run.started",
    "timestamp": "…", "payload": { "protocolVersion": "0.1",
      "run": { "id": "r1", "status": "running", "startedAt": "…" } } },
  { "eventId": "e2", "sessionId": "s1", "sequence": 2, "type": "message.created",
    "timestamp": "…", "payload": { "protocolVersion": "0.1",
      "message": { "id": "m1", "role": "assistant", "status": "streaming" } } },
  { "eventId": "e3", "sessionId": "s1", "sequence": 3, "type": "part.added",
    "timestamp": "…", "payload": { "protocolVersion": "0.1", "messageId": "m1",
      "part": { "id": "p1", "type": "markdown", "markdown": "**Hello** from AIUX" } } },
  { "eventId": "e4", "sessionId": "s1", "sequence": 4, "type": "message.updated",
    "timestamp": "…", "payload": { "protocolVersion": "0.1", "messageId": "m1",
      "message": { "status": "complete" } } },
  { "eventId": "e5", "sessionId": "s1", "sequence": 5, "type": "run.completed",
    "timestamp": "…", "payload": { "protocolVersion": "0.1", "runId": "r1" } }
]
```

Notes on the envelope:

- `sequence` is 0-based and contiguous per session — a gap buffers the event
  until the missing sequences arrive (or `SequenceGap` past the buffer bound).
- `eventId` dedupes: re-dispatching a seen id is a no-op, so replays are safe.
- Every payload repeats `protocolVersion` (`"0.1"` for v1 events).
- `text.delta` streams text into an existing part instead of `part.added`.

Ready-made event scripts: [`conformance/fixtures`](../../conformance/fixtures)
and the [testing guide](../guides/testing.md).

## Next steps

- Wire a real model: [connecting a model](../guides/connecting-a-model.md)
- Customise the look: [theming](../guides/theming.md) ·
  [composer toolbar](../guides/composer-toolbar.md) ·
  [custom surface nodes](../guides/surfaces.md)
- Handle every action: [action vocabulary](../guides/actions.md)
- Persist/resume: [persistence](../guides/persistence.md)
