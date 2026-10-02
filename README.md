# AIUX

A reusable, framework-independent AI interaction platform — the default UX
foundation for Beyondigital AI applications.

One protocol, one Rust state engine, one semantic surface schema — rendered
natively by SwiftUI, Jetpack Compose, React DOM, and Flutter, and bridged into
Expo/React Native behind a single native boundary.

```
Host transport → AIUXEvent[] → Rust Core → AIUXSnapshot → Renderer
```

## Layout

| Path | Contents |
|------|----------|
| `protocol/` | Versioned AIUX Protocol schemas, fixtures, docs |
| `core/rust/` | Rust workspace: protocol, reducer, session, tools, approvals, artifacts, surfaces, persistence |
| `bindings/` | UniFFI (swift/kotlin), WASM (js), C ABI (dart) |
| `renderers/` | `swiftui`, `compose`, `web`, `flutter` |
| `bridges/` | `expo` (`@beyondigital/aiux-expo`), `react-native` |
| `transports/` | Host-side transport helpers per language |
| `adapters/` | Wire adapters (ai-sdk, sse, websocket, graphql) |
| `examples/` | Example app per renderer/bridge |
| `conformance/` | Canonical fixtures + expected states + harness |
| `docs/` | Architecture, protocol, renderer, integration docs + ADRs |

## Docs

- **Plan of record:** [docs/PLAN.md](docs/PLAN.md)
- **Execution tracker:** [TASKS.md](TASKS.md)
- **Decisions:** [docs/adr/](docs/adr/)

## Quick start

```bash
cargo test --workspace        # Rust core
pnpm install && pnpm build    # JS packages
./gradlew build               # Kotlin/Android modules
swift build                   # inside renderers/swiftui (macOS)
```

## License

Proprietary — Beyondigital.
