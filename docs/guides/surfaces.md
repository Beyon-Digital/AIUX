# Surfaces & custom nodes

Surfaces are **agent-authored UI trees** — the model emits
`surface.created`/`surface.updated` events carrying a `root` node, and every
renderer draws the same tree natively. This is how an agent asks for input
(forms), shows structured results (tables, key-value grids), or hands the
host a semantic action.

```jsonc
// surface.created payload
{"surface": {"id": "sfr-1", "name": "Intake", "revision": 1,
             "root": {"type": "form", …}}}
```

## The 31 node types

| Group | Nodes |
| --- | --- |
| **Containers** | `surface` (tree root), `card`, `stack`, `row`, `grid`, `form`, `actions` |
| **Content** | `heading`, `text`, `markdown`, `code`, `icon`, `image`, `badge`, `divider`, `spacer`, `keyValue`, `list`, `listItem`, `table` |
| **Controls** | `button`, `menu`, `progress`, `status` |
| **Inputs** | `input`, `textarea`, `select`, `checkbox`, `radio`, `field` |
| **Extension** | `custom` — host-registered `kind` |

## Node fields (union)

Every node carries `type` plus optional fields — presence depends on the
type:

```ts
type SurfaceNode = {
  type: …; id?: string;
  // containers
  children?: SurfaceNode[];           // (in NodeBase)
  title?: string; subtitle?: string;
  direction?: "row" | "column";       // stack
  columns?: number | TableColumn[];   // grid | table
  // content
  text?: string; level?: number; variant?: string;
  markdown?: string; code?: string; language?: string;
  name?: string;                      // icon name
  size?: IconSize | Gap; src?: string; alt?: string;
  tone?: Tone; icon?: string;
  items?: KeyValueItem[] | SelectOption[] | MenuItem[];
  ordered?: boolean;                  // list
  headers?: string[];                 // table
  rows?: TableCell[][] | number;      // table matrix | textarea rows
  caption?: string;
  // controls & inputs
  label?: string; action?: AiuxAction; disabled?: boolean;
  value?: number | string; max?: number;
  placeholder?: string; inputType?: InputType; required?: boolean;
  checked?: boolean; options?: SelectOption[];
  errorText?: string; helperText?: string;
  // form
  submit?: AiuxAction; submitLabel?: string;
  // custom
  kind?: string; props?: JsonObject;
}
```

`KeyValueItem` = `{type:"text",text} | {type:"number",value} |
{type:"badge",text,tone?} | {type:"action",label,action}`.

## Events

- `surface.created {surface: SurfaceTree}` — `SurfaceTree {id, name?,
  revision?, root}`.
- `surface.updated {surfaceId, root}` — replace the whole tree (renderer
  re-renders; form state the user entered is renderer-owned, so avoid
  rewriting a form people are mid-fill on — prefer a new surface or field
  updates through your own channel).

## Interactions

- `button` / `actions` row buttons emit `action` (`{id, payload}`) — your
  ids, your semantics; route them in `onAction`.
- Input edits emit `aiux.surface.{input|select|checkbox|radio}.change` with
  `{surfaceId, nodeId, value}` — keep a field map in your controller.
- `form` wraps inputs + a submit row: on submit it emits `submit` (an
  `AiuxAction` you author in the tree — e.g. `myapp.intake.submit`) with the
  collected `fields` merged into the payload.
- `AiuxFormStore` (Swift) / `LocalAIUXFormScope` (Compose) collect field
  values — `disabled` propagates to nested inputs.

## `custom` nodes — the extension point

```json
{"type": "custom", "kind": "myapp.chart", "props": {"points": [1,2,3]}}
```

Register a renderer per `kind` per platform; unregistered kinds render a
placeholder and still render `children`:

| Platform | Registration |
| --- | --- |
| Web | `customNodes={{ "myapp.chart": MyChart }}` on `AIConversation` — `ComponentType<{node: SurfaceNode}>` |
| Expo | `customNodes` prop (same shape, forwarded natively where supported) |
| SwiftUI | `.aiuxCustomNodes(["myapp.chart": { node in AnyView(MyChart(node)) }])` |
| Compose | `CompositionLocalProvider(LocalAIUXCustomNodes provides mapOf("myapp.chart" to { n -> MyChart(n) }))` |

`props` is opaque JSON — your renderer decodes it.

## Example — intake form (what the mock agent emits)

```jsonc
{"type": "form", "id": "intake",
 "submit": {"id": "demo.intake.submit"},
 "children": [
   {"type": "heading", "level": 2, "text": "Tell us about the case"},
   {"type": "field", "label": "Name", "required": true,
    "children": [{"type": "input", "id": "name", "placeholder": "Full name"}]},
   {"type": "field", "label": "Matter type",
    "children": [{"type": "select", "id": "kind",
      "options": [{"label":"Civil","value":"civil"},
                  {"label":"Criminal","value":"criminal"}]}]},
   {"type": "actions", "children": [
     {"type": "button", "label": "Submit", "variant": "primary"}]},
 ]}
```

Field edits stream `aiux.surface.*.change` actions; submit emits
`demo.intake.submit` with `fields: {name, kind}`.

See also: [surface schema](../protocol/surface-schema.md),
[ADR 0007](../adr/0007-surface-dsl-expansion.md).
