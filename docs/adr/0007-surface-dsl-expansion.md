# ADR 0007: Surface DSL expansion — forms, structured tables, list items, custom nodes, artifact workspace

- Status: Accepted
- Date: 2026-10-02
- Amends: ADR 0006 (surface schema philosophy)

## Context

Phase 6 needs AI-generated surfaces to express structured tool results and
interactive data collection without leaving the semantic model: forms with
validation states, typed table cells, templated list rows, an artifact
preview/workspace contract, and a host-managed extension point — all while
keeping payloads declarative data (§23).

## Decision

All extensions are **additive inside Protocol v1** (`protocolVersion` stays
`0.1`; §21 — unknown required semantics remain an explicit compatibility
error: cores that don't know a node type reject it at dispatch, and `custom`
is the forward-compat path).

### New node types

- `form { children, submit, submitLabel?, disabled? }` — an interactive form.
  Named field descendants (`input`/`textarea`/`select`/`checkbox`/`radio`)
  contribute their current value to the nearest enclosing `form`, or to the
  surface when no form encloses them (existing behavior). Activating the
  submit affordance emits `submit` (an `AIUXAction`) with the collected
  `fields` object merged into its payload. Forms may not nest.
- `field { children, label?, helperText?, required?, errorText?, disabled? }` —
  a labelled field group: one label/hint/error for the control(s) inside.
- `radio { name, label?, options, value?, required?, disabled?, errorText? }` —
  a single-choice group rendered as radios (same option model as `select`).
- `listItem { title, subtitle?, icon?, action?, children? }` — a structured
  list row; only valid as a direct child of `list`. `action` makes the row
  itself activatable; `children` nest further content.
- `custom { kind, props?, children? }` — the host-managed extension point
  (registration contract below).

### Refinements to existing nodes

- `table`: gains `columns: [{ key, title, align? }]` (`align:
  start|center|end`, semantic) and typed cells — `rows` entries may be bare
  strings (text cells, backward compatible) or `{ "type": "text" | "number" |
  "badge" | "action", ... }` objects. `headers` is now optional; `headers` or
  `columns` (non-empty) is required, and when both are present their lengths
  must agree. Rows still must match the effective column count.
- `keyValue` items gain optional `tone`.
- `badge` gains optional `icon`.
- All surface-node wire keys are camelCase (`inputType`, `errorText`,
  `helperText`, `submitLabel`). The pre-existing `input_type` wire key was
  unreachable — `validate_raw` only ever allowed `inputType` — so this ADR
  normalizes the serialized form (`#[serde(rename)]` per field) rather than
  changing the contract.
- `input`, `textarea`, `select`, `checkbox`, `radio` gain `errorText`;
  `required` now exists on all field nodes (a required `checkbox` must be
  checked before submission — renderer-enforced display semantics; `errorText`
  is author-provided, renderers display it, hosts own validation outcomes).

### Artifact model expansion

`Artifact` gains two optional fields (also patchable via `artifact.updated`):

- `preview { summary?, surface? }` — what an artifact card shows inline:
  a short text summary and/or an inline surface descriptor.
- `workspace { mode?, surface?, lazy? }` — the contract a host honors when
  the user opens an artifact: `mode: fullscreen | detail | sheet` (default
  fullscreen), an optional detail surface descriptor, and `lazy` — a hint
  that the renderer may defer mounting the workspace until it is visible.

An *inline surface descriptor* is `{ id, root }`: a self-contained semantic
node tree carried inside the artifact (not a session surface; `root` must be
a `surface` node and is validated exactly like `surface.created` roots).

### Custom node registration contract

Hosts register `kind → renderer` out of band (a prop/environment registry —
each renderer exposes one). `kind` is a host-namespaced identifier
(e.g. `acme.sparkline`); the `aiux.*` prefix is reserved for built-ins.
`props` is free-form data — never code, never eval'd. A `custom` node whose
`kind` has no registered renderer degrades to the same placeholder as any
unknown node (plan §21), so an older or minimal host never crashes on a
newer payload.

## Consequences

- Structured tool results (forms, tables, lists, artifacts) render
  semantically on every completed renderer from one payload — the Phase 6
  gate.
- The schema stays closed: `validate_raw` still rejects keys/types outside
  the schema; `custom.props` is the only sanctioned escape hatch and it is
  data-only.
- Old fixtures are untouched — every change is additive or relaxes a
  previously-required field (`table.headers`), so existing payloads still
  validate and serialize identically.
- Renderer parity for a new node is additive per renderer (one case → one
  view); a renderer that has not landed a node yet falls back cleanly.
