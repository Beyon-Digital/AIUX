import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { jsPackages } from './js-packages.mjs';
import assert from 'node:assert/strict';
import { basename, resolve } from 'node:path';
const args = process.argv.slice(2);
const dir = resolve(args.find(a => !a.startsWith('--')) ?? 'dist/npm');
const tag = args.includes('--tag') ? args[args.indexOf('--tag') + 1] : null;
const manifest = JSON.parse(readFileSync(`${dir}/manifest.json`));
const expected = jsPackages.map(dir => JSON.parse(readFileSync(`${dir}/package.json`)));
assert.equal(manifest.length, expected.length, 'release package count');
manifest.forEach((p, i) => { assert.equal(p.name, expected[i].name); assert.equal(p.version, expected[i].version); assert.equal(p.filename, `${p.name.slice(1).replace('/', '-')}-${p.version}.tgz`); });
const checksums = new Map(readFileSync(`${dir}/SHA256SUMS`, 'utf8').trim().split('\n').map(line => { const [hash, path] = line.split(/\s+/); return [basename(path), hash]; }));
for (const file of ['manifest.json', 'release-manifest.json', ...manifest.map(p => p.filename)]) {
  const actual = createHash('sha256').update(readFileSync(`${dir}/${file}`)).digest('hex');
  if (actual !== checksums.get(file)) throw new Error(`Checksum mismatch/missing: ${file}`);
}
// The consolidated inventory must name the exact tag commit it was built for.
const inventory = JSON.parse(readFileSync(`${dir}/release-manifest.json`, 'utf8'));
assert.equal(inventory.schema, 'aiux-release-manifest/v1');
assert.equal(inventory.packages.length, expected.length, 'inventory package count');
if (tag) assert.equal(inventory.sourceSha, execFileSync('git', ['rev-parse', `${tag}^{commit}`], { encoding: 'utf8' }).trim(), 'inventory source SHA');
console.log('Release manifest, inventory and npm tarball checksums verified');
