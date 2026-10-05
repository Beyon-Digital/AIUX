# Testing & fixtures

Three layers, cheapest first: **conformance fixtures** (no UI), **store
tests** (UI state, no pixels), **example-app drives** (full stack).

## Conformance fixtures — `conformance/`

28 canonical event streams (`conformance/fixtures/*.json`) with expected
snapshots (`conformance/expected/`) — every renderer must satisfy them.
Each fixture is `{name, protocolVersion?, events}`:

- approvals (requested/accepted/rejected), artifacts, attachments,
  cancel, citations, context-injection, basic-response, surfaces, errors …
- Replay: dispatch all events → compare `snapshot()` to the expected file.
- Manifest/loading helpers exist per renderer: `AIUXFixtureCatalog` (Swift),
  `AIUXFixture`+`FixtureHarness` (Compose test-side), and the JS test
  loaders under `renderers/web/test/`.

Use them to guard your *producer*: if your backend emits events, replay your
own transcripts through a session and assert the snapshot.

## JS — `MockCore` + `EventBuffer`

```ts
import {MockCore, AiuxSession, EventBuffer} from "@beyond-digital/aiux-core";

const core = new MockCore();              // contract-shaped, in-memory
const session = AiuxSession.create(core, {protocolVersion: "0.1", sessionId: "s1"});

session.dispatchBatch('[{"type":"run.started",…}]');
core.calls.dispatchBatch;                 // → 1  (also create/restore/snapshot/…, freeSession)
```

- `MockCore` records call **counts** per method — assert dispatch batching
  happened (`calls.dispatchBatch === 1`) instead of per-token calls.
- `EventBuffer` coalesces dispatches on a timer — test flush behavior with
  fake timers (policy: `flushIntervalMs` 16–50, `maxEvents` 64, `maxBytes`
  64 KiB; `onFlushError` fires for timer-triggered flush failures only).
- `AiuxSessionOptions.onListenerError` — subscribe-listener exceptions are
  funneled there, not thrown.

## Web — vitest + happy-dom

`renderers/web/test/conformance.test.ts` replays all fixtures through the
React renderer. Leaf components take plain props — render `AIApproval`,
`AIToolStatus`, `AISurface` directly in unit tests without a session.

## Swift — XCTest + `AIFixturePlayer`

- `renderers/swiftui/Tests/` — store ingest, model decode, surface nodes.
- `AIFixturePlayer(directory:)` — interactive picker that replays fixtures
  into a live store (drop it in a debug menu).
- Headless: `swift run AIUXExample` (in `examples/ios-native`) replays the
  catalog and exits non-zero on divergence — CI gate.

## Compose — JUnit + `FixtureHarness`

- `renderers/compose/src/test/` — `SessionStoreTest` (StateFlow emission),
  `SnapshotMappingTest`, `SurfaceNodeTest`, `MarkdownParserTest`.
- `FixtureHarness` replays fixtures through a real UniFFI `AiuxSession`
  loaded via JNA (host `.so` from `bindings/kotlin/generate.sh`).

## Expo — vitest

`bridges/expo/test/` — transport queue semantics (permanent vs transient
rejects, head-of-line retries), session helpers.

## Repo-wide commands

```bash
pnpm test                    # all JS packages (vitest)
pnpm --filter @beyond-digital/aiux-web test
cargo test                   # Rust core + bindings
swift test                   # in renderers/swiftui (or the SwiftPM workspace)
cd renderers/compose && ./gradlew test
cd bridges/expo && pnpm test
```

## Driving the example end-to-end

`examples/expo` (dev-client) is the full-stack smoke test: scripted mock
stream (no network) or live OpenRouter (`EXPO_PUBLIC_OPEN_ROUTER`,
model `openrouter/free`). See
[`examples/expo/README.md`](../../examples/expo/README.md) — and the
live captures in [the docs index](../README.md#live-demo).
