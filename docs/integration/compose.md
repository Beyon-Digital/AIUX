# Compose Integration

`in.beyondigital.aiux:compose` (renderers/compose) on
`in.beyondigital.aiux:core`/`bindings` (bindings/kotlin — UniFFI Kotlin
bindings + per-ABI `.so`s).

## Install

```kotlin
// settings.gradle.kts — composite build against the monorepo, or consume
// the published AAR (release pipeline produces aiux-compose-<ver>.aar).
includeBuild("../AIUX") {
    dependencySubstitution {
        substitute(module("in.beyondigital.aiux:compose"))
            .using(project(":renderers:compose"))
        substitute(module("in.beyondigital.aiux:bindings"))
            .using(project(":bindings:kotlin"))
    }
}

dependencies {
    implementation("in.beyondigital.aiux:compose:0.1.0")
}
```

Generate/rebuild the native slices: `bash bindings/kotlin/generate.sh`
(builds host `.so` + NDK `jniLibs/{arm64-v8a,armeabi-v7a,x86_64}` when the
NDK is installed; release pipeline builds all).

## Wire the store

```kotlin
val session = AiuxSession.create(configJson)        // UniFFI facade
val store = AIUXSessionStore(
    dispatch = { batch -> session.dispatchBatch(batch) },
    snapshot = { session.snapshot() },
)
```

## Render

```kotlin
setContent {
    AIUX(theme = myAiuxTheme) {          // §7 provider → CompositionLocal
        AIConversation(
            snapshot = store.snapshot,   // immutable projection
            mode = AIConversationMode.Fullscreen,   // or Embedded
            onAction = { action -> handleAction(action.id, action.payload) },
        )
    }
}
```

- `AIConversation(snapshot, mode, showComposer, showContextBar, onAction)`
  — the complete surface; `Embedded` drops the Scaffold/top bar.
- Ingest events by calling `store.dispatch(batchJson)` (or feed the store
  through the transport helpers); recomposition is incremental — message
  items are keyed by stable id.
- Fixture previews: `AIUXFixture` + `FixtureHarness` (test source) mirror
  the conformance set; screenshot via Paparazzi (see
  `docs/renderers/accessibility.md` golden matrix).

## Rules

- Same §23 contract: `onAction` receives `{id, payload}`; the composable
  never executes.
- Theme via `AIUXTheme` → `AIUX` provider; Material3 container colors derive
  from the contract roles.
- `minSdk` 26+ (see compatibility matrix); keep the Rust `.so` packaged per
  ABI — `jniLibs` layout produced by `generate.sh` is already correct.
