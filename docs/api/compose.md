# Compose renderer — `aiux:compose` / `in.beyondigital.aiux:compose`

Jetpack Compose renderer for Android (minSdk 24, compileSdk 36, Kotlin 2.0.20
+ Compose BOM 2024.12.01). Distributed in `aiux-android-maven.tar.gz` — see
[install](../integration/install.md#android). Source:
[`renderers/compose`](../../renderers/compose).

## The 3-piece setup

```kotlin
val store = AIUXSessionStore.create("""{"sessionId":"s1"}""")

setContent {
    AIUXThemeProvider {                                  // installs AIUXTheme
        val snapshot by store.snapshot.collectAsState()
        AIConversation(snapshot = snapshot, onAction = ::route)
    }
}
```

## `AIUXSessionStore`

Wraps the UniFFI `AiuxSession` in Compose-friendly `StateFlow`s; every FFI
call runs on `Dispatchers.IO` under a mutex (dispatch order = call order).

```kotlin
val store = AIUXSessionStore.create(
    configJson = """{"sessionId":"s1"}""",   // or restore(serializedJson)
    ioDispatcher = Dispatchers.IO,
)

store.snapshot          // StateFlow<AIUXSnapshot>   — decoded render model
store.snapshotJson      // StateFlow<String>        — raw snapshot (bridge events)
store.lastError         // StateFlow<AIUXError?>     — last FFI failure
store.lastReport        // StateFlow<AIUXDispatchReport>

suspend store.dispatch(eventJson)       // → Result<AIUXDispatchReport>
suspend store.dispatchBatch(eventsJson) // → Result<AIUXDispatchReport>
store.dispatchAsync(eventJson)          // fire-and-forget on the scope
store.dispatchBatchAsync(eventsJson)
suspend store.serialize()               // → Result<String>
suspend store.snapshotJson()            // → Result<String>
suspend store.reset()
store.resetAsync()                      // non-suspend — safe from sync contexts
store.refresh()                         // re-read snapshot into the flows
store.close()                           // Closeable — cancels the scope
```

`AIUXSessionStore` implements `Closeable`. `dispatchBatch` is the recommended
boundary (batch = one FFI call, not per token).

## `@Composable AIConversation`

```kotlin
AIConversation(
    snapshot = snapshot,
    modifier = Modifier,
    mode = AIConversationMode.Fullscreen,      // Fullscreen | Embedded
    showComposer = true,
    showContextBar = true,
    composerToolbar = AIComposerToolbar.Default,
    onAction = { action -> route(action) },
)
```

Fullscreen: `Scaffold` with a `TopAppBar` titled from `snapshot.session?.title`,
context bar, message feed and the floating composer (IME + nav-bar padded).
Embedded: the same content in flow.

## Theming — `AIUXThemeProvider`

```kotlin
AIUXThemeProvider(
    theme = if (isSystemInDarkTheme()) AIUXTheme.dark() else AIUXTheme.light(),
) { /* content */ }
```

- Provides `LocalAIUXTheme`; read it via `AIUX.theme` inside composables.
- Also wraps content in a `MaterialTheme` mapped from the role colors, so
  stock M3 widgets inside AI surfaces stay consistent.

`AIUXTheme(colors, typography, spacing, radius, motion, density)` where
`AIUXColors` carries 17 roles incl. `inputSurface`, `codeSurface`,
`codeForeground`, `mutedForeground`, `destructiveForeground`. Defaults follow
the ChatGPT mobile language — flat assistant messages, monochrome accent:

| Role | `light()` | `dark()` |
| --- | --- | --- |
| `background` / `surface` | `#FFFFFF` | `#0C0C0C` |
| `surfaceElevated` | `#F4F4F5` | `#242424` |
| `userSurface` | `#ECECF1` | `#2F2F2F` |
| `assistantSurface` | transparent | transparent |
| `accent` / `accentForeground` | `#0D0D0D` / `#FFFFFF` | `#FFFFFF` / `#0D0D0D` |
| `muted` / `mutedForeground` | `#F4F4F5` / `#707070` | `#2A2A2A` / `#B4B4B4` |
| `border` | `#E6E6E6` | `#333333` |
| `foreground` | `#0D0D0D` | `#ECECEC` |
| `inputSurface` | `#FFFFFF` | `#1F1F1F` |
| `codeSurface` / `codeForeground` | `#171717` / `#ECECEC` (both schemes) | |

`AIUXTypography` (body/caption/label/heading/title/code `TextStyle`s),
`AIUXSpacing` (xs 4 / sm 8 / md 12 / lg 16 / xl 24 dp),
`AIUXRadii` (sm 8 / md 12 / lg 20 dp, full), `AIUXMotion`,
`AIUXDensity.Compact|Regular|Spacious`.

## Composer toolbar

```kotlin
AIConversation(
    snapshot = snapshot,
    composerToolbar = AIComposerToolbar(
        attach = true,        // `+` → aiux.composer.attach
        tools = false,        // tools toggle → aiux.composer.tools (opt-in)
        dictate = true,       // mic → aiux.composer.dictate
        extra = listOf(
            AIComposerTool(id = "aiux.composer.docs",
                           contentDescription = "Docs",
                           glyph = AIComposerGlyph.Document),
        ),
    ),
)
```

`AIComposerGlyph`: `Sparkle, Document, Photo, Gear, Globe, Mic, Search, Plus,
Star` — or pass a custom `icon` composable. Custom tools emit their `id` as
the action. All controls render in uniform 40dp slots.

## Surfaces & custom nodes

`AISurface(snapshot)` renders a surface tree — every schema node incl.
`form`/`field`/`radio`/`listItem`/`table`/`custom` (ADR 0007).

- `LocalAIUXCustomNodes`:
  `compositionLocalOf<Map<String, @Composable (AISurfaceNode.Custom) -> Unit>>`
  — registry keyed by the node's `kind`; unregistered kinds render a
  placeholder and still render children.
- `LocalAIUXFormScope` + `LocalAIUXFormDisabled` — form scope collects field
  values into the submit action's `fields` payload; `disabled` propagates to
  inputs.
- Field changes emit `aiux.surface.{input,select,checkbox,radio}.change`
  actions with `{surfaceId, nodeId, value}`.

## Actions — `AIUXActions` constants

```kotlin
AIUXActions.COMPOSER_SEND        // "aiux.composer.send"
AIUXActions.COMPOSER_CANCEL      // "aiux.composer.cancel"
AIUXActions.COMPOSER_ATTACH      // "aiux.composer.attach"
AIUXActions.COMPOSER_TOOLS       // "aiux.composer.tools"
AIUXActions.COMPOSER_DICTATE     // "aiux.composer.dictate"
AIUXActions.COMPOSER_VOICE       // "aiux.composer.voice"
AIUXActions.APPROVAL_APPROVE     // "aiux.approval.approve"
AIUXActions.APPROVAL_REJECT      // "aiux.approval.reject"
AIUXActions.ERROR_RETRY          // "aiux.error.retry"
AIUXActions.CITATION_OPEN        // "aiux.citation.open"
AIUXActions.ATTACHMENT_OPEN      // "aiux.attachment.open"
AIUXActions.IMAGE_OPEN           // "aiux.image.open"
AIUXActions.ARTIFACT_OPEN        // "aiux.artifact.open"
AIUXActions.CONTEXT_OPEN         // "aiux.context.open"
AIUXActions.SURFACE_INPUT_CHANGE // "aiux.surface.input.change"
AIUXActions.SURFACE_SELECT_CHANGE
AIUXActions.SURFACE_CHECKBOX_CHANGE
AIUXActions.SURFACE_RADIO_CHANGE
```

`AIUXAction(id, payload: JsonObject)` — payloads are kotlinx-serialization
JSON. Full vocabulary + payloads: [actions guide](../guides/actions.md).

## Other exports

- Leaf composables: `AIMessage`, `AIPart` (all 13 part kinds), `AIComposer`,
  `AIContextBar`, `AIToolStatus`, `AIApproval`, `AIArtifactPreview`,
  `AISurface`, `SurfaceNodeView`, `AIMarkdown`, `AICodeBlock`.
- Parsers: `AIUXModelParser` (snapshot JSON → models), `SurfaceNodeParser`
  (surface JSON → nodes), `MarkdownParser` (inline markdown → `AnnotatedString`).
- Fixtures: `AIUXFixture` + `FixtureHarness` (test-side) — replay
  `conformance/fixtures` through a real `AiuxSession`.
- Models: `AIUXSnapshot`, `AIUXMessage`, `AIUXTool`, `AIUXApproval`,
  `AIUXArtifact`, `AIUXSurface`, `AISurfaceNode`, `AIUXRun`,
  `AIUXContextEntity`, `AIUXError`, `AIUXDispatchReport`.

## Working references

- [`examples/android-native/src/main/kotlin/aiux/example/`](../../examples/android-native/src/main/kotlin/aiux/example/)
  — `DemoController` + `MockAgent.kt`: the canonical scripted scenario
  (stream → tool → approval → surface → error/retry → cancel).
