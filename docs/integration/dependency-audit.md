# Dependency Audit — v0.1.0 baseline

Phase 8 deliverable: `cargo audit`, `pnpm audit`, and the Gradle equivalent,
run against the `devin/integration` tree on 2026-10-02. Re-run per release;
CI gating is a follow-up (see "Automating").

## Rust — `cargo audit`

```
Loaded 1279 security advisories
Scanning Cargo.lock for vulnerabilities (156 crate dependencies)
→ clean: 0 vulnerabilities, 0 warnings
```

## JS — `pnpm audit`

Baseline: **6 advisories → fixed 4, documented 2.**

| Advisory | Severity | Action |
|----------|----------|--------|
| vitest <3.2.6 — arbitrary file read/exec via Vitest UI server (GHSA) | critical | **fixed**: `vitest ^3.2.4/3.2.4 → ^4.1.11` across 8 workspace packages (also clears the @vitest/mocker path-traversal, patched only in ≥4.1.11) |
| @vitest/mocker <4.1.11 — path traversal / file read via redirect mock | moderate | **fixed** (same bump) |
| vitest — mocker redirect mock (same GHSA) | moderate | **fixed** (same bump) |
| ajv 8.17.1 — ReDoS via `$data` | moderate | **fixed**: direct devDep pin `8.17.1 → 8.20.0` (5 packages) |
| uuid 7.0.3 — missing bounds check when `buf` provided | moderate | **documented**: transitive via `xcode@3.0.1` ← `@expo/config-plugins` — Expo *build tooling* only, never in shipped runtime; requires upstream Expo bump |
| node-forge 1.4.0 — PKCS#1 v1.5 verification accepts nested DigestAlg | high | **documented — unpatched upstream** (`patched: None`): transitive via `@expo/cli` — dev-server/build tooling only; track Expo SDK updates; no fix available to apply |

Remaining: `2 advisories (1 moderate, 1 high)` — both Expo-tooling
transitives outside the shipped artifact boundary.

## Gradle — dependency inventory + known-CVE check

`./gradlew :renderers:compose:dependencies :bindings:kotlin:dependencies
--configuration releaseRuntimeClasspath`

Runtime classpath is deliberately tiny: `kotlin-stdlib 2.0.20`,
`jna 5.18.0` (bindings), Compose BOM + `kotlinx-coroutines-core 1.7.3`
(renderer), `protobuf-java 3.25.5` + Android UTP libs (test platform only).
No known advisories against these coordinates at audit time.

The real Gradle CVE gate is OWASP dependency-check — it requires an NVD API
key (`NVD_API_KEY` env), so it is not wired into CI. To run it manually:

```bash
./gradlew dependencyCheckAnalyze \
  -PdependencyCheck.nvd.apiKey=$NVD_API_KEY   # after adding the
                                            # org.owasp.dependencycheck plugin
```

## Automating (follow-up, not blocking v0.1)

- `cargo audit` → add a CI step (`rustsec/audit-check@v2`) in `ci.yml`.
- `pnpm audit --audit-level=high` → cheap CI step; currently fails on the
  documented Expo transitives, so either gate at `--audit-level=critical`
  or add an allowlist when pnpm's `--ignore` lands.
- Gradle → wire OWASP dependency-check when an `NVD_API_KEY` secret exists.

## Policy going forward

- New advisories on **shipped** dependencies are release blockers;
  advisories confined to dev-tooling transitives are documented here with
  the upgrade path.
- New direct deps: pin an exact version ≥7 days old (supply-chain rule);
  no floating `latest`/`*`.
