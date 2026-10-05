# Theming

One role vocabulary, four platform implementations. You theme **roles**, not
widgets — the renderer maps roles to every message bubble, chip, composer,
approval card and surface node.

## The role vocabulary

All renderers share ~17 color roles:

| Role | Used for |
| --- | --- |
| `background` | Screen canvas |
| `surface` | Cards, entity rows |
| `surfaceElevated` | Composer, floating elements |
| `userSurface` | User message bubbles |
| `assistantSurface` | Assistant bubbles (transparent on native defaults = flat ChatGPT style) |
| `accent` | Send button, active controls, links |
| `accentForeground` | Text/icons on `accent` |
| `muted` | Subtle fills |
| `mutedForeground` | Secondary text |
| `border` | Hairlines, dividers |
| `destructive` / `destructiveForeground` | Reject/error actions |
| `success` | Completed states |
| `warning` | Pending/caution |
| `foreground` | Primary text |
| `inputSurface` | Text input fill |
| `codeSurface` / `codeForeground` | Code blocks |

Beyond colors: `typography` (body/caption/label/heading/title/code),
`spacing` (xs→xl), `radius` (sm/md/lg/full), `motion` (durations, reduced
motion), `density` (compact/regular/spacious).

## Web — `@beyond-digital/aiux-web`

```tsx
import {AIConversation, resolveTheme, themeCssVars, LIGHT_COLORS, DARK_COLORS}
  from "@beyond-digital/aiux-web";

// 1) Whole-theme object:
<AIConversation session={s} theme={{colors: {...LIGHT_COLORS, accent: "#7c3aed"}}} />

// 2) Or emit CSS vars yourself:
const vars = themeCssVars(resolveTheme("dark")); // { "--aiux-background": "#...", ... }
```

- `resolveTheme(input)` — accepts `"light" | "dark" | theme object | partial`.
- `themeCssVars(theme)` — every role as a `--aiux-*` CSS variable; drop them
  under your own class for scoped themes.
- Web defaults (blue accent): light `accent #2563eb`,
  `userSurface #e8f0fe`; dark `accent #5b8def`.
- Reduced motion is auto-detected from `prefers-reduced-motion`.

## Expo — `AIUXThemeInput`

```tsx
<AIConversation
  sessionId="s1"
  theme={{colors: {accent: "#7c3aed", userSurface: "#ede9fe"}}}
/>
```

`AIUXThemeInput` maps the 17 `AIUXColorRole`s (+ typography/spacing/radius)
and crosses the bridge as JSON — the native side resolves light/dark per
role. Pass a preset name string (`"dark"`) or a partial object; unspecified
roles fall back to native defaults. The example passes an **empty** object —
native ChatGPT defaults stay (see [`examples/expo/src/theme.ts`](../../examples/expo/src/theme.ts)).

## SwiftUI — `AIUXTheme`

```swift
.environment(\.aiuxTheme, AIUXTheme(colors: .init(
    accent: AIUXColor(light: "#7C3AED", dark: "#A78BFA"),
    …
)))
```

- `AIUXTheme {colors: AIUXColorRoles, typography, spacing, radius, motion, density}`.
- `AIUXColor` is a light/dark pair — `resolve(in: .light/.dark)` picks per
  color scheme; the renderer resolves against the ambient `ColorScheme`.
- Defaults: `AIUXTheme.light()` / `.dark()` — ChatGPT-aligned (flat
  assistant messages, monochrome accent).
- `AIUXMotion.animation(reduced:value:)` respects Reduce Motion.

## Compose — `AIUXThemeProvider`

```kotlin
AIUXThemeProvider(
    theme = if (isSystemInDarkTheme()) AIUXTheme.dark() else AIUXTheme.light()
        .copy(colors = AIUXTheme.light().colors.copy(accent = Color(0xFF7C3AED))),
) { AIConversation(…) }
```

Wraps content in a MaterialTheme mapped from roles — stock M3 widgets inside
surfaces stay consistent. Role defaults: [compose API](../api/compose.md#theming--aiuxthemeprovider).

## Flutter — `AiuxThemeData`

```dart
AiuxTheme(data: AiuxThemeData.standard(), child: …)
```

`AiuxColorRoles` of light/dark `AiuxColor` pairs resolved by `Brightness`.
Flutter's `standard()` palette has its own blue-accent defaults
(`#336BDB`/`#6699FA`) — full table: [flutter API](../api/flutter.md#aiuxtheme--aiuxthemedata).

## Choosing a palette strategy

- **Brand accent only**: override `accent` + `accentForeground` (and maybe
  `userSurface`) — 95% of perceived theming.
- **Full brand pass**: define all 17 roles per scheme; keep
  `assistantSurface` transparent for the flat look or give it a tint for
  bubbles.
- **Dark mode**: every platform has a light/dark pair; drive it from the OS
  (`isSystemInDarkTheme()`, `ColorScheme`, `Brightness`) or your app setting
  (the example's "Dark" toggle).

See also: [theme contract](../renderers/theme-contract.md) — the
renderer-side guarantees (contrast fallbacks, reduced motion, density).
