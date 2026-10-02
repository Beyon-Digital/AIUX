# CI / Release Guide

## CI (`ci.yml` — every PR + main push)

Guardrails (§19): top-level concurrency group `ci-${{github.workflow}}-
${{github.ref}}` with `cancel-in-progress: true`; **every** job has
`timeout-minutes`.

| Job | Runs on | Covers |
|-----|---------|--------|
| `protocol-validate` | ubuntu | schema drift: `cargo run -p aiux-protocol --bin gen-schemas` + `git diff --exit-code protocol/schemas` — edit Rust types, regenerate, commit |
| `rust` | ubuntu | fmt, `clippy --workspace --all-targets -D warnings`, `cargo test --workspace`, release build — benches are compiled+smoked here (`cargo bench --bench session -- --test`) |
| `swift-bindings` | macos | UniFFI gen + SwiftPM build+test of `bindings/swift` & `renderers/swiftui` |
| `kotlin-bindings` | ubuntu | UniFFI gen + `gradle build test` of `bindings/kotlin` & `renderers/compose` |
| `js` | ubuntu | `pnpm -r typecheck` + `pnpm -r test` (adapters, transports, wasm JS wrapper, web renderer incl. golden DOM snapshots) |
| `web-build` | ubuntu | `pnpm --filter @beyondigital/aiux-web build` + examples/web build against real wasm |
| `expo-android` | ubuntu | gradle `assembleDebug` of `bridges/expo/android` + example app |
| `expo-ios` | macos | pod install + xcodebuild of example app (staged XCFramework) |
| `flutter` | ubuntu | dart ffi build, `dart analyze/test`, `flutter analyze/test` (renderer + example) |
| `flutter-goldens` | ubuntu | `AIUX_GOLDENS=1 flutter test test/golden_test.dart --update-goldens` → PNG artifact (`flutter-goldens`, 30d) for human review |
| `conformance` | ubuntu | 27/27 fixtures through the Rust runner |

## Release (`release.yml` — tag `v*`)

Pipeline per §20; every artifact derives from the **same tag commit**:

```
validate-tag → conformance → build-rust (per-target libs) →
build-apple (macos: XCFramework+swift bindings) →
build-android (kotlin gen + AAR) → build-js-wasm (wasm-pack + pnpm builds)
→ checksums → GitHub Release (draft w/ generated notes)
```

- `generate-notes` runs `node tools/release-notes.mjs <prev-tag> <tag>`
  (conventional-commit changelog, grouped).
- Artifacts: `AIUXCore.xcframework.zip`, `aiux-compose-*.aar`,
  `aiux-bindings-kotlin-*.jar`, `aiux-wasm/pkg` tarball, per-target Rust
  libs, npm-ready JS package dirs (publishable to **GitHub Packages** —
  internal v0.x scope per §20; public registries deferred).
- `SHA256SUMS` covers every uploaded asset.

### Cutting a release (operator checklist)

1. Green `ci.yml` on the release commit.
2. `git tag v0.1.0 <commit> && git push origin v0.1.0`.
3. `release.yml` runs; the GitHub Release is created **draft** — attach
   review, then publish.
4. Optional: publish JS packages to GitHub Packages
   (`npm publish --registry https://npm.pkg.github.com` with the repo
   `@beyondigital` scope) — bodies are wired in `release.yml` but gated
   behind `workflow_dispatch`/manual step until registry auth is set.

## Local equivalents

| Task | Command |
|------|---------|
| Conformance | `cargo run -p aiux-conformance` (see `conformance/README.md`) |
| Benches | `cargo bench -p aiux-benches --bench session` |
| Schema regen | `cargo run -p aiux-protocol --bin gen-schemas` |
| Swift bindings | `bash bindings/swift/generate.sh` (macOS) |
| XCFramework | `bash bindings/swift/package-xcframework.sh` (macOS) |
| Kotlin bindings | `bash bindings/kotlin/generate.sh` |
| wasm/JS core | `bash bindings/wasm/build.sh` |
| JS workspace | `pnpm install && pnpm -r typecheck && pnpm -r test` |
| Dep audits | `cargo audit`; `pnpm audit`; `gradle :renderers:compose:dependencies` + OWASP dep-check (see `docs/integration/dependency-audit.md`) |
