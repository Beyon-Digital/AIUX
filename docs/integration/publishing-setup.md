# GitHub CI publishing setup

Destination: public npmjs packages under **@beyond-digital**. GitHub repository:
**Beyon-Digital/AIUX**. No local npm login is needed. Add credentials directly in
GitHub Settings → Secrets and variables → Actions; never put token values in
issues, chat, source files, workflow inputs or command-line arguments.

## First publication

Create one **granular npm access token** on npmjs.com using an account allowed
to create packages under `@beyond-digital`. Set:

- Packages and scopes: **Read and write (publish and stage)**; **Only select
  packages and scopes** → scope **@beyond-digital** (new packages do not yet
  exist to select individually).
- Organizations: **No access**. Organization-governance access does not grant
  package publishing rights.
- Enable **Bypass two-factor authentication** for unattended direct publication,
  only if your npm organization's policy permits it. Otherwise use an interactive
  bootstrap/staged-approval flow; a stage-only token cannot directly publish.
- Short expiry (for example, 7 days), then revoke after migration to OIDC.

Store it as repository Actions secret **`NPM_TOKEN`**. A classic npm token,
GitHub PAT or stage-only token will not satisfy this workflow. These choices
follow [npm's granular-token setup](https://docs.npmjs.com/creating-and-viewing-access-tokens/).
Direct-publish bypass tokens are scheduled to be removed in January 2027;
use this as bootstrap, then migrate to OIDC. [npm token policy](https://docs.npmjs.com/about-access-tokens/)

`GITHUB_TOKEN` is created automatically by Actions. The workflow grants only
`contents: write` for release publication, `actions: read` for validation evidence,
and `id-token: write` for provenance/OIDC. Its small dispatcher job uses
`actions: write` only to dispatch the same workflow on the immutable tag, keeping
provenance tied to the actual release commit. No GitHub PAT secret is needed.

## Later releases without an npm token

For each of the eight packages after first publication, open npm package
Settings → Trusted publishing and add GitHub Actions:

| Field | Value |
| --- | --- |
| Organization or user | `Beyon-Digital` |
| Repository | `AIUX` |
| Workflow filename | `publish.yml` |
| Environment | Leave blank (workflow does not declare an environment) |
| Allowed actions | Enable direct `npm publish` |

Set repository Actions variable **`NPM_AUTH_MODE=oidc`**. Dispatch a subsequent
release using auth mode `oidc`. After verifying it, remove `NPM_TOKEN` and revoke
the token in npm. Cloud-hosted runners and the workflow's Node 24/npm 12.2.0
support trusted publishing; no npm API secret is used. [npm trusted publishing](https://docs.npmjs.com/trusted-publishers/)

## Trigger and recovery

After PR review/merge and green main CI, create a new immutable tag:

```sh
git tag v0.2.0-rc.1 <green-main-commit>
git push origin v0.2.0-rc.1
```

`Release` builds native/WASM/JS artifacts from that commit, validates tarballs and
fresh native consumers, then creates a draft release with checksums. Its
successful tag run automatically dispatches **Publish packages** on that tag.
The built-in token can trigger `workflow_dispatch` without a PAT ([GitHub docs](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow)).
For the Actions UI, choose the release tag in the run selector, not `main`. Publication
requires green CI for that exact main commit, validates release checksums,
publishes in dependency order, verifies exact registry integrity and clean
consumer installation, then publishes a regular GitHub release and npm **`latest`**.
The owner approved this channel for v0.1.1 on 2026-10-03 and reported iOS/Android
simulator accessibility testing; see the [evidence limits](../renderers/accessibility.md#manual-run-throughs-performed).

After fixing credentials, rerun explicitly:

```sh
gh workflow run publish.yml -R Beyon-Digital/AIUX --ref v0.2.0-rc.1 -f release_tag=v0.2.0-rc.1 -f auth_mode=token
# After trusted publishing is configured:
gh workflow run publish.yml -R Beyon-Digital/AIUX --ref v0.2.0 -f release_tag=v0.2.0 -f auth_mode=oidc
```

Reruns skip identical already-published versions and reject mismatched bytes.
No unpublish, overwrite or automatic version bump occurs. Multi-package registry
publication is not atomic: a failure can leave an installable subset published;
the GitHub release stays draft until every exact package and install passes.
If an immutable version contains different bytes, bump all versions and create
a new tag. Preserve the old tag. Branch candidate Release runs build/upload
artifacts but do not trigger registry publication. Publication reruns must use
the tag's own workflow version (`gh workflow run publish.yml --ref <tag>`):
an older tag's asset set predates later tooling additions.

## Prerelease (RC) publications

Semver prerelease tags (`vX.Y.Z-<suffix>`, e.g. `v0.2.0-rc.1`) are accepted
everywhere `vX.Y.Z` is. Before tagging an RC, bump **every** versioned manifest
to the exact prerelease version — root `package.json`, the eight publishable
package manifests, `Cargo.toml`, both `pubspec.yaml`s and
`bridges/expo/android/build.gradle` — `release-check.mjs` requires tag ==
version across all of them. Prereleases publish to the npm **`next`** dist-tag
(consumers install `@beyond-digital/aiux-core@next` or the exact version) and
the GitHub release is marked a **prerelease**; npm `latest` and the regular
release flag stay stable-only. A successful RC tag Release run auto-dispatches
publication just like a stable tag. Promoting an RC means bumping to the stable
version and cutting a new stable tag — never re-tag or mutate the RC.

## Native destinations and credentials

Swift/XCFramework and Android Maven/AAR artifacts are published on GitHub
Releases using the automatic `GITHUB_TOKEN`. This includes an embedded local
Maven repository, not a Maven Central deployment. Rust and Flutter/Dart remain
Git/source consumers; there is no crates.io or pub.dev publication workflow.
No `CARGO_REGISTRY_TOKEN`, `PUB_*`, Maven Central credentials, Apple signing
credentials or GitHub Packages token is required for the implemented channels.
Mobile Flutter C ABI packaging, plain RN Fabric and GraphQL remain unavailable
as installable registry packages; see [installation](install.md).

## Open owner decisions

Resolved so far: MIT licensing, `@beyond-digital` scope ownership, and the
v0.1.1 stable `latest` channel (approved 2026-10-03). Still pending, none of
which this repository can configure on its own:

- **npm trusted publishing** — per-package OIDC setup on npmjs.com for all
  eight packages, then `NPM_AUTH_MODE=oidc` and `NPM_TOKEN` removal.
- **Non-npm registries** — crates.io, pub.dev and Maven Central stay
  unconfigured; enabling them needs owner accounts/credentials.
- **Mobile Flutter C ABI packaging** — iOS/Android native library bundling for
  Flutter consumers; currently Git-source only.
- **Physical-device sign-off** — simulator accessibility was reported;
  physical-device coverage remains an owner call (or a prerelease label).
