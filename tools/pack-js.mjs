import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { jsPackages } from './js-packages.mjs';
execFileSync(process.execPath, ['tools/release-check.mjs'], { stdio: 'inherit' });
const output = resolve(process.argv.slice(2).find(a => !a.startsWith('--')) ?? 'dist/npm');
mkdirSync(output, { recursive: true });
const manifest = [];
for (const dir of jsPackages.filter(p => !process.argv.includes('--js-only') || p !== 'bridges/expo')) {
  // pnpm pack, unlike npm pack, resolves workspace:* into publishable versions.
  execFileSync('pnpm', ['--dir', dir, 'pack', '--pack-destination', output], { stdio: 'inherit' });
  const pkg = JSON.parse(readFileSync(`${dir}/package.json`));
  const filename = `${pkg.name.slice(1).replace('/', '-')}-${pkg.version}.tgz`;
  const list = execFileSync('tar', ['-tzf', resolve(output, filename)], { encoding: 'utf8' }).split('\n');
  const targets = [pkg.main, pkg.types, ...Object.values(pkg.exports).flatMap(v => typeof v === 'string' ? [v] : Object.values(v))];
  for (const target of targets) if (!list.includes('package/' + target.replace(/^\.\//, ''))) throw new Error(`${pkg.name}: missing ${target}`);
  const packed = JSON.parse(execFileSync('tar', ['-xOzf', resolve(output, filename), 'package/package.json'], { encoding: 'utf8' }));
  if (JSON.stringify(packed).includes('workspace:')) throw new Error(`${pkg.name}: unresolved workspace dependency`);
  if (['bindings/wasm/js','bridges/expo'].includes(dir) && !list.includes('package/LICENSES/manifest.json')) throw new Error(`${pkg.name}: missing third-party notices`);
  if (!list.includes('package/LICENSE')) throw new Error(`${pkg.name}: missing license`);
  if (dir === 'bridges/expo') for (const target of ['ios/vendor/AIUXCore.xcframework/Info.plist', 'ios/vendor/staged/AIUXCore/AIUXCore.swift', 'android/vendor/maven/in/beyondigital/aiux/bindings/' + pkg.version + '/bindings-' + pkg.version + '.aar', 'android/vendor/maven/in/beyondigital/aiux/compose/' + pkg.version + '/compose-' + pkg.version + '.pom']) {
    if (!list.includes('package/' + target)) throw new Error(`Expo native asset missing: ${target}`);
  }
  manifest.push({ name: pkg.name, version: pkg.version, filename });
}
writeFileSync(resolve(output, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log('All tarball exports, workspace dependencies, licenses and Expo native assets verified');
