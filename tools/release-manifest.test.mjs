// Deterministic release-manifest emission: stable bytes, self-checksummed,
// prerelease-aware, and strict about the publication allowlist.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { chdir } from 'node:process';
import { build, write, MANIFEST_FILE } from './release-manifest.mjs';
import { jsPackages } from './js-packages.mjs';
import { sha256 } from './assemble-release.mjs';

const repoRoot = new URL('..', import.meta.url).pathname;
const SHA = 'a'.repeat(40);

function fixture() {
  const dir = mkdtempSync(join(tmpdir(), 'aiux-relmanifest-'));
  mkdirSync(dir, { recursive: true });
  const names = ['aiux-swift-package.tar.gz', 'aiux-android-maven.tar.gz', 'AIUXCore.xcframework.zip', 'SHA256SUMS', 'manifest.json'];
  const pkgs = jsPackages.map((dir, i) => {
    const pkg = JSON.parse(readFileSync(join(repoRoot, dir, 'package.json'), 'utf8'));
    return { name: pkg.name, version: pkg.version, filename: `${pkg.name.slice(1).replace('/', '-')}-${pkg.version}.tgz` };
  });
  for (const p of pkgs) names.push(p.filename);
  for (const n of names) if (n !== 'manifest.json') writeFileSync(join(dir, n), `bytes-of-${n}`);
  writeFileSync(join(dir, 'manifest.json'), JSON.stringify(pkgs));
  return { dir, pkgs };
}

test('manifest covers every asset, npm package and git channel deterministically', () => {
  const cwd = process.cwd();
  chdir(repoRoot);
  try {
    const { dir, pkgs } = fixture();
    const a = build(dir, 'v9.9.9', SHA);
    const b = build(dir, 'v9.9.9', SHA);
    assert.deepEqual(a, b, 'same inputs must produce identical manifest objects');
    assert.equal(a.schema, 'aiux-release-manifest/v1');
    assert.equal(a.version, '9.9.9');
    assert.equal(a.prerelease, false);
    assert.equal(a.sourceSha, SHA);
    assert.equal(a.packages.length, pkgs.length);
    assert.deepEqual(a.packages.map(p => p.name), pkgs.map(p => p.name));
    for (const p of a.packages) assert.equal(p.sha256, sha256(join(dir, p.file)));
    const files = a.assets.map(x => x.file);
    assert.ok(files.includes('manifest.json') && files.includes('aiux-swift-package.tar.gz'));
    assert.ok(!files.includes(MANIFEST_FILE), 'a manifest cannot hash itself');
    assert.ok(!files.includes('SHA256SUMS'), 'SHA256SUMS mutates on manifest append — excluded for determinism');
    assert.equal(a.gitChannels.length, 3);
  } finally { chdir(cwd); }
});

test('prerelease tags mark the manifest without changing shape', () => {
  const cwd = process.cwd();
  chdir(repoRoot);
  try {
    const { dir } = fixture();
    const m = build(dir, 'v9.9.9-rc.1', SHA);
    assert.equal(m.prerelease, true);
    assert.equal(m.tag, 'v9.9.9-rc.1');
    assert.throws(() => build(dir, 'v9.9', SHA), /tag must be/);
    assert.throws(() => build(dir, 'release-9', SHA), /tag must be/);
    assert.throws(() => build(dir, 'v9.9.9', 'notasha'), /exact source SHA/);
  } finally { chdir(cwd); }
});

test('write() emits the manifest and self-checksums into SHA256SUMS once', () => {
  const cwd = process.cwd();
  chdir(repoRoot);
  try {
    const { dir } = fixture();
    const tag = 'v0.1.1';
    const m = write(dir, tag);
    const path = join(dir, MANIFEST_FILE);
    assert.ok(existsSync(path));
    const parsed = JSON.parse(readFileSync(path, 'utf8'));
    assert.equal(parsed.tag, tag);
    assert.equal(parsed.sourceSha.length, 40);
    const sums = readFileSync(join(dir, 'SHA256SUMS'), 'utf8');
    assert.ok(sums.includes(`${sha256(path)}  ${MANIFEST_FILE}`));
    write(dir, tag);
    const again = readFileSync(join(dir, 'SHA256SUMS'), 'utf8');
    assert.equal(again.split('\n').filter(l => l.endsWith(`  ${MANIFEST_FILE}`)).length, 1, 'idempotent');
    assert.deepEqual(JSON.parse(readFileSync(path, 'utf8')), parsed, 'regeneration is byte-stable');
  } finally { chdir(cwd); }
});
