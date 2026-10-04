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
| `bridges/` | `expo` (`@beyond-digital/aiux-expo`), `react-native` |
| `transports/` | Host-side transport helpers per language |
| `adapters/` | Wire adapters (ai-sdk, sse, websocket, graphql) |
| `examples/` | Example app per renderer/bridge |
| `conformance/` | Canonical fixtures + expected states + harness |
| `docs/` | Architecture, protocol, renderer, integration docs + ADRs |

## Docs

- **Plan of record:** [docs/PLAN.md](docs/PLAN.md)
- **Execution tracker:** [TASKS.md](TASKS.md)
- **Decisions:** [docs/adr/](docs/adr/)
- **Usage guide:** [docs/integration/usage.md](docs/integration/usage.md)
- **API reference:** [docs/protocol/api-reference.md](docs/protocol/api-reference.md)

## Install and availability

See [consumer installation](docs/integration/install.md) for versioned commands,
native prerequisites, and the availability of each client. The existing v0.1.0
draft is not a registry release. v0.1.1 is the first installable release, published through the gated release workflow.

## Build from source

```bash
cargo test --workspace        # Rust core
pnpm install && pnpm build    # JS packages
./gradlew build               # Kotlin/Android modules
swift build                   # inside renderers/swiftui (macOS)
```

## License

[MIT](LICENSE).
