// Fail closed on immutable-version conflicts; reruns skip identical packages.
// A partial multi-package publish can be resumed, but cannot be rolled back.
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
const manifest = JSON.parse(readFileSync('dist/npm/manifest.json'));
const tag = process.env.NPM_TAG ?? 'latest';
assert.match(tag, /^[a-z][a-z0-9-]*$/);
function remote(pkg) {
  const result = spawnSync('npm', ['view', `${pkg.name}@${pkg.version}`, 'dist.integrity', '--json', '--registry=https://registry.npmjs.org'], {encoding:'utf8'});
  if (result.status === 0) return JSON.parse(result.stdout);
  // Missing exact version is safe; connectivity/auth/rate-limit failures are not.
  if (/E404/.test(result.stderr + result.stdout)) return null;
  throw new Error(`Registry preflight failed for ${pkg.name}; no publication attempted`);
}
const plans = manifest.map(pkg => {
  assert.ok(pkg.name.startsWith('@beyond-digital/'), 'unapproved scope');
  const integrity = 'sha512-' + createHash('sha512').update(readFileSync(`dist/npm/${pkg.filename}`)).digest('base64');
  const existing = remote(pkg);
  if (existing && existing !== integrity) throw new Error(`${pkg.name}@${pkg.version} already exists with different bytes; bump version, never overwrite`);
  return {...pkg,integrity,existing};
});
if (process.argv.includes('--preflight')) {
  console.log(`Registry preflight passed for ${plans.length} immutable package versions`);
  process.exit(0);
}
for (const pkg of plans) {
  if (pkg.existing) {console.log(`Skip identical ${pkg.name}@${pkg.version}`);continue;}
  execFileSync('npm', ['publish', `dist/npm/${pkg.filename}`, '--access=public', '--provenance', `--tag=${tag}`, '--registry=https://registry.npmjs.org'], {stdio:'inherit'});
}
// Registry propagation is eventually consistent. Independently compare bytes.
for (const pkg of plans) {
  let integrity;
  for (let attempt=0;attempt<6;attempt++) {
    integrity=remote(pkg);
    if(integrity) break;
    console.log(`Waiting for registry availability: ${pkg.name}`);
    await new Promise(resolve=>setTimeout(resolve,5000));
  }
  assert.equal(integrity,pkg.integrity,`published bytes: ${pkg.name}`);
}
console.log('All exact published package versions match validated release tarballs');
