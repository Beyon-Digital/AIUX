# ADR 0004: Transport ownership stays with the host

- Status: Accepted
- Date: 2026-10-02

## Context

Networking policy varies per product: auth, cookies, TLS pinning, proxies,
retry/backoff, analytics, and secure storage are app concerns with existing
implementations.

## Decision

Rust core does not own authentication, API clients, cookies, navigation,
analytics, secure storage, or HTTP/SSE/WebSocket policy. Hosts own transport
and emit normalized `AIUXEvent[]` into the core.

Per-language transport helpers (`transports/{javascript,swift,kotlin,dart}`)
and wire adapters (`adapters/{ai-sdk,sse,websocket,graphql}`) live in the
monorepo as reusable conveniences, but remain host-side code — outside the
Rust core's trust boundary.

## Consequences

- Apps keep their network stacks; AIUX integrates without re-platforming.
- Transport bugs stay out of the deterministic core.
- Adapters become the compatibility surface to test (bridge serialization,
  action round-trip).
