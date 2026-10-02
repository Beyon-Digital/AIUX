# Custom Tool UI Guide

How to give YOUR tool a bespoke visual without breaking the §23 "surface
payloads are data, never code" rule. Two mechanisms — pick per tool:

## 1. The standard path: tool entities + parts (no code needed)

Most tools need no custom UI at all. `tool.started/progress/completed/
failed` render as `AIToolStatus` rows — name, status badge, collapsible
input/result JSON — on every renderer for free. Use `Progress`/`Status`
parts for inline indicators and `artifact` parts for produced files.

**Stay here unless the tool's output is genuinely a UI** (chart, diff,
picker). Most "custom tool UI" requests are actually surfaces:

## 2. Surfaces for rich tool output

Emit `surface.created` with the closed node set — `keyValue`, `table`,
`progress`, `form`, `button`, … — and let the platform renderer draw it
natively. A chart is usually a `table`/`keyValue` + `badge`; a diff is
`code` + `row`. Covered by `docs/protocol/surface-schema.md`.

## 3. `custom` nodes — the registered escape hatch (ADR 0007)

When no primitive fits, emit a `custom` node and **register the renderer
per platform in YOUR app** — the node carries `kind` + data-only `props`;
the component lives in the host, not in the payload.

```json
{"type": "custom", "kind": "trade-ticket", "props": {"symbol": "AAPL", "qty": 10}}
```

| Platform | Registration |
|----------|--------------|
| Web | `<AIConversation customNodes={{ "trade-ticket": TradeTicket }} />` — `ComponentType<{node: SurfaceNode}>` |
| SwiftUI | register in the surface renderer's custom registry (host-side) |
| Compose | host registry on `AISurface` (`contentDescription` is set on the fallback) |
| Flutter | host registry on `AISurface` view |

**Contract** (all platforms):

- Unregistered `kind` → a labelled placeholder ("Unregistered custom node
  `<kind>`", `role="note"` on web) plus still-rendered `children` — never a
  blank spot, never a crash.
- `props` is a plain JSON object — no functions, no URLs-to-eval. Validation
  strips non-schema fields but `custom` props pass through opaquely.
- Actions still flow through `AIUXAction` — a custom component emits action
  ids; the host policy layer resolves them like any other.
- `kind` namespacing: prefix with your app (`myapp.trade-ticket`) — shared
  fixtures never rely on a `custom` kind being registered (the
  `surface-custom` conformance fixture asserts the *fallback* path).

## What NOT to do

- Don't put component code, URLs to scripts, or HTML in `props` — §23.
- Don't bypass with a `markdown` part containing HTML — renderers sanitize.
- Don't key off tool name to change core behavior — visual customization is
  a renderer/host concern; the core treats all tools identically.
