# Compatibility Matrix — v0.1.0

Protocol versions × renderer versions × platform minimums. Policy rules:
`docs/integration/compatibility-policy.md`.

## Version correspondence (single release train)

| Protocol | Rust core | SwiftUI | Compose | Expo | Web | Flutter | Dart bindings |
|----------|-----------|---------|---------|------|-----|---------|---------------|
| `0.1` | `0.1.0` | `0.1.0` | `0.1.0` | `0.1.0` (SDK 57) | `0.1.0` | `0.1.0` | `0.1.0` |

Every component reports its target (`AIUXSwiftUI.protocolVersion`,
`aiuxProtocolVersion`, JS `aiux-core` version). `0.1` payloads are
interchangeable across all `0.1.x` components; additive producer↔renderer
skew is tolerated per the policy doc.

## Platform minimums

| Surface | Minimum | Verified on |
|---------|---------|-------------|
| SwiftUI renderer + `AIUXCore` XCFramework | iOS 16 / macOS 13 (Package.swift `platforms:`) | Xcode 16, iPhone 15 sim + macOS — CI (`swift-bindings`, `expo-ios`) |
| Compose renderer + kotlin bindings | `minSdk 24` (Android 7.0); `compileSdk 36`; JDK 17 | API 34 emulator — CI (`kotlin-bindings`, `expo-android`) |
| Expo bridge | Expo SDK **≥57** (`peer: >=57.0.0`), `react-native >=0.86`, `react` 19.2.x | SDK `~57.0.26` / RN `0.86.3` / react `19.2.3` — examples/expo |
| Web renderer | React **≥18.3** (`peer`); modern evergreen browsers (ES2020+, WASM) | react `19.2.3` + `react-dom 19.2.3`, jsdom + Chromium — CI (`js`, `web-build`) |
| Flutter renderer | Dart `>=3.4.0 <4.0.0`, Flutter stable | CI `subosito/flutter-action@stable` |
| wasm core | `wasm32-unknown-unknown`, `wasm-bindgen 0.2.129` (locked to Cargo.lock) | node 22 + browser — CI |
| Rust core | rustc stable ≥1.85 (edition 2021, workspace) | `dtolnay/rust-toolchain@stable` — CI |
| UniFFI | `=0.29.5` (pinned) | — |

## Known coupling notes

- `react`/`react-dom` must be the **same version** — jsdom+vitest explode on
  `react 19.2.3`/`react-dom 19.3.0` ("Incompatible React versions"). The
  workspace pins `19.2.3`; host apps should too.
- pnpm workspace: `@types/node` is unified at `22.20.4` — mixed versions
  fork vitest into two peer contexts and break `toMatchSnapshot`
  ("SnapshotClient.setup() not found"). Keep it aligned.
- `wasm-bindgen-cli` version must equal the `wasm-bindgen` crate in
  Cargo.lock (`0.2.129`) — `bindings/wasm/build.sh` assumes the match.
- UniFFI pins `=0.29.5`: generated Swift/Kotlin sources are
  toolchain-version-sensitive; regenerating under a different version is a
  diff CI will flag via the bindings jobs.
- Node ≥18 required by workspace tooling (pnpm 12, vitest 3.2); dev
  toolchain is node 22.x.

## Event/payload compatibility

Producer → any `0.1` renderer is safe when the stream uses the 20 event
types + 13 part kinds + 29 surface nodes of protocol `0.1`. Unknown event
types → `unsupported` (explicit error, no corruption); unknown optional
fields → stripped/ignored (additive tolerance).
