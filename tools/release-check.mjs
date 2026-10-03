import { readFileSync, existsSync } from 'node:fs';
import assert from 'node:assert/strict';
import { jsPackages } from './js-packages.mjs';
const version = JSON.parse(readFileSync('package.json')).version;
if (process.argv[2]) assert.equal(process.argv[2], `v${version}`, 'tag must match package version');
for (const dir of jsPackages) {
  const pkg = JSON.parse(readFileSync(`${dir}/package.json`));
  assert.equal(pkg.version, version, dir);
  assert.equal(pkg.license, 'MIT', dir);
  assert.notEqual(pkg.private, true, dir);
  assert.ok(pkg.repository.directory === dir, `repository association: ${dir}`);
  assert.ok(existsSync(`${dir}/LICENSE`), dir);
  for (const script of ['build', 'test', 'typecheck']) assert.ok(pkg.scripts[script] && !pkg.scripts[script].startsWith('echo'), `${dir}: no placeholder ${script}`);
}
for (const file of ['Cargo.toml', 'bindings/dart/pubspec.yaml', 'renderers/flutter/pubspec.yaml', 'bridges/expo/android/build.gradle']) {
  assert.ok(readFileSync(file, 'utf8').includes(version), `${file}: version mismatch`);
}
assert.ok(readFileSync('LICENSE', 'utf8').startsWith('MIT License'));
console.log(`Release ${version}: ${jsPackages.length} implemented JS packages; metadata gates pass`);
