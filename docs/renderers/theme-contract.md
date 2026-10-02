# Theme Contract

The §7 contract: renderers own **no** brand decisions. Every visual value
resolves through a semantic role the host supplies — same shape on all five
platforms, mapped to each platform's idiom (CSS vars, SwiftUI `Environment`,
Compose `CompositionLocal`, Flutter `ThemeExtension`-style object).

## Roles

### Colors (13)

| Role | Used for |
|------|----------|
| `background` | App-level backdrop behind the conversation |
| `foreground` | Primary body text |
| `surface` | Cards, tool rows, approval panels |
| `surfaceElevated` | Raised chrome (header, composer, popovers) |
| `userSurface` | User message bubble |
| `assistantSurface` | Assistant message bubble |
| `accent` | Primary actions, links, active states |
| `accentForeground` | Text/icons on `accent` |
| `muted` | Secondary text, timestamps, hints |
| `border` | Hairlines, input outlines |
| `destructive` | Errors, destructive actions |
| `success` | Completed states |
| `warning` | Approvals-pending, caution |

### Typography (6 roles) — each `{fontFamily, fontSize, fontWeight, lineHeight}`

`body`, `caption`, `label`, `heading`, `title`, `code`

### Spacing scale (5) — `xs sm md lg xl` (web defaults `0.25/0.5/0.75/1/1.5rem`)

### Radius (4) — `sm md lg full`

### Motion — `{ durationMs, reduce }`; `reduce` also auto-honors the platform
reduced-motion setting unless overridden.

### Also: `density` (`comfortable|compact`), `colorScheme` (`light|dark|auto`)

## Per-platform expression

| Platform | Type / entry point | Resolution |
|----------|--------------------|------------|
| Web | `AiuxTheme` → `resolveTheme()` | `themeCssVars()` → `--aiux-color-*`, `--aiux-font-*`, `--aiux-space-*`, `--aiux-radius-*`, `--aiux-motion-duration` scoped to the component root — themes never leak |
| SwiftUI | `AIUXTheme` + `.aiuxTheme(_:)` | `Environment(\.aiuxTheme)`; `colors(for: colorScheme)` picks light/dark pair |
| Compose | `AIUXTheme` via `AIUX` provider | `AIUX.theme` CompositionLocal; Material3 container colors from it |
| Flutter | `AiuxThemeData` | theme object on `AiuxScope`; light+dark palettes both supported |
| Expo | `AIUXThemeInput` prop (object or JSON string) | serialized once across the bridge → native `AIUXTheme` per platform |

Colors accept CSS-style strings (`#rgb`, `#rrggbb`, `#rrggbbaa`,
`rgb()/rgba()`) everywhere — one authored theme object ports across all five
renderers. On all platforms `colors` may be flat or `{light, dark}` scoped.

## Defaults

Every role has a built-in light + dark value (web: `LIGHT_COLORS`/
`DARK_COLORS`; natives: paired colors) — a host can ship zero theme and get
a correct UI, then override roles piecemeal (`Partial<>` semantics — only
supplied keys replace).

## Rules

- Renderers must never read a raw hex not present in the contract, and never
  invent roles — additions go through schema + ADR (§25 protocol changes).
- `dark` is a first-class input, not a derived inversion.
- Motion `reduce` must collapse streaming dots/progress animation to static
  indicators.
