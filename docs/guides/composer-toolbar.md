# Composer toolbar

The composer's bottom row has three stock controls plus host-added custom
tools, in a uniform 40pt/40dp slot:

```
[ + attach ] [ custom tools … ]              [ tools ] [ mic ] [ send/voice ]
```

| Control | Flag | Action emitted | Default |
| --- | --- | --- | --- |
| `+` attach | `attach` | `aiux.composer.attach` | on |
| Tools toggle | `tools` | `aiux.composer.tools` | **off** (opt-in) |
| Mic / dictate | `dictate` | `aiux.composer.dictate` | on |
| Action circle | — | `send` (idle) / `cancel` (streaming) / `voice` | always |

Custom tools sit between the built-ins and the action circle; tapping emits
your `id` as the action — route it like any other
[action](actions.md). Name custom ids under `aiux.composer.*` by convention.

## Expo

```tsx
<AIConversation
  sessionId="s1"
  composerToolbar={{
    attach: true,
    tools: true,
    dictate: false,
    extra: [
      {id: "aiux.composer.docs",  label: "Docs",   glyph: "doc"},
      {id: "aiux.composer.photo", label: "Photo",  glyph: "photo"},
      {id: "aiux.composer.scan",  label: "Scan",   glyph: "search"},
    ],
  }}
/>
```

`AIUXComposerToolbarSpec` — `{attach?, tools?, dictate?, extra?: AIUXComposerToolSpec[]}`
serialized as JSON across the bridge. A `string` shorthand (`"docs"` style
preset names) is also accepted.

`AIUXComposerGlyphName`: `"sparkle" | "doc" | "photo" | "gear" | "globe" |
"mic" | "search" | "plus" | "star"` — rendered as SF Symbols on iOS and the
matching Material/Compose glyph on Android.

## SwiftUI

```swift
AIConversation(store: store, composerToolbar: AIUXComposerToolbar(
    attach: true, tools: true, dictate: false,
    extra: [AIUXComposerTool(id: "aiux.composer.docs",
                            accessibilityLabel: "Docs",
                            systemImage: "doc.text")]))
```

Custom tools take any SF Symbol name — you're not limited to the glyph enum.

## Compose

```kotlin
AIConversation(
    snapshot = snapshot,
    composerToolbar = AIComposerToolbar(
        attach = true, tools = true, dictate = false,
        extra = listOf(
            AIComposerTool(id = "aiux.composer.docs",
                           contentDescription = "Docs",
                           glyph = AIComposerGlyph.Document),
            AIComposerTool(id = "aiux.composer.qr",
                           contentDescription = "QR",
                           icon = { Icon(painterResource(R.drawable.ic_qr), null) }),
        ),
    ),
)
```

`AIComposerGlyph`: `Sparkle, Document, Photo, Gear, Globe, Mic, Search, Plus,
Star`; or pass a custom `icon` composable.

## Web

`AIComposer` exposes behavior props rather than a toolbar spec:
`{onAction, attachmentsEnabled, disabled, placeholder}`. Hide or add
controls by composing `AIComposer` with your own buttons alongside it
inside `AIConversation`'s layout, or fork the layout with the leaf
components.

## Behavior notes

- Custom tools render in the same hit target as built-ins — keep labels
  short; `accessibilityLabel`/`contentDescription` is required.
- The action circle switches send ⇄ cancel ⇄ voice automatically from run
  state — you can't remove it, only change glyph via `mode`.
- Attach/dictate emit *intents* — wiring the actual picker/dictation is the
  host's job (see [actions](actions.md)).
