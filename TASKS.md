# AIUX — Execution Tracker

Progress ledger for the multi-session build of `docs/PLAN.md`. **Update rules:**
whoever does the work edits the row in the same PR — mark `[x]` with the PR link,
or `[~]` plus a note when partially landed. New session? Read `docs/PLAN.md`
first, then this file; pick the lowest-numbered unblocked phase.

Legend: `[ ]` todo · `[~]` in progress · `[x]` done · `(_)` blocked/skipped (note why)

## Status snapshot

- Current phase: **COMPLETE** — all 12 PRs merged to `main` (2026-10-02);
  `v0.1.0` tag pending DoD signoff (plan §26).
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
- [x] Theme contract mapping + light/dark (plan §7)
  - [x] SwiftUI: `AIUXTheme` roles (colors/typography/spacing/radius/motion/
    density), light + dark via `AIUXColor`
  - [x] Compose: `AIUXTheme` §7 roles → Material3, light + dark
- [x] Examples: ios-native app, android-native app
  - [x] ios-native: real app over UniFFI (conversation + fixture gallery +
    agent log), headless `swift run AIUXExample` scenario gate
  - [x] android-native: mocked agent script + fixture browser (emulator-verified)
- **Gate:** mocked agent interaction end-to-end on both platforms: user prompt →
  stream → tool start/finish → approval → approve → render result.
  - [x] iOS (`AIUXExample` scenario + XCTest, verified on macOS CI)
  - [x] Android (mocked agent script verified on `vendor_v3` emulator)

## Phase 4 — Expo SDK 57 bridge → PR 6

- [x] `@beyond-digital/aiux-expo` — Expo Modules native view
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

- [x] `aiux-wasm` — wasm-bindgen surface over core (`scripts/build-wasm.mjs`
      → `bindings/wasm/pkg/` → vendored as aiux-core `./wasm` export)
- [x] `@beyond-digital/aiux-core` (JS session wrapper + subscriptions)
- [x] `@beyond-digital/aiux-web` React DOM renderer (fullscreen + embedded modes)
      — `AIConversation`, all 13 part types, all 26 surface primitives, ARIA
      + keyboard/feed pattern, theme roles → scoped CSS vars (light/dark)
- [x] Web adapter + examples/web fixture playback — `createEventDriver`
      (EventBuffer → dispatchBatch); Vite app replays every fixture with a
      live `serialize() === expected` conformance badge
- **Gate:** same protocol fixture runs through iOS, Android, Expo and web.
      Web side verified: `renderers/web/test/conformance.test.ts` replays all
      21 fixtures through the real wasm core — byte-identical serialize().

## Phase 6 — Surface DSL + artifacts expansion → PR 8

- [x] forms, tables, keyValue, lists
- [x] artifact preview + artifact workspace contract
- [x] actions + validation
- [x] custom node registration contract
- **Gate:** one structured tool result renders semantically on every completed
  renderer from the same Surface payload.

## Phase 7 — Flutter → PR 9

- [x] narrow C ABI over Rust core (`aiux-capi` staticlib/cdylib —
  `bindings/dart/capi`, opaque handle + JSON strings + explicit free fns)
- [x] Dart FFI wrapper (`aiux_ffi` — `bindings/dart`; handwritten `dart:ffi`
  per ADR 0005, decision documented in `bindings/dart/README.md`)
- [x] Flutter renderer + fixture app (`beyond_aiux` — `renderers/flutter`;
  `examples/flutter` mocked-agent demo + fixture gallery)
- **Gate:** conformance scenario passes without platform-view dependency —
  all 22 fixtures replay through the C ABI byte-identical to
  `conformance/expected/` (`bindings/dart` `dart test`); widget tests render
  via the real FFI backend (`renderers/flutter` `flutter test`).

## Phase 8 — Production/release hardening → PR 12

- [x] benchmarks (first render, 1k-msg restore, stream throughput, 100-ev
  batch, surface render, memory) — `benches/` + checked-in `BASELINE.md`
- [x] large conversation tests + accessibility checks + golden tests —
  `core/rust/tests/tests/large_conversation.rs` (1k msgs, idempotent replay,
  reversed chunks, 5k deltas); `docs/renderers/accessibility.md` checklists
  (manual cells open for DoD pass); web DOM goldens in CI, Flutter goldens
  as `flutter-goldens` artifact job
- [x] compatibility matrix + migration docs + package docs —
  `docs/integration/compatibility-matrix.md`, `migration.md`,
  `compatibility-policy.md`, full §24 doc set under `docs/`
- [x] release notes automation + dependency audit — `tools/release-notes.mjs`
  + `docs/integration/dependency-audit.md` (cargo clean; pnpm 4 fixed,
  2 documented Expo transitives; gradle inventory + OWASP path noted)
- [ ] tag `v0.1.0` internal release via `release.yml` — orchestrator cuts
  after this PR merges + v0.1 DoD signoff (not part of PR 12)
- [x] `release.yml` real pipeline bodies (bindings gen, XCFramework, AARs,
  wasm, JS package builds, checksums, draft GitHub Release)
- **Gate:** v0.1 DoD (plan §26) — one Expo app installs AIUX, renders
  `<AIConversation/>`, demo conversation covers streaming/markdown/code/
  tool/progress/approval/surface/context/error+retry/light+dark.

## Parking lot (explicitly out of v0.1 per plan §15)

Flutter, full web artifact workspace, voice, video, complex charts, 100 DSL
components, native networking stack, provider SDKs, public registry publishing.

## OSS installable release amendment (0.1.1)

- [x] Owner approved MIT and npm scope `@beyond-digital`.
- [x] Compiled JS exports, ESM import resolution and package allowlist; scaffold
  GraphQL and plain RN remain private.
- [x] Executable metadata/tarball gates and isolated consumer validation scripts.
- [x] Native distribution assembly and npm trusted-publishing workflow prepared.
- [ ] Exact candidate commit passes all CI + distribution consumer builds.
- [ ] Manual native accessibility/device sign-off (see renderer checklist).
- [ ] npm account authenticated / trusted publishers configured.
- [ ] Reviewed PR merged, immutable 0.1.1 tag built, registry packages published
  and independently installed; GitHub release published.
- [ ] pub.dev/crates.io registry releases and mobile Flutter native payloads.

## Docs expansion + live captures (Oct 2026 session)

- [x] docs/README.md documentation hub — index over install → quickstart →
  per-package API → guides → ops + live-capture media table
- [x] docs/api/ — source-verified per-package references:
  session-contract, js-core, web, expo, swiftui, compose, flutter,
  transports-adapters
- [x] docs/guides/ — dispatch-semantics, actions, theming, composer-toolbar,
  surfaces, persistence, connecting-a-model, testing
- [x] docs/troubleshooting.md — dispatch/web/expo/native/sim failure atlas
- [x] getting-started/quickstart.md — per-platform end-to-end quickstarts
- [x] docs/assets/ screenshots + videos captured live on iOS sim +
  Android emulator — iOS captures done (conversation,
  approval, surface, error-retry, dark + full-flow video); Android
  captures done on KVM-enabled Linux box (same 5 frames + demo video)
