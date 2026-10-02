# AIUX — Execution Tracker

Progress ledger for the multi-session build of `docs/PLAN.md`. **Update rules:**
whoever does the work edits the row in the same PR — mark `[x]` with the PR link,
or `[~]` plus a note when partially landed. New session? Read `docs/PLAN.md`
first, then this file; pick the lowest-numbered unblocked phase.

Legend: `[ ]` todo · `[~]` in progress · `[x]` done · `(_)` blocked/skipped (note why)

## Status snapshot

- Current phase: **Phase 0 → Phase 1**
- Branching model: one draft PR per phase, branched off `main` (or off the prior
  open phase branch when it is still unmerged — keep PRs stackable and small).
- Parallel lanes: SwiftUI (PR 4) ∥ Compose (PR 5) after PR 3; Web/WASM (PR 7)
  can run parallel once PR 2 lands. Expo (PR 6) needs PRs 4+5.
- Constraints: Linux dev box — Rust/Kotlin/WASM/Web/Compose verifiable locally;
  Swift compile + iOS verify via macOS CI runners only. UniFFI version is pinned —
  do not bump without compat CI.

## Phase 0 — Repository + engineering foundation → PR 1

- [x] Monorepo layout per plan §2 (all dirs scaffolded)
- [x] Cargo workspace (9 core crates + `bindings/wasm`)
- [x] pnpm workspace (bridges, transports/javascript, adapters, web, examples)
- [x] Gradle wrapper + root build (compose renderer, android example — JVM stubs)
- [x] SPM stubs (renderers/swiftui, examples/ios-native)
- [x] Formatters/linters (rustfmt.toml, clippy.toml, .editorconfig)
- [x] ADRs 0001–0006 (state engine, renderers, versioning, transport, FFI, surface)
- [x] CI workflows with timeout + concurrency guardrails (`ci.yml`, `release.yml`)
- [x] CODEOWNERS, .gitignore, blueprint (`.devin/blueprint.yaml`)
- [x] docs/PLAN.md + TASKS.md
- **Gate:** every empty/example target builds on CI — PR 1 must be green.

## Phase 1 — Protocol v1 + Rust core → PR 2

- [x] JSON schemas in `protocol/schemas/v1/` for all core entities + events
- [x] `aiux-protocol` — types, serde, protocolVersion, envelope validation
- [x] `aiux-session` — session state, ordering buffer, idempotency (eventId set)
- [x] `aiux-reducer` — deterministic `dispatch`/`dispatch_batch`
- [x] Tool/approval/artifact lifecycles (in `aiux-tools/-approvals/-artifacts`)
- [x] `aiux-surfaces` — initial Surface Schema primitives per plan §6
- [x] `aiux-persistence` — serialize/restore (JSON, canonical ordering)
- [x] Public API: `create_session / restore_session / dispatch /
  dispatch_batch / snapshot / serialize / reset` (plan §4)
- [x] Out-of-order handling: buffer or explicit recoverable error — never
  silent corruption
- [x] Conformance: `conformance/harness` fixture runner +
  `conformance/fixtures/*` + `conformance/expected/*` (plan §17 list)
- [x] Property/replay/serialization tests (plan §18)
- **Gate:** same event fixture → exact expected serialized state.
  **No UI begins before this gate passes.**

## Phase 2 — Native bindings → PR 3

- [x] UniFFI (pinned `=0.29.5`) — `AiuxSession` object: `create()`,
  `restore()`, `dispatch()`, `dispatchBatch()`, `snapshot()`, `serialize()`,
  `reset()`
- [x] Swift bindings + XCFramework/SPM packaging path (verified on macOS CI)
- [x] Kotlin bindings + Android library (AAR) packaging path
- [x] Binding smoke tests both languages (Kotlin JVM+CI; Swift macOS CI)
- **Gate:** Swift + Kotlin example tests can create session → dispatch fixture →
  snapshot → serialize → restore.

## Phase 3 — SwiftUI + Compose MVP → PRs 4 + 5 (parallel lanes)

- [x] SwiftUI: `AIConversation AIComposer AIMessage AIToolStatus AIApproval
  AIArtifactPreview AISurface AIContextBar` (plan §8)
- [x] Compose: same component set (plan §9)
- [ ] Fixture catalog both renderers: text, markdown, code, status, tool,
  approval, composer, context chip, surface/card/button
  - [x] SwiftUI: `AIFixturePlayer` + `AIUXFixtureCatalog` replaying
    `conformance/fixtures/*.json`; conformance parity test vs `expected/`
  - [x] Compose: `SnapshotMappingTest` replays all 21 fixtures; unknown
    node/part coverage
- [ ] Theme contract mapping + light/dark (plan §7)
  - [x] SwiftUI: `AIUXTheme` roles (colors/typography/spacing/radius/motion/
    density), light + dark via `AIUXColor`
  - [x] Compose: `AIUXTheme` §7 roles → Material3, light + dark
- [ ] Examples: ios-native app, android-native app
  - [x] ios-native: real app over UniFFI (conversation + fixture gallery +
    agent log), headless `swift run AIUXExample` scenario gate
  - [x] android-native: mocked agent script + fixture browser
- **Gate:** mocked agent interaction end-to-end on both platforms: user prompt →
  stream → tool start/finish → approval → approve → render result.
  - [x] iOS (`AIUXExample` scenario + XCTest, verified on macOS CI)
  - [x] Android (mocked agent script verified on `vendor_v3` emulator)

## Phase 4 — Expo SDK 57 bridge → PR 6

- [x] `@beyondigital/aiux-expo` — Expo Modules native view
- [x] `<AIConversation sessionId theme context capabilities onAction />`
- [x] iOS: Expo view → SwiftUI hosting → AIUXSwiftUI → core
- [x] Android: Expo view → ComposeView → AIUXCompose → core
- [x] JS transport adapter + event buffer + `dispatchBatch` flush policy
  (16–50 ms coalescing + size cap; FIFO drain keeps ordering, failures
  requeue for the next flush — event-id dedup makes replays safe)
- [x] examples/expo running the mocked fixture (dev-client, prompt → stream →
  tool → approval → surface → error+retry, light/dark — verified on
  `vendor_v3` emulator)
- **Gate:** same fixture natively on iOS+Android, zero RN message UI.
  Android verified end-to-end; iOS compiles via macOS CI (xcodebuild sim).

## Phase 5 — Web → PR 7

- [ ] `aiux-wasm` — wasm-bindgen surface over core
- [ ] `@beyondigital/aiux-core` (JS session wrapper + subscriptions)
- [ ] `@beyondigital/aiux-web` React DOM renderer (fullscreen + embedded modes)
- [ ] Web adapter + examples/web fixture playback
- **Gate:** same protocol fixture runs through iOS, Android, Expo and web.

## Phase 6 — Surface DSL + artifacts expansion → PR 8

- [ ] forms, tables, keyValue, lists
- [ ] artifact preview + artifact workspace contract
- [ ] actions + validation
- [ ] custom node registration contract
- **Gate:** one structured tool result renders semantically on every completed
  renderer from the same Surface payload.

## Phase 7 — Flutter → PR 9

- [ ] narrow C ABI over Rust core
- [ ] Dart FFI wrapper (`beyond_aiux`)
- [ ] Flutter renderer + fixture app
- **Gate:** conformance scenario passes without platform-view dependency.

## Phase 8 — Production/release hardening → PR 10

- [ ] benchmarks (first render, 1k-msg restore, stream throughput, 100-ev
  batch, surface render, memory)
- [ ] large conversation tests + accessibility checks + golden tests
- [ ] compatibility matrix + migration docs + package docs
- [ ] release notes automation + dependency audit
- [ ] tag `v0.1.0` internal release via `release.yml`
- **Gate:** v0.1 DoD (plan §26) — one Expo app installs AIUX, renders
  `<AIConversation/>`, demo conversation covers streaming/markdown/code/
  tool/progress/approval/surface/context/error+retry/light+dark.

## Parking lot (explicitly out of v0.1 per plan §15)

Flutter, full web artifact workspace, voice, video, complex charts, 100 DSL
components, native networking stack, provider SDKs, public registry publishing.
