# Beyondigital AIUX — Implementation Plan

> Source of truth for the AIUX build. This file documents the pasted plan
> verbatim in markdown form. Execution progress is tracked in `TASKS.md`.

## Objective

Build a reusable, framework-independent AI interaction platform that becomes the
default UX foundation for Beyondigital AI applications.

AIUX must not be an Expo, React Native, SwiftUI, Compose, Flutter, or
web-specific chat library.

The architecture is:

```
                    AIUX Protocol
                          │
                     Rust Core
                          │
             AIUX Surface Schema
                          │
       ┌──────────┬───────┼──────────┐
       │          │       │          │
    SwiftUI    Compose    Web      Flutter
       │          │
       └──── Native bridge ────┐
                               │
                       React Native / Expo
```

The same semantics, state transitions, tools, approvals, artifacts, context,
actions, and surface definitions must behave consistently on every renderer.

Each product retains its own visual identity.

---

## 1. Non-negotiable architectural rules

### AIUX is not a chat library

The fundamental abstraction is an AI interaction session composed of typed
parts and events. Chat is one presentation.

The system must support:

- conversational text
- streaming
- markdown/code
- tool execution
- progress
- approval requests
- citations
- files/media
- forms
- structured surfaces
- artifacts
- errors/recovery
- contextual entities
- custom actions

### Rust owns behavior, not application networking

Rust should own:

- state machine
- event reduction
- lifecycle invariants
- ordering
- serialization
- session state
- tool state
- approval state
- artifact state
- validation
- persistence representation

Rust should initially not own:

- authentication
- application API clients
- cookies
- navigation
- analytics
- secure storage
- HTTP/SSE/WebSocket policy

Those remain host responsibilities.

Flow:

```
Host transport
     │
     ▼
AIUXEvent[]
     │
     ▼
 Rust Core
     │
     ▼
AIUXSnapshot
     │
     ▼
 Renderer
```

### Renderers are first-class

Do not attempt to make one renderer pretend to be every platform.

Use:

- Apple → SwiftUI
- Android → Jetpack Compose
- Web → React DOM/web primitives
- Flutter → Flutter widgets

Expo/React Native uses the native renderer on iOS/Android rather than
recreating the UI through Yoga.

### Avoid fine-grained RN/native interleaving

The Expo/RN boundary should normally contain the entire AI surface.

Good:

```
React Native
    ↓
<AIConversation />
    ↓
one native boundary
    ↓
complete SwiftUI/Compose workspace
```

Avoid:

```
RN
↓
SwiftUI
↓
RN
↓
Compose/SwiftUI
↓
RN
```

### AI-generated content cannot execute arbitrary code

AI surfaces communicate through semantic actions.

Example:

```json
{
  "action": {
    "id": "invoice.approve",
    "payload": {
      "invoiceId": "293"
    }
  }
}
```

The host application receives the action and decides whether/how to execute it.

---

## 2. Repository structure

Use a single monorepo.

```
aiux/
├── Cargo.toml
├── package.json
├── pnpm-workspace.yaml
│
├── protocol/
│   ├── schemas/
│   ├── fixtures/
│   ├── versions/
│   └── docs/
│
├── core/
│   └── rust/
│       ├── protocol/
│       ├── reducer/
│       ├── session/
│       ├── tools/
│       ├── approvals/
│       ├── artifacts/
│       ├── surfaces/
│       ├── persistence/
│       └── tests/
│
├── bindings/
│   ├── swift/
│   ├── kotlin/
│   ├── wasm/
│   └── dart/
│
├── renderers/
│   ├── swiftui/
│   ├── compose/
│   ├── web/
│   └── flutter/
│
├── bridges/
│   ├── expo/
│   └── react-native/
│
├── transports/
│   ├── javascript/
│   ├── swift/
│   ├── kotlin/
│   └── dart/
│
├── adapters/
│   ├── ai-sdk/
│   ├── sse/
│   ├── websocket/
│   └── graphql/
│
├── examples/
│   ├── ios-native/
│   ├── android-native/
│   ├── expo/
│   ├── react-native/
│   ├── web/
│   └── flutter/
│
├── conformance/
│   ├── fixtures/
│   ├── expected/
│   └── harness/
│
├── docs/
│   ├── architecture/
│   ├── protocol/
│   ├── renderers/
│   ├── integration/
│   └── adr/
│
└── .github/
    └── workflows/
```

Use:

- Cargo workspace for Rust.
- pnpm workspace for JS/TS.
- Swift Package Manager for Apple renderer.
- Gradle/Maven for Android.
- standard Dart package structure for Flutter.

Do not introduce Turborepo/Nx unless a concrete need emerges.

---

## 3. Protocol v1

Start here before building UI.

Create a versioned AIUX Protocol.

Core entities:

`Session` `Message` `Part` `Event` `Action` `Tool` `Approval` `Artifact`
`Attachment` `Citation` `ContextEntity` `Surface` `Capability` `Error`

Minimum AIUXPart types:

`text` `markdown` `code` `image` `attachment` `citation` `tool` `approval`
`artifact` `status` `progress` `surface` `error`

Minimum lifecycle events:

`session.created` `run.started` `run.cancelled` `run.completed` `run.failed`
`message.created` `message.updated` `part.added` `part.updated` `text.delta`
`tool.started` `tool.progress` `tool.completed` `tool.failed`
`approval.requested` `approval.resolved` `artifact.created` `artifact.updated`
`surface.created` `surface.updated`

Events must have: `eventId` `sessionId` `sequence` `timestamp` `type` `payload`.

Sequence ordering must be deterministic. Duplicate events must be safely
ignored.

---

## 4. Rust core

The Rust API should remain deliberately small.

Conceptual public interface:

```
create_session(config)
restore_session(serialized)
dispatch(event)
dispatch_batch(events)
snapshot()
serialize()
reset()
```

Do not expose every internal implementation detail over FFI.

Core requirements:

- **Deterministic reducer** — given initial state + ordered events, the
  resulting state must always be identical.
- **Idempotency** — replaying the same eventId must not mutate state twice.
- **Out-of-order detection** — sequence problems must either buffer safely, or
  produce an explicit recoverable protocol error. Never silently corrupt state.
- **Serialization** — session state must be serializable for persistence,
  debugging, replay, conformance tests.
- **Batching** — support `dispatch_batch(events)` from day one. Particularly
  important for JS → native streaming so every token does not require an
  independent cross-runtime operation.

---

## 5. Language bindings

### Swift/Kotlin

Use UniFFI for the initial Swift and Kotlin bridge. Keep the UniFFI interface
coarse-grained. Prefer:

```
AIUXSession
dispatch()
dispatchBatch()
snapshot()
serialize()
```

over exposing dozens of internal reducer structures.

Pin the UniFFI version. Do not automatically upgrade it without compatibility
CI because UniFFI is production-used but remains pre-1.0.

### JavaScript/Web

Use a dedicated WASM/JS binding.

Primary consumers:

- `@beyondigital/aiux-core`
- `@beyondigital/aiux-web`

Do not try to route JS through UniFFI.

### Dart

Do not invent a fake UniFFI Dart generator. Implement a narrow C-compatible ABI
around the Rust core and a Dart FFI wrapper. Evaluate bridge-generation tooling
during this phase, but preserve the C ABI boundary even if tooling changes.

---

## 6. AIUX Surface Schema

Implement a constrained semantic UI schema. Do not build another generic UI
framework.

Initial primitives:

`surface` `card` `stack` `row` `grid` `heading` `text` `markdown` `code` `icon`
`image` `badge` `divider` `spacer` `keyValue` `list` `table` `button` `menu`
`progress` `status` `input` `textarea` `select` `checkbox` `actions`

Layout accepts semantic values:

- `gap: xs | sm | md | lg | xl`
- `padding: none | xs | sm | md | lg`
- `radius: sm | md | lg | full`
- `alignment`
- `distribution`

Do not support arbitrary CSS-like positioning. No `position:absolute`,
`left:13px`, `transform…`. The point is semantic portability.

---

## 7. Theme contract

Theme is platform-neutral. Define roles instead of literal component styling.

- **colors**: `background` `surface` `surfaceElevated` `userSurface`
  `assistantSurface` `accent` `accentForeground` `muted` `border` `destructive`
  `success` `warning`
- **typography**: `body` `caption` `label` `heading` `title` `code`
- **spacing** **radius** **motion** **density**

Apps supply the values. Each renderer maps them onto its platform's native
primitives. Dark/light mode must be supported from the first renderer
implementation.

---

## 8. SwiftUI renderer

Create `AIUXSwiftUI`.

Initial supported surfaces: `AIConversation` `AIComposer` `AIMessage`
`AIToolStatus` `AIApproval` `AIArtifactPreview` `AISurface` `AIContextBar`

Use native Apple behavior for keyboard, scrolling, focus, menus, sheets,
file/image selection integration points, accessibility, Dynamic Type,
VoiceOver, reduced motion.

Do not attempt pixel parity with Android. Target semantic and behavioral
parity.

---

## 9. Compose renderer

Create `AIUXCompose`.

Implement equivalent semantic components: `AIConversation` `AIComposer`
`AIMessage` `AIToolStatus` `AIApproval` `AIArtifactPreview` `AISurface`
`AIContextBar`

Use native Compose behavior for LazyColumn, IME handling, bottom sheets, menus,
Material/native interactions, Android accessibility, large font scaling,
predictive back where applicable.

Again: semantic parity, not pixel parity.

---

## 10. Expo bridge

This is the first major end-to-end milestone.

Target Expo SDK 57. Create `@beyondigital/aiux-expo`.

Expo SDK 57 currently maps to React Native 0.86 and React Native Web 0.21.
Use current SDK-57-specific official Expo documentation when implementing
native modules. Do not rely on model memory or SDK 58 APIs.

Bridge through Expo Modules.

Conceptual usage:

```jsx
<AIConversation
  sessionId={session.id}
  theme={theme}
  context={context}
  capabilities={capabilities}
  onAction={handleAction}
/>
```

Native mapping:

- iOS: `JS → Expo native view → SwiftUI hosting → AIUXSwiftUI → Rust Core`
- Android: `JS → Expo native view → ComposeView → AIUXCompose → Rust Core`

JS must configure/control the surface. JS should not perform the native layout.

### Streaming

For a JS-based transport:

```
SSE/WebSocket
      ↓
JS adapter
      ↓
event buffer
      ↓
dispatchBatch()
      ↓
native Rust core
```

Batch small streaming deltas instead of crossing the native boundary per
character/token.

Suggested starting flush policy: 16–50 ms or size threshold. Benchmark before
permanently selecting a value.

---

## 11. Plain React Native bridge

Do this after Expo integration works.

Expose `@beyondigital/aiux-react-native`.

Use a Fabric Native Component / Codegen-compatible interface. Keep its public
JS API aligned with the Expo package.

Where practical, `@beyondigital/aiux` can provide platform exports that route
consumers automatically.

Do not compromise the native architecture purely to make Expo and plain RN
internals identical. Their public APIs should match; their bridge
implementations may differ.

---

## 12. Web renderer

Create `@beyondigital/aiux-web`.

Architecture:

```
JS transport
   ↓
Rust/WASM core
   ↓
React subscription
   ↓
DOM renderer
```

Use browser-native semantics: DOM, ARIA, keyboard navigation, browser
clipboard, drag/drop, file picker, responsive layouts, proper links, selection,
focus management.

Do not render the web experience through React Native Web merely for
theoretical code reuse. Share protocol, state and semantics instead.

---

## 13. Flutter

Implement Flutter after native + Expo + web prove the protocol.

Package: `beyond_aiux`.

Default renderer: `Rust core → Dart FFI → Flutter widgets`.

Do not make embedded SwiftUI/Compose platform views the default Flutter
implementation. Native platform views can exist later as an optional renderer
mode for specific use cases.

---

## 14. Renderer modes

All renderers should eventually support the same presentation concepts:

`fullscreen` `embedded` `sidecar` `sheet` `headless`

Do not implement every mode immediately.

v0.1 should include: `fullscreen` `embedded`. Desktop/web can add `sidecar`
next.

---

## 15. MVP scope

### AIUX v0.1 must contain:

- Protocol v1
- Rust reducer/core
- Swift binding
- Kotlin binding
- SwiftUI renderer
- Compose renderer
- Expo SDK 57 bridge
- text, markdown, code
- streaming
- tool lifecycle
- approval lifecycle
- status/progress
- attachments representation
- context entities
- initial Surface Schema
- semantic theming
- light/dark
- fixture/conformance infrastructure
- example iOS app
- example Android app
- example Expo app
- GitHub CI
- tagged internal release

### Not required for v0.1:

- Flutter
- full web artifact workspace
- voice
- video
- complex charts
- 100 DSL components
- native networking stack
- model/provider-specific SDKs
- fully public package registry releases

Keep scope disciplined.

---

## 16. Implementation phases

### Phase 0 — Repository + engineering foundation

Deliver: monorepo, Cargo workspace, pnpm workspace, formatters, linters, basic
CI, ADR structure, release versioning, CODEOWNERS, examples folders.

Create ADRs for: Rust as canonical state engine, renderer architecture,
protocol versioning, transport ownership, FFI strategy, Surface Schema
philosophy.

**Gate:** Every empty/example target builds on CI.

### Phase 1 — Protocol + Rust core

Deliver: Protocol v1 schemas, Rust models, event reducer, session state, tool
lifecycle, approval lifecycle, artifact lifecycle, serialization, idempotency,
batch dispatch, fixture runner.

**Gate:** The same event fixture always produces the exact expected serialized
state. No UI begins before this gate passes.

### Phase 2 — Native bindings

Deliver: Swift UniFFI binding, Kotlin UniFFI binding, XCFramework/SPM packaging
path, Android library packaging path, binding smoke tests.

**Gate:** Both Swift and Kotlin example tests can create session, dispatch
fixture, read resulting snapshot, serialize session, restore session.

### Phase 3 — SwiftUI + Compose MVP

Implement the same fixture catalog in both renderers. Start with: text,
markdown, code, status, tool, approval, composer, context chip,
surface/card/button.

**Gate:** A native iOS app and Android app can run a complete mocked agent
interaction: user prompt → stream response → start tool → finish tool → request
approval → approve → render result.

### Phase 4 — Expo integration

Create SDK-57 example. Implement: native view, props, events, actions, theme,
context, transport adapter, stream batching.

**Gate:** Expo app runs the same mocked fixture natively on iOS and Android
without rebuilding message UI in React Native. This is the first major product
milestone — usable by existing Beyondigital Expo products.

### Phase 5 — Web

Build: Rust/WASM integration, React DOM renderer, responsive fullscreen,
embedded mode, keyboard/focus behavior, web adapter.

**Gate:** Same protocol fixture runs through native iOS, Android, Expo and web.

### Phase 6 — Surface DSL + artifacts expansion

Expand the semantic UI model. Add: forms, tables, key/value, lists, artifact
preview, artifact workspace contract, actions, validation, custom node
registration contract.

**Gate:** One structured tool result renders semantically across every
completed renderer from the exact same Surface payload.

### Phase 7 — Flutter

Implement: Dart FFI, Flutter state wrapper, Flutter renderer, Flutter fixture
app.

**Gate:** Same conformance scenario passes in Flutter without native
platform-view dependency.

### Phase 8 — Production/release hardening

Add: performance benchmarks, large conversation tests, accessibility checks,
golden/screenshot tests, compatibility matrix, migration docs, package docs,
release notes automation, dependency audit. Then cut 1.0.

---

## 17. Conformance system

This is mandatory. Create canonical fixtures for:

basic response, streaming response, markdown/code, tool started, tool progress,
tool success, tool failure, approval requested, approval rejected, approval
accepted, artifact update, attachment, citation, context injection, retry,
cancel, network reconnect, duplicate events, out-of-order events, large
history, dark mode, large accessibility text, RTL, reduced motion.

Each renderer consumes the same semantic fixtures.

Assertions are split into:

- **STATE CONFORMANCE** — exact
- **BEHAVIOR CONFORMANCE** — equivalent
- **VISUAL CONFORMANCE** — semantic, not pixel-identical

A Compose button should look Android-native. A SwiftUI button should look
Apple-native. Both must represent the same semantic action.

---

## 18. Testing strategy

- **Rust**: unit tests, property tests, reducer replay tests, serialization
  tests, protocol compatibility tests
- **Native**: Swift tests, Kotlin tests, renderer component tests,
  accessibility checks
- **Integration**: example app compile, fixture playback, action round-trip,
  bridge serialization
- **Web**: component tests, Playwright, keyboard/focus tests, responsive tests
- **Later**: golden/screenshot regression, performance benchmarks

---

## 19. GitHub CI

Every PR: protocol validation, cargo fmt, cargo clippy, cargo test, Swift
binding generation, Swift tests, Kotlin binding generation, Kotlin tests, JS
typecheck/test, web build, Expo Android compile, Expo iOS compile, fixture
conformance.

Use platform runners intelligently:

- Ubuntu → Rust, Android, JS/web
- macOS → Swift/iOS, Apple XCFramework

**Hard guardrails:** Every workflow needs `timeout-minutes`, a concurrency
group, and `cancel-in-progress: true`. No CI job may run indefinitely. Release
builds may get larger limits than PR checks, but every job still receives a
hard timeout.

---

## 20. Release pipeline

Trigger: `v0.x.y` / `v1.x.y` tag.

Pipeline:

```
validate tag → full conformance suite → build Rust targets →
generate bindings → build XCFramework → build Android artifact →
build WASM/JS → build JS packages → generate checksums →
GitHub Release → package registry publishing
```

For internal v0.x releases, prioritize GitHub Releases + GitHub Packages before
adding unnecessary public-registry complexity.

Potential artifacts: `@beyondigital/aiux` `@beyondigital/aiux-core`
`@beyondigital/aiux-expo` `@beyondigital/aiux-react-native`
`@beyondigital/aiux-web` `BeyondAIUX` Swift Package
`in.beyondigital.aiux:core` `in.beyondigital.aiux:compose` `beyond_aiux`.

All official artifacts for a release must derive from the same Git tag/commit.

---

## 21. Compatibility/version policy

Initially keep one release train, e.g. AIUX Protocol 0.4 / Rust Core 0.4 /
SwiftUI 0.4 / Compose 0.4 / Expo 0.4 / Web 0.4.

Do not independently version every package until there is a real need.

Protocol payloads must contain `protocolVersion`. Renderers declare supported
ranges. Unknown optional fields should not break old renderers. Unknown
required semantics must result in an explicit compatibility error.

---

## 22. Performance principles

Avoid: one FFI call per character, JS-driven native layout, full conversation
rerender per delta, unbounded in-memory histories, JSON encode/decode chains
across five layers.

Prefer: event batches, stable IDs, incremental state, virtualized histories,
native renderer state observation, coarse host/native interfaces, lazy artifact
rendering, paginated history.

Create benchmarks early for: first render, 1,000-message restore, stream
throughput, 100 events/batch, surface rendering, memory after long
conversations.

Performance regression thresholds can later become CI gates.

---

## 23. Security rules

AI-generated Surface payloads are data, never executable source code.

No: eval, dynamic JS, remote Swift/Kotlin code, arbitrary HTML, arbitrary
navigation URLs without host validation.

All actions travel through `AIUXAction → host policy → application handler`.

Approval UI must clearly distinguish: requested, approved, rejected, expired,
already executed. Never permit duplicate execution merely because an event was
replayed.

---

## 24. Documentation required before v0.1

Create: Architecture Overview, Protocol Specification, Event Lifecycle,
Surface Schema, Theme Contract, SwiftUI Integration, Compose Integration,
Expo SDK 57 Integration, Transport Adapter Guide, Custom Tool UI Guide,
CI / Release Guide, Compatibility Policy.

Every example app should demonstrate the same fake assistant scenario.

---

## 25. PR strategy

Do not build this on one huge branch. Recommended progression:

| PR  | Contents |
|-----|----------|
| 1   | Scaffold + CI + ADRs |
| 2   | Protocol + Rust core |
| 3   | Swift/Kotlin bindings |
| 4   | SwiftUI renderer |
| 5   | Compose renderer |
| 6   | Expo SDK 57 integration |
| 7   | Web/WASM renderer |
| 8   | Surface DSL expansion + artifacts |
| 9   | Flutter |
| 10  | Release hardening |

Dependencies may allow SwiftUI and Compose PRs to proceed in parallel after
PR 3.

Do not let later renderer work redefine Protocol v1 ad hoc. Protocol changes
require explicit schema/ADR review.

---

## 26. v0.1 Definition of Done

v0.1 is complete when one Expo application can install AIUX and render:

```jsx
<AIConversation
  sessionId={sessionId}
  theme={theme}
  context={context}
  onAction={handleAction}
/>
```

and receive SwiftUI on iOS and Compose on Android — while the same
protocol/core also works inside standalone native iOS and Android examples.

The demonstration conversation must include: streaming answer, markdown/code,
tool execution, progress, approval, structured result surface, context entity,
error + retry, light/dark mode.

No application-specific AI chat implementation should be required.

That is the first point where the library should be adopted by a real
Beyondigital application.
