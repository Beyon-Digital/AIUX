# aiux-swift binding

UniFFI-generated Swift + XCFramework packaging. Phase 2 (plan §5).

## Local development

`bash bindings/swift/generate.sh` regenerates the UniFFI sources + headers
under `Sources/` and the host-arch Rust archive at
`Sources/AIUXCoreFFI/lib/libaiux_uniffi.a` (all gitignored — never committed).
`swift build` / `swift test` from this directory then work as usual.

## Distribution

`bash bindings/swift/package-xcframework.sh` (macOS + Xcode + Rust) produces
`build/xcframework/` with two artifacts a consumer needs **both** of:

- `AIUXCore.xcframework` — the compiled FFI library + C shim, vendored via
  an SPM `binaryTarget` (or linked directly in Xcode).
- `Sources/AIUXCore/AIUXCore.swift` — the generated Swift API
  (`AiuxSession`, `dispatchBatch`, `snapshot`, `serialize`, `restore`,
  `reset`). An XCFramework cannot carry Swift sources, so this file is
  staged beside it; add it to the app/framework target that talks to the
  core. Without it the package has the Rust archives but no callable API.
