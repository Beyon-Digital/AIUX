# Troubleshooting

## Session & dispatch

**`invalid event` rejects that never clear**
The Expo `AIUXTransport` treats `invalid event:`/`sequence gap:` prefixes as
**permanent** — it drops the batch and moves on. Everything else retries the
head forever. If events vanish, check `onDispatch` reports and your envelope
shape against the [contract](api/session-contract.md): `sequence` must be
0-based contiguous per session, `sessionId` must match the session.

**Buffered events that never apply**
`DispatchReport.buffered > 0` means a sequence gap — the event is parked in
the reorder buffer (cap 1024). Find the producer that skipped a number;
don't just resend the parked event.

**Duplicate deliveries doing nothing**
That's the design — `duplicatesIgnored` counts re-sent `eventId`s. Safe
at-least-once delivery is the point.

**`unsupported` on create/restore**
`protocolVersion` mismatch — the wire is `"0.1"`. Set it on the envelope
**and** inside each payload (`createEventFactory` does both).

**`corruptState` on restore**
Persisted blob failed validation — version skew or a hand-edited string.
Fall back to `create`; only `serialize()` output is restorable (never
`snapshot()` — it's a projection, see [persistence](guides/persistence.md)).

## Web

**Wasm never initializes**
`init({module_or_path})` must resolve a fetchable `.wasm` URL — with Vite use
`?url` import or serve `bindings/wasm/pkg`; in test/SSR pass the instantiated
module. `createEventDriver` without init throws at dispatch time.

**Actions do nothing**
`onAction` wasn't wired — the composer *emits* `aiux.composer.submit`, it
doesn't send anything itself. Route actions to your controller
([vocabulary](guides/actions.md)).

## Expo / React Native

**Native screens are blank / `getNativeModule` throws**
The vendored renderer sources are staged — run
`bash bridges/expo/scripts/prepare-ios.sh` (iOS) after regenerating the
XCFramework, and `bindings/kotlin/generate.sh` for Android `.so` slices.
Without them the module loads but never renders.

**Dev client lands on the launcher, not Metro**
Start `expo start --dev-client`, then in the app tap the Metro URL card
(`10.0.2.2:8081` on emulator, `localhost:8081` on iOS sim). `adb reverse
tcp:8081 tcp:8081` also works.

**Fast Refresh ate your state**
Editing source during a run resets the JS session — the native session
survives; edit before relaunching, or persist via `serializeAIUXSession`.

**Composer controls emit, nothing happens**
Same as web — `onAction` routes intents. `attach`, `tools`, `dictate`,
`voice` are all host-implemented.

**`colorScheme` in the `theme` prop doesn't repaint the native view (iOS)**
Changing `theme.colorScheme` after mount is decoded by the bridge
(`AIUXThemeJSON.colorScheme`) but the hosted SwiftUI surface can stay on
its launch appearance — the surrounding RN chrome updates while the
conversation view does not. Workaround: drive appearance from the OS
(`xcrun simctl ui <udid> appearance dark`, or the user's system setting)
or recreate the view on scheme change. Tracked as a bridge bug.

## iOS native

**`AIUXCore` module not found in a consuming app**
Link the XCFramework (`aiux-swift-package.tar.gz` → `AIUXCore.xcframework`)
*and* add `AIUXSwiftUI` sources/package — the renderer never links UniFFI
itself, it talks to `AIUXSessionBackend`. Copy `UniFFIBackend` from
`examples/ios-native` as the adapter.

**Release archive fails on `libaiux_uniffi` slices**
The packaging script lipo's per-slice archives all named
`libaiux_uniffi.a` — if you hand-assemble, keep per-arch staging dirs
separate (see `bindings/swift/package-xcframework.sh`).

## Android native

**`dlopen`/`UnsatisfiedLinkError` on `aiux_uniffi`**
ABI slices missing — `bindings/kotlin/generate.sh` produces
`build/generated/jniLibs/{arm64-v8a,armeabi-v7a,x86_64}` when an NDK is
present. No NDK → it prints "skipping Android .so slices" and the AAR ships
no native lib. x86_64 slice needed for Intel emulators; Apple-Silicon
emulators use arm64-v8a.

**Gradle can't resolve `aiux:compose`/`aiux:bindings`**
Source checkouts need the composite-build substitution (`includeBuild` in
the example's `settings.gradle`); packaged installs need `vendor/maven`
(extracted `aiux-android-maven.tar.gz`) registered as a repo — see
[install](integration/install.md#android).

## Both simulators

**Two booted iPhones / `simctl io booted` captures the wrong one**
`xcrun simctl io booted` picks an arbitrary booted device. Pass the UDID:
`xcrun simctl io <udid> screenshot out.png`, or shutdown extras.

**Emulator taps missing**
`input tap x y` is in *device* pixels, not your screenshot's size — scale
from `wm size` (e.g. 1080x2400). Android 15's status bar eats y < ~63 px.

**"streaming" answer appears all at once**
Deltas went through one event each but dispatched in a single batch — batch
the stream producer-side (`EventBuffer` 16–50 ms or `streamToBatches`) so
the UI ticks between flushes.
