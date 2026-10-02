# Compatibility Policy

§21 codified for v0.1+.

## One release train

All AIUX packages version together: protocol `0.1`, rust crates `0.1.0`,
JS packages `0.1.0`, Swift/Kotlin/Dart `0.1.0`. No independent per-package
versioning until a real need exists — a release means one tag
(`v0.1.0`) → every artifact from that commit.

## Protocol versions

- Wire: every payload carries `protocolVersion` (`"0.1"`). The core
  rejects unsupported versions with `ProtocolError.Unsupported` at
  dispatch/restore — never silent downgrade.
- **Additive tolerance (required)**: readers MUST tolerate unknown
  optional fields — schemas are `additionalProperties: true`, the surface
  sanitizer strips unknown node fields rather than failing, unknown
  *required* semantics (new event type, new required concept) fail
  explicitly with `unsupported`.
- **Renderer declarations**: each renderer exposes its target
  (`AIUXSwiftUI.protocolVersion`, `aiuxProtocolVersion` in Dart, etc.) —
  a host mixing a `0.2` producer with a `0.1` renderer is a supported
  configuration *only* for additive changes; anything else surfaces the
  `unsupported` error path.

## What counts as breaking (needs `0.2`+ / bump)

- Removing or renaming an event type, entity field, surface node kind, or
  enum value; changing a field's type or making optional required.
- Changing reducer semantics so an identical event stream produces
  different state (other than a documented bug fix).
- Changing `serialize()`'s envelope so `restore()` of a `0.1` envelope
  fails — persistence compatibility is part of the contract.

## What is allowed within `0.1.x`

- New optional fields anywhere (`additionalProperties` model).
- New surface node **fields** on existing kinds (sanitized by old builds).
- New `custom` node `kind` values (hosts simply render the fallback until
  they register it).
- Bug fixes; performance work; new conformance fixtures.
- New event types only when every supported consumer treats unknown types
  as `unsupported` (they do) — i.e. safe to *emit* only behind a
  capability/`protocolVersion` bump.

## Deprecation & migration

Breaking changes ship behind a new protocol version + migration doc
(`docs/integration/migration.md`) covering: wire diffs, `serialize()`
envelope upgrade path, and renderer mapping changes. `0.x` line: minor
bumps may break; `1.0`+ follows semver.

## Bindings

UniFFI is pinned (`=0.29.5`) and `wasm-bindgen-cli` must match Cargo.lock
— cross-boundary ABI drift is a build failure by design, not a runtime
risk.
