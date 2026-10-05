# Flutter renderer — `aiux` (Dart)

Flutter renderer driven by the same wire models. Consumes the core through
`dart:ffi` against `libaiux_capi` (built by `bindings/dart/generate.sh`).
Source: [`renderers/flutter`](../../renderers/flutter).

## Setup

```dart
final backend = AiuxFfiBackend(libraryPath: 'libaiux_capi.dylib');
final store = AiuxSessionStore(backend: backend);
await store.create('{"sessionId":"s1"}');

AIConversation(store: store)
```

## `AiuxSessionStore`

Change-notifying wrapper over a JSON backend (`AiuxSessionBackend`, the same
contract as the [SwiftUI store](swiftui.md#aiuxsessionbackend)):

```dart
await store.create(configJson)      // or store.restore(serializedJson)
await store.dispatch(eventJson)     // → AiuxDispatchReport
await store.dispatchBatch(eventsJson)
store.snapshot                      // decoded AiuxSnapshot, notifies on change
await store.serialize()
await store.reset()
```

The store reparses `snapshot()` after every dispatch so widgets rebuild off
plain `notifyListeners`/`AnimatedBuilder` or `Provider`.

## `AIConversation`

```dart
AIConversation(
  store: store,
  mode: AiuxConversationMode.fullscreen,   // fullscreen | embedded
  onAction: (action) => route(action),
)
```

Same layout contract as the other renderers: context bar, message feed,
unreferenced entities, composer. Emits the shared
[action vocabulary](../guides/actions.md).

## `AiuxTheme` / `AiuxThemeData`

```dart
AiuxTheme(
  data: AiuxThemeData.standard(),          // or a fully custom instance
  child: …,
)
```

`AiuxThemeData` — `colors: AiuxColorRoles`, `typography: AiuxTypography`,
`spacing: AiuxSpacing`, `radius: AiuxRadiusTokens`, `motionDuration`,
`density: AiuxDensity`, plus `colorsFor(Brightness)`. Each `AiuxColor` is a
light/dark pair resolved against the ambient `Brightness`.

`AiuxThemeData.standard()` defaults — Flutter's own palette (blue accent,
independent of the SwiftUI/Compose ChatGPT-aligned defaults):

| Role | Light | Dark |
| --- | --- | --- |
| `background` | `#FFFFFF` | `#1A1A1C` |
| `surface` | `#F5F5F7` | `#29292E` |
| `surfaceElevated` | `#FFFFFF` | `#36363D` |
| `userSurface` | `#E0EBFF` | `#294070` |
| `assistantSurface` | `#F0F0F5` | `#303036` |
| `accent` | `#336BDB` | `#6699FA` |
| `accentForeground` | `#FFFFFF` | `#0F172B` |
| `muted` | `#6B7079` | `#9EA3AD` |
| `border` | `#DBDDE3` | `#52545C` |
| `destructive` | `#D43D36` | `#F0635C` |
| `success` | `#299956` | `#5CC280` |
| `warning` | `#CC841A` | `#F2B240` |

## Constants

`aiuxProtocolVersion = '0.1'` (re-exported in `lib/aiux.dart`).

## Status

The renderer is wire-complete for the conversation model (messages, parts,
tools, approvals, artifacts, surfaces, context). Check
[`renderers/flutter/lib/src`](../../renderers/flutter/lib/src) for the current
widget surface — it trails SwiftUI/Compose on the newest features.
