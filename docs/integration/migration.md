# Migration Guide

There is no earlier AIUX release — this guide covers (a) moving an app
**onto** AIUX 0.1, and (b) the shape future `0.1 → 0.2` migrations will take.

## Migrating to AIUX 0.1

### From a hand-rolled chat UI

1. **Model your stream as events.** Map your backend's stream onto the 20
   event types (`docs/protocol/specification.md`): assistant tokens →
   `text.delta`; tool calls → `tool.*`; human-in-loop → `approval.*`;
   rich UI → `surface.*`. Give every event a stable `eventId` +
   session-monotonic `sequence`.
2. **Pick the boundary.** JS/TS host → `@beyondigital/aiux-core` (wasm) or
   the adapters in `adapters/*`; native host → the language binding +
   `dispatchBatch`.
3. **Mount the renderer.** `AIConversation` in your platform's idiom
   (integration guides in this directory). Supply theme + `onAction`.
4. **Route actions.** Everything interactive emits `AIUXAction {id,
   payload}` — wire to your existing handlers; delete the old rendering
   code path behind a flag.
5. **Persistence** (optional): store `serialize()` output alongside the
   conversation; `restore()` resumes exactly — including dedup state.

### From Vercel AI SDK

`adapters/ai-sdk` maps stream parts → AIUX events (`mapAiSdkPart` /
`createAiSdkAdapter`) — see `docs/integration/transport-adapters.md`.

### Composer submit → events

Host-synthesized events (user message send, retry, cancel) go through
`createEventFactory` (JS) which mints `eventId`/`sequence`/`timestamp` in
the session's monotonic space — never hand-number sequences on the host.

## Future protocol migrations (policy)

When a `0.2` exists, this file gains per-version sections covering:

- **Wire diffs** — added/removed/changed event types, fields, node kinds.
- **Envelope upgrade** — `restore()` of `0.1` envelopes: either supported
  in-place (additive) or an explicit `tools/` upgrade command that rewrites
  `state`/`seenEventIds`/`bufferedEvents` to the new shape. Breaking
  envelope changes always ship a converter (§21).
- **Renderer mapping** — theme role or node-kind renames and their
  deprecation window.
- **Capability gating** — how a mixed `0.1`/`0.2` fleet degrades:
  unknown-but-optional stays silent, unknown-required → `unsupported`.

Rule of thumb: producers and renderers may skew **within additive scope**;
anything structural is a coordinated version bump, documented here before
the tag is cut.
