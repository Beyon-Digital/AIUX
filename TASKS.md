# AIUX — Execution Tracker

Progress ledger for the multi-session build of `docs/PLAN.md`. **Update rules:**
whoever does the work edits the row in the same PR — mark `[x]` with the PR link,
or `[~]` plus a note when partially landed. New session? Read `docs/PLAN.md`
first, then this file; pick the lowest-numbered unblocked phase.

Legend: `[ ]` todo · `[~]` in progress · `[x]` done · `(_)` blocked/skipped (note why)

## Status snapshot

- Current phase: **ALL PHASES LANDED** — 12 draft PRs open, all CI green; awaiting merges + v0.1 DoD signoff + `v0.1.0` tag
- Active lanes (2026-10-02):
  - PR 1 `devin/phase0-scaffold` — Phase 0 scaffold + contract freeze (green)
  - PR 2 `devin/wasm-js-core` — WASM binding + `@beyondigital/aiux-core` (green, awaits core merge)
  - PR 3 `devin/phase1-core` — Phase 1 protocol + core + conformance (green, gate met: 22/22 fixtures)
  - PR 4 `devin/phase2-bindings` — Phase 2 UniFFI Swift/Kotlin bindings (green, gate met on CI)
  - PR 6 `devin/phase3-compose` — AIUXCompose + Android example (green 9/9, emulator-verified)
  - PR 7 `devin/phase3-swiftui` — AIUXSwiftUI + iOS example (green 9/9, gate met on macOS CI)
  - PR 8 `devin/phase5-web` — aiux-web renderer + example (green 9/9, fixtures byte-identical via real wasm core)
  - PR 9 `devin/phase7-flutter` — Dart C-ABI + `beyond_aiux` renderer (green 10/10,
    22 fixtures byte-identical via C ABI, app verified on flutter run -d linux)
  - PR 11 `devin/phase4-expo` — Expo SDK 57 bridge + example (green 9/9, emulator-verified)
  - PR 12 `devin/phase8-hardening` — release hardening (green 11/11; benches+1k tests,
    goldens, a11y, §24 docs, release.yml, audits, release-notes automation)
  - Integration branches (orchestrator-maintained): `devin/phase5-web-base`,
    `devin/phase4-expo-base`, `devin/phase6-dsl-base`, `devin/integration`
  - PR 10 `devin/phase6-dsl` — Surface Schema v1→31 nodes (ADR 0007) + renderer
    updates (green 9/9, conformance 27/27, browser-verified)
  - PR 5 `devin/js-adapters` — sse/websocket/ai-sdk adapters + transport helpers (green)

- Branching model: one draft PR per phase, branched off `main` (or off the prior
  open phase branch when it is still unmerged — keep PRs stackable and small).
- Parallel lanes: SwiftUI (PR 4) ∥ Compose (PR 5) after PR 3; Web/WASM lane
  runs parallel to Phase 1 via the frozen `AiuxSession` contract. Expo (PR 6)
  needs PRs 4+5.
- Constraints: Linux dev box — Rust/Kotlin/WASM/Web/Compose verifiable locally;
  Swift compile + iOS verify via macOS CI runners only. UniFFI version is pinned —
  do not bump without compat CI.
- Frozen contracts: `AiuxSession` facade + `ProtocolError`/`DispatchReport`
  signatures (core/rust/session, core/rust/protocol) — never change without an
  ADR; bindings code against them.

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

- [ ] UniFFI (pinned version) — `AIUXSession` object: `dispatch()`,
  `dispatchBatch()`, `snapshot()`, `serialize()`, `restore_session()`
- [ ] Swift bindings + XCFramework/SPM packaging path
- [ ] Kotlin bindings + Android library (AAR) packaging path
- [ ] Binding smoke tests both languages
- **Gate:** Swift + Kotlin example tests can create session → dispatch fixture →
  snapshot → serialize → restore.

## Phase 3 — SwiftUI + Compose MVP → PRs 4 + 5 (parallel lanes)

- [ ] SwiftUI: `AIConversation AIComposer AIMessage AIToolStatus AIApproval
  AIArtifactPreview AISurface AIContextBar` (plan §8)
- [ ] Compose: same component set (plan §9)
- [ ] Fixture catalog both renderers: text, markdown, code, status, tool,
  approval, composer, context chip, surface/card/button
- [ ] Theme contract mapping + light/dark (plan §7)
- [ ] Examples: ios-native app, android-native app
- **Gate:** mocked agent interaction end-to-end on both platforms: user prompt →
  stream → tool start/finish → approval → approve → render result.

## Phase 4 — Expo SDK 57 bridge → PR 6

- [ ] `@beyondigital/aiux-expo` — Expo Modules native view
- [ ] `<AIConversation sessionId theme context capabilities onAction />`
- [ ] iOS: Expo view → SwiftUI hosting → AIUXSwiftUI → core
- [ ] Android: Expo view → ComposeView → AIUXCompose → core
- [ ] JS transport adapter + event buffer + `dispatchBatch` flush policy
  (start 16–50 ms / size threshold, benchmark)
- [ ] examples/expo running the mocked fixture
- **Gate:** same fixture natively on iOS+Android, zero RN message UI.

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
