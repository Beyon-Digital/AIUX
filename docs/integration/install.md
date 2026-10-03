# Consumer installation

AIUX first-party code is MIT. The first installable candidate is **0.1.1** under
npm scope **@beyond-digital**. Until publication completes, the commands below
are release targets, not a claim of registry availability. v0.1.0 remains an
older draft; its source archives are not npm packages. Check the [releases](https://github.com/Beyon-Digital/AIUX/releases)
and `npm view @beyond-digital/aiux-core@0.1.1 version` before installing.

| Client | Distribution / availability |
| --- | --- |
| JS/WASM + React DOM | Seven implemented packages; versioned npm tarballs and npmjs after publication |
| Expo SDK 57 | Native bridge exists for iOS/Android; npm tarball must contain both platform artifacts; development build required |
| Plain React Native Fabric bridge | Scaffold only; private and excluded from release. Use Expo modules in an RN app with compatible Expo modules installed |
| GraphQL adapter | Scaffold only; private and excluded. SSE, WebSocket and AI SDK adapters are implemented |
| SwiftUI / Swift core | Standalone `aiux-swift-package.tar.gz` on GitHub Releases; iOS 16+, macOS 13+; local SwiftPM package |
| Compose / Kotlin core | `aiux-android-maven.tar.gz` contains AARs and POMs with dependencies; local Maven repository, API 24+, compile SDK 36, Java 17 |
| Rust core | Git dependency at a release tag; crates.io publication not configured |
| Dart / Flutter | Git dependencies at a release tag; pub.dev publication not configured. Native C ABI must be supplied for the app's target |

## Web / Node

Node 20+; React and React DOM 18.3+ (validated with 19.2.3).

```sh
npm install @beyond-digital/aiux-core@0.1.1 @beyond-digital/aiux-web@0.1.1 react react-dom
npm install @beyond-digital/aiux-adapter-sse@0.1.1
```

Other one-line packages: `npm install @beyond-digital/aiux-adapter-websocket@0.1.1`,
`npm install @beyond-digital/aiux-adapter-ai-sdk@0.1.1`,
`npm install @beyond-digital/aiux-transport-js@0.1.1`, and
`npm install @beyond-digital/aiux-protocol-types@0.1.1`.

For Vite, import the shipped WASM URL; no Rust or wasm-bindgen installation is
needed by the consumer:

```ts
import { AiuxSession, wasmCore } from '@beyond-digital/aiux-core';
import init, * as wasm from '@beyond-digital/aiux-core/wasm';
import wasmUrl from '@beyond-digital/aiux-core/wasm/aiux_wasm_bg.wasm?url';
import '@beyond-digital/aiux-web/styles.css';
await init({ module_or_path: wasmUrl });
const session = AiuxSession.create(wasmCore(wasm), '{}');
// Feed protocol events with session.dispatchBatch(events), subscribe to snapshots.
// Dispose on host teardown: session.dispose().
```

See [the working web host](../../examples/web/src/host.ts) for transport, action
handling, and lifecycle wiring. Host policy executes actions; renderers emit
semantic actions. Provider credentials belong in the host backend.

## Expo and React Native with Expo modules

Expo SDK 57, React 19+, RN 0.86.x. Expo Go cannot load this custom native module.
For bare RN first install the matching Expo modules; the plain Fabric bridge is
not released.

```sh
npx expo install @beyond-digital/aiux-expo@0.1.1
npx expo prebuild && npx expo run:android
# On macOS with Xcode: npx expo run:ios
```

Published packages contain the iOS XCFramework, generated Swift API, SwiftUI
renderer and Android Maven artifacts/POMs. Consumers must not run
`prepare:ios`, use repository `includeBuild`, or compile Rust. Android resolves
bundled Maven coordinates through the bridge's Gradle configuration. iOS needs
an iOS 16+ deployment target. See [Expo example](../../examples/expo) for
`AIConversation`, session bootstrap and batched transport usage.

## Swift

After downloading and verifying `aiux-swift-package.tar.gz` from the exact
release, extract into `Vendor/AIUX`. Add `.package(path: "Vendor/AIUX")` to the
host's SwiftPM dependencies and products `AIUXCore` and `AIUXSwiftUI` to its
target. The package includes its binary FFI target; the monorepo's
`bindings/swift/Package.swift` is only a source-development manifest.

```sh
mkdir -p Vendor/AIUX && tar -xzf aiux-swift-package.tar.gz -C Vendor/AIUX
```

## Android

Extract `aiux-android-maven.tar.gz` to `Vendor/AIUX`; configure
`maven { url = uri("Vendor/AIUX/maven") }` in the host's repositories alongside
Google and Maven Central. Install with
`implementation("in.beyondigital.aiux:compose:0.1.1")` and
`implementation("in.beyondigital.aiux:bindings:0.1.1")`. Keep the bundled POMs;
copying loose AARs loses JNA, Compose and other transitive dependency metadata.

## Rust

```sh
cargo add aiux-session --git https://github.com/Beyon-Digital/AIUX --tag v0.1.1
```

Path dependencies resolve within Cargo's Git checkout. Rust delivery binaries
are built on GitHub CI, not on the release operator's Mac. The release's Linux
native libraries are Linux artifacts, not universal binaries.

## Dart / Flutter

Use the Git repository with `ref: v0.1.1` and `path: bindings/dart` for
`aiux_ffi`; use `path: renderers/flutter` for `beyond_aiux`. For local
checkout development the Flutter renderer's relative path dependency is
intentional. A Git consumer must override that dependency to the same Git tag: A published pub.dev package is not yet available.

```sh
flutter pub add --override 'aiux_ffi:{git: {url: https://github.com/Beyon-Digital/AIUX, ref: v0.1.1, path: bindings/dart}}'
flutter pub add 'beyond_aiux:{git: {url: https://github.com/Beyon-Digital/AIUX, ref: v0.1.1, path: renderers/flutter}}'
```

The Dart loader accepts `AiuxCapi(libraryPath: ...)` or `AIUX_CAPI_PATH`. Linux
CI release libraries can serve Linux consumers; Android/iOS/macOS/Windows
apps need a matching C ABI library and platform bundling. Mobile FFI distribution
is not yet packaged. Do not install the Linux `.so` on a mobile or Apple target.

## Verify the downloaded release

`SHA256SUMS` hashes the files using artifact-relative paths. Preserve those paths
or compare individual file hashes. npm tarballs are created with `pnpm pack`,
which converts workspace dependencies to versioned registry dependencies.
[Release checklist](ci-release.md) explains the executable gates and publishing.
Native accessibility/device checks remain pending wherever marked manual in
[accessibility](../renderers/accessibility.md); automated builds do not sign them off.
