# ADR 0001: Rust as the canonical state engine

- Status: Accepted
- Date: 2026-10-02

## Context

AIUX must behave identically across SwiftUI, Compose, Web, Flutter, and the
Expo/RN bridge. Implementing session state, ordering, idempotency, and
lifecycle rules per platform guarantees drift.

## Decision

A single Rust core owns all behavior: state machine, event reduction,
lifecycle invariants, ordering, serialization, session/tool/approval/artifact
state, validation, and the persistence representation. Hosts feed it
`AIUXEvent[]` and render the `AIUXSnapshot` it produces.

The public API stays deliberately small: `create_session`,
`restore_session`, `dispatch`, `dispatch_batch`, `snapshot`, `serialize`,
`reset`. Internal reducer structures are not exposed over FFI.

## Consequences

- One implementation to verify; renderers can be thin and dumb.
- Deterministic replay makes conformance testing exact.
- FFI boundary must stay coarse to keep cross-runtime overhead low.
- Rust expertise is required on the critical path of every platform.
