# ADR 0002: First-class native renderers

- Status: Accepted
- Date: 2026-10-02

## Context

Each platform has native interaction vocabulary (keyboard, scrolling, menus,
sheets, IME, accessibility) that a shared UI toolkit cannot faithfully
reproduce. Parity must be semantic and behavioral, not pixel-identical.

## Decision

One renderer per platform, each a first-class citizen:

- Apple → SwiftUI (`AIUXSwiftUI`)
- Android → Jetpack Compose (`AIUXCompose`)
- Web → React DOM primitives (`@beyond-digital/aiux-web`)
- Flutter → Flutter widgets (`beyond_aiux`)

Expo/React Native mounts the platform's native renderer behind a single
coarse boundary (`<AIConversation/>`); no fine-grained RN/native
interleaving. The web renderer does not run through React Native Web — we
share protocol, state, and semantics, not widgets.

## Consequences

- Each renderer maps the same Surface Schema + theme roles onto native
  primitives; visual identity stays per-product.
- Conformance asserts state (exact), behavior (equivalent), and visuals
  (semantic) rather than pixels.
- N renderer implementations to maintain; mitigated by the thin-renderer
  rule and shared fixtures.
