# ADR 0003: Protocol versioning policy

- Status: Accepted
- Date: 2026-10-02

## Context

Multiple packages (core, renderers, bridges, transports) ship to different
ecosystems and will drift out of sync. Events and payloads cross version
boundaries at runtime.

## Decision

- Protocol v1 schemas are versioned under `protocol/versions/` and
  `protocol/schemas/v1/`. Every payload carries `protocolVersion`.
- One release train: Protocol, Rust core, and all renderers release under the
  same version (e.g. 0.4). No independent package versioning until a real
  need exists.
- Renderers declare supported protocol ranges. Unknown optional fields must
  not break old renderers; unknown required semantics must produce an
  explicit compatibility error, never silent misbehavior.
- Later renderer work must not redefine Protocol v1 ad hoc — changes go
  through schema + ADR review.

## Consequences

- Forward-compatible additive changes are cheap; breaking changes are loud.
- A single version line simplifies support and release automation.
