# AIUX Surface Schema v1

Surfaces are **data, never code** (§23): a closed set of layout primitives an
agent uses to render structured UI — cards, tables, forms, status boards —
without shipping executable markup. Normative schema:
`protocol/schemas/v1/surface.json`; validator: `core/rust/surfaces`.

## Document shape

```json
{
  "id": "invoice",
  "name": "Invoice summary",
  "revision": 1,
  "root": { "type": "surface", "children": [ /* nodes */ ] }
}
```

- `root.type` must be `surface` — the root container only.
- `revision` increments on every `surface.updated`; stale revisions are
  rejected (`invalidEvent`).
- The validator caps a tree at **4096 nodes** and rejects unknown node
  types (`webview`, arbitrary HTML, scripts) — there is no escape hatch
  other than the deliberate `custom` node.

## The 29 node kinds (closed set)

| Group | Kinds |
|-------|-------|
| Containers | `surface` (root only), `card`, `stack` (v/h), `row`, `grid`, `list`, `listItem`, `actions`, `form`, `field` |
| Content | `heading`, `text`, `markdown`, `code`, `icon`, `image`, `badge`, `divider`, `spacer`, `keyValue`, `table`, `status`, `progress` |
| Interactive | `button`, `menu`, `input`, `textarea`, `select`, `checkbox`, `radio` |
| Escape hatch | `custom` — opaque `{name, props}` the host renderer may map to a registered component (see `docs/integration/custom-tool-ui.md`); hosts that don't register a name render an explicit placeholder, never nothing |

Shared layout props on containers: `gap` (`xs|sm|md|lg|xl`), `padding`,
`radius`, `alignment` (`start|center|end|stretch`), `distribution`
(`start|center|end|spaceBetween|spaceAround|spaceEvenly`); `stack` adds
`direction`; `card` adds `title`.

`table` takes `headers` + `rows`; cells may be literals or typed objects
`{"type": "text|number|badge|action"}` with `ColumnAlign`.

## Actions

Interactive nodes carry `action: { "id": "invoice.approve", "payload": {...} }`.
The id is semantic — the renderer emits it as an `AIUXAction`; the host
resolves it through its own policy. Payloads never contain code.

## Update semantics

`surface.updated` replaces the whole tree at a higher `revision` (no partial
patches in v1 — trees are small by the node cap, and replace-whole keeps
renderer diffing trivial and deterministic).

## Example

```json
{"id": "s1", "name": "Invoice summary", "revision": 1, "root": {
  "type": "surface", "children": [
    {"type": "card", "title": "Invoice #293", "children": [
      {"type": "heading", "text": "Invoice #293", "level": 2},
      {"type": "keyValue", "items": [{"key": "Total", "value": "$42.00"}]},
      {"type": "actions", "children": [
        {"type": "button", "label": "Approve", "variant": "primary",
         "action": {"id": "invoice.approve", "payload": {"invoiceId": "293"}}}
      ]}
    ]}
  ]
}}
```

## Validation failures (all `invalidEvent`)

- root `type` ≠ `surface`, or `surface` node below the root
- unknown `type` value / `custom` missing `name`
- > 4096 nodes total
- unknown fields are stripped by the sanitizer rather than fatal —
  forward compatibility (§21): a `0.2` producer emitting an optional new
  field still renders on `0.1` renderers
- action ids containing whitespace (ids are tokens, not sentences)
