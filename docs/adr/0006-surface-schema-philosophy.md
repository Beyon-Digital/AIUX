# ADR 0006: Surface Schema is semantic, not stylistic

- Status: Accepted
- Date: 2026-10-02

## Context

AI-generated UI must render on every platform without shipping executable
code or platform-specific styling. A generic UI DSL invites CSS-like
positioning that breaks semantic portability and security.

## Decision

A constrained semantic schema with a fixed primitive set (surface, card,
stack, row, grid, heading, text, markdown, code, icon, image, badge, divider,
spacer, keyValue, list, table, button, menu, progress, status, input,
textarea, select, checkbox, actions) and semantic layout values
(`gap: xs..xl`, `padding: none..lg`, `radius: sm..full`, alignment,
distribution).

Explicitly excluded: arbitrary positioning (`position:absolute`, pixel
offsets, transforms), arbitrary HTML, eval, and remote code. AI surfaces
communicate via semantic `AIUXAction`s resolved by host policy — payloads are
data, never source code.

## Consequences

- Same payload renders natively everywhere; conformance is semantic.
- Apps keep visual identity through the theme contract, not per-node styling.
- Extending the schema is a deliberate, versioned protocol change.
