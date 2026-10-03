# CI and release checklist

First-party code is MIT. The approved npm scope is `@beyond-digital`; this
supersedes the original internal-only plan. The immutable v0.1.0 tag/draft is
preserved; 0.1.1 is the first installable release. See [consumer installation](install.md).

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
   explicitly labelled prerelease if those manual gates remain incomplete, unless
   the owner approves a release exception and its evidence limits are recorded.
5. Merge the reviewed PR through the normal GitHub process. Create `v0.1.1`
   at the exact green commit; tag-triggered Release builds every artifact and
   creates a draft GitHub Release with notes, manifest and SHA256SUMS.
6. Configure CI publication using [publishing setup](publishing-setup.md):
   `NPM_TOKEN` for the first release, then tokenless npm trusted publishing.
   The successful tag build triggers `publish.yml` automatically.
7. Publication checks exact-commit CI/checksums, immutable registry integrity and
   clean installs. Only then does CI publish the regular GitHub release. Credential
   failures leave the release draft and can be recovered with workflow_dispatch.
8. v0.1.1 uses npm `latest` and a regular GitHub release by explicit owner approval
   on 2026-10-03. The owner reports iOS/Android simulator accessibility testing.
   Physical-device, Flutter and specific screen-reader coverage remain unverified;
   registry installation is not proof of those manual results.

## Third-party licenses

MIT covers first-party code. `third-party-notices.mjs` preserves upstream license
and copyright files in native/WASM distributions. UniFFI remains MPL-2.0; its
unmodified source crates and license text are included alongside source URLs.
This meets the source-availability requirement described by [Mozilla](https://www.mozilla.org/en-US/MPL/2.0/FAQ/#q8-i-want-to-distribute-outside-my-organization-executable-programs-or-libraries-that-i-have-compiled-from-someone-elses-unchanged-mpl-licensed-source-code-either-standalone-or-part-of-a-larger-work-what-do-i-have-to-do).
Do not relabel upstream code as MIT or discard bundled notices.

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

## Interrupted draft uploads

Apple, Android and Rust may supply notice archives with the same basename.
`assemble-release.mjs` gives differing payloads unique names, reuses identical
bytes and writes checksums using the actual downloadable filenames.

If an upload fails after creating a draft, recover from the **original** tagged
run's artifacts; never rebuild or move the tag to replace uploaded bytes:

```sh
gh run download <original-tagged-run-id> -D original-artifacts
node tools/assemble-release.mjs original-artifacts release-assets
node tools/complete-release.mjs v0.1.1 release-assets
gh run rerun <original-tagged-run-id> --failed
```

Completion checks every existing GitHub digest before any upload, preserves
matching files and uploads only missing files. A digest mismatch stops recovery.
The failed assembly job may then be rerun; normal publication still checks the
original tag commit, CI, checksums and immutable npm integrity.
