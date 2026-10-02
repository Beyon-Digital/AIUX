# ADR 0005: FFI strategy — UniFFI, WASM, and a narrow C ABI

- Status: Accepted
- Date: 2026-10-02

## Context

The Rust core must be callable from Swift, Kotlin, JS, and Dart. Each target
has different FFI ergonomics; the wrong tool per platform produces either
fragile glue or unmaintainable generated code.

## Decision

- **Swift + Kotlin: UniFFI.** Pinned version, coarse-grained interface
  (`AIUXSession` with `dispatch`, `dispatchBatch`, `snapshot`, `serialize`),
  no dozens of exposed internal types. UniFFI is pre-1.0 — upgrades require
  compatibility CI, never automatic bumps.
- **JS/Web: dedicated WASM/JS binding** (`aiux-wasm`), consumed by
  `@beyondigital/aiux-core` and `@beyondigital/aiux-web`. JS is never routed
  through UniFFI.
- **Dart: narrow C-compatible ABI** + a Dart FFI wrapper. No fake UniFFI Dart
  generator. Bridge-generation tooling may be evaluated, but the C ABI is the
  stable boundary regardless of tooling.
- All boundaries batch events (`dispatch_batch`) — streaming deltas never
  cross FFI per token.

## Consequences

- Three maintained boundary surfaces, each idiomatic to its consumer.
- Coarse interfaces keep FFI call overhead and codegen churn bounded.
