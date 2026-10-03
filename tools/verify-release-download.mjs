import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { basename, resolve } from 'node:path';
const dir = resolve(process.argv[2] ?? 'dist/npm');
const manifest = JSON.parse(readFileSync(`${dir}/manifest.json`));
const checksums = new Map(readFileSync(`${dir}/SHA256SUMS`, 'utf8').trim().split('\n').map(line => { const [hash, path] = line.split(/\s+/); return [basename(path), hash]; }));
for (const file of ['manifest.json', ...manifest.map(p => p.filename)]) {
  const actual = createHash('sha256').update(readFileSync(`${dir}/${file}`)).digest('hex');
  if (actual !== checksums.get(file)) throw new Error(`Checksum mismatch/missing: ${file}`);
}
console.log('Release manifest and npm tarball checksums verified');
