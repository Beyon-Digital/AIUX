// Consolidated release inventory: one deterministic manifest listing every
// release asset, its sha256 and its distribution channel. Runs on the
// assembled asset directory AFTER assemble-release.mjs, then appends its own
// line to SHA256SUMS so the manifest is itself checksummed and uploaded.
//
// Determinism is a hard requirement: recovery workflows regenerate this file
// and complete-release.mjs rejects byte changes on uploaded assets. No
// timestamps, no host-specific data, source SHA resolved from the tag.
//
// Usage: node tools/release-manifest.mjs <assets-dir> <tag>
import { readFileSync, readdirSync, writeFileSync, appendFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { sha256 } from './assemble-release.mjs';
import { jsPackages } from './js-packages.mjs';

export const TAG_RE = /^v\d+\.\d+\.\d+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/;
export const MANIFEST_FILE = 'release-manifest.json';

export function build(assetsDir, tag, sourceSha) {
  assert.match(tag ?? '', TAG_RE, `tag must be vX.Y.Z or vX.Y.Z-<prerelease>: ${tag}`);
  assert.match(sourceSha ?? '', /^[0-9a-f]{40}$/, 'exact source SHA required');
  const version = tag.slice(1);
  const npmManifest = JSON.parse(readFileSync(join(assetsDir, 'manifest.json'), 'utf8'));
  // Every file that will be uploaded, except the manifest itself (a file
  // cannot hash its own contents) and SHA256SUMS (its bytes change when the
  // manifest line is appended — including it would make regeneration
  // non-deterministic; every entry inside it is already listed here).
  const assets = readdirSync(assetsDir, { withFileTypes: true })
    .filter(e => e.isFile() && e.name !== MANIFEST_FILE && e.name !== 'SHA256SUMS')
    .map(e => e.name)
    .sort((a, b) => a.localeCompare(b, 'en'))
    .map(name => ({ file: name, sha256: sha256(join(assetsDir, name)) }));
  const byName = new Map(assets.map(a => [a.file, a.sha256]));
  const packages = npmManifest.map(p => {
    assert.ok(byName.has(p.filename), `npm tarball missing from assets: ${p.filename}`);
    return { name: p.name, version: p.version, file: p.filename, sha256: byName.get(p.filename), channel: 'npm:@beyond-digital' };
  });
  const expected = jsPackages.map(dir => JSON.parse(readFileSync(join(dir, 'package.json'), 'utf8')).name);
  assert.deepEqual(packages.map(p => p.name), expected, 'manifest must cover the publication allowlist in dependency order');
  return {
    schema: 'aiux-release-manifest/v1',
    version,
    tag,
    sourceSha,
    prerelease: version.includes('-'),
    packages,
    assets,
    gitChannels: [
      { package: 'aiux-session (Rust core)', spec: `git tag ${tag}` },
      { package: 'aiux_ffi (Dart bindings)', spec: `git ref ${tag} path bindings/dart` },
      { package: 'beyond_aiux (Flutter renderer)', spec: `git ref ${tag} path renderers/flutter` },
    ],
  };
}

export function write(assetsDir, tag) {
  const sourceSha = execFileSync('git', ['rev-parse', `${tag}^{commit}`], { encoding: 'utf8' }).trim();
  const manifest = build(assetsDir, tag, sourceSha);
  const path = join(assetsDir, MANIFEST_FILE);
  writeFileSync(path, JSON.stringify(manifest, null, 2) + '\n');
  const sumsPath = join(assetsDir, 'SHA256SUMS');
  const line = `${sha256(path)}  ${MANIFEST_FILE}\n`;
  if (!existsSync(sumsPath)) throw new Error('SHA256SUMS must exist before the manifest is emitted');
  if (!readFileSync(sumsPath, 'utf8').split('\n').some(l => l.endsWith(`  ${MANIFEST_FILE}`))) appendFileSync(sumsPath, line);
  return manifest;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const [assetsDir, tag] = process.argv.slice(2);
  if (!assetsDir || !tag) throw new Error('Usage: release-manifest.mjs <assets-dir> <tag>');
  const manifest = write(assetsDir, tag);
  console.log(`${MANIFEST_FILE}: ${manifest.packages.length} npm packages, ${manifest.assets.length} assets, sha ${manifest.sourceSha.slice(0, 12)}${manifest.prerelease ? ' (prerelease)' : ''}`);
}
