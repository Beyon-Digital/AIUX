# CI and release checklist

First-party code is MIT. The approved npm scope is `@beyond-digital`; this
supersedes the original internal-only plan. The immutable v0.1.0 tag/draft is
preserved; 0.1.1 is the installable candidate. See [consumer installation](install.md).

## Executable gates

- `pnpm install --frozen-lockfile` uses the committed real workspace lockfile.
- `pnpm release:check` verifies allowlisted implementations, license, versions,
  repository association and non-placeholder build/test/typecheck commands.
- `pnpm -r --if-present build` compiles JS. `finalize-js.mjs` makes emitted ESM
  imports resolve outside the workspace, including Node and Metro consumers.
- Build WASM on CI, then `node bindings/wasm/js/scripts/copy-wasm.mjs` copies
  generated JS, declarations and WASM into the package's declared exports.
- CI builds Apple/Android artifacts from the same commit. `stage-native.mjs`
  assembles Expo's complete native payload. The Android Maven repository includes
  dependency POMs; the Swift distribution uses a binary target without unsafe
  repo-relative linker flags.
- `pnpm release:pack` creates actual npm `.tgz` packages with `pnpm pack`, checks
  every entrypoint/export, rejects unresolved workspace dependencies, and requires
  Expo's native payload. Scaffolds are excluded from the allowlist.
- `pnpm release:smoke` installs those tarballs into an isolated npm project,
  runs real WASM lifecycle/imports, checks NodeNext declarations, builds Vite
  with shipped CSS/WASM, and resolves Expo JS declarations without repo links.
- `pnpm release:smoke -- --registry` / `node tools/consumer-smoke.mjs --registry`
  repeats installation against exact published registry versions.

## Operator checklist

1. Confirm scope ownership, MIT license and version. Never move an existing tag.
2. Run the PR's exact commit through CI: schema checks, Rust fmt/clippy/tests,
   Swift/Android builds, JS tests, Expo native compiles and Flutter tests.
3. Run the Release workflow on the candidate branch to produce and validate
   distribution artifacts. Branch runs upload artifacts and do not create a release.
4. Review [native accessibility/device gates](../renderers/accessibility.md).
   Record actual results; do not infer sign-off from native compilation. Use an
   explicitly labelled prerelease if those manual gates remain incomplete.
5. Merge the reviewed PR through the normal GitHub process. Create `v0.1.1`
   at the exact green commit; tag-triggered Release builds every artifact and
   creates a draft GitHub Release with notes, manifest and SHA256SUMS.
6. Authenticate npm securely. First publication requires an authorized npm
   account with access to `@beyond-digital`. Run `npm login` interactively;
   never paste credentials into chat or commit them. Publish the validated
   tarballs in manifest order with `npm publish <tarball> --access public`.
7. For later CI publication configure npm trusted publishing for this repository
   and `publish.yml` for each package. No npm credential is committed. Dispatch
   Publish packages with the release tag; it downloads the release's tarballs,
   checks checksum/CI evidence, publishes using OIDC and tests registry installs.
8. Independently verify every exact version and consumer install. Publish the
   GitHub draft only after artifacts and registry availability are confirmed.

## Availability boundaries

Rust is supported via Git dependencies; crates.io credentials and publishing are
not configured. Swift/Android ship self-contained GitHub distribution bundles.
Dart/Flutter are source/Git clients; pub.dev and multi-platform mobile C ABI
packaging remain pending. Plain RN Fabric and GraphQL are scaffolds and stay
private. Echo-only example scripts are not native-test evidence; CI has real
Expo Android/iOS compilation jobs.

## Evidence

Save commit SHA, exact CI run URLs, consumer logs, package manifest and hashes,
registry version/integrity results and manual native sign-offs alongside release
notes. A green old commit or an old draft release cannot validate new packages.
