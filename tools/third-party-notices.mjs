// Preserve upstream license/copyright files and MPL sources in redistributed
// Rust binaries. MIT applies to AIUX's first-party code, not third-party code.
import { execFileSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
const metadata = process.argv[2] ? JSON.parse(readFileSync(process.argv[2])) : JSON.parse(execFileSync('cargo', ['metadata', '--locked', '--format-version', '1'], {encoding:'utf8'}));
const output = resolve('dist/third-party');
rmSync(output, {recursive:true,force:true}); mkdirSync(output, {recursive:true});
const entries=[];
for (const pkg of metadata.packages.filter(p => p.source)) {
  const source=dirname(pkg.manifest_path), name=`${pkg.name}-${pkg.version}`;
  const dest=resolve(output,name); mkdirSync(dest,{recursive:true});
  const notices=readdirSync(source).filter(n => /^(licen[cs]e|copying|notice)/i.test(n));
  for(const n of notices) cpSync(resolve(source,n),resolve(dest,n),{recursive:true});
  if(pkg.license_file && existsSync(resolve(source,pkg.license_file))) cpSync(resolve(source,pkg.license_file),resolve(dest,'LICENSE-FILE'),{recursive:true});
  // UniFFI is unmodified MPL-2.0. Include its complete published crate source,
  // preserving existing notices, so recipients need not rely on external URLs.
  if(pkg.license?.includes('MPL-2.0') || (!notices.length && !pkg.license_file)) cpSync(source,resolve(dest,'source'),{recursive:true});
  if(pkg.license?.includes('MPL-2.0')) cpSync('tools/licenses/MPL-2.0.txt',resolve(dest,'LICENSE-MPL-2.0'));
  entries.push({name:pkg.name,version:pkg.version,license:pkg.license,source:`https://crates.io/api/v1/crates/${pkg.name}/${pkg.version}/download`});
}
writeFileSync(resolve(output,'manifest.json'),JSON.stringify(entries,null,2)+'\n');
writeFileSync(resolve(output,'README.md'),'# Third-party software\n\nAIUX first-party code is MIT. Upstream code retains the licenses in manifest.json and per-crate directories. Sources for unmodified MPL-2.0 UniFFI and crates without separate root license files are included in source/ subdirectories; exact source archive URLs are recorded in manifest.json. Other upstream license and copyright notices are copied unchanged.\n');
for(const dir of ['bindings/wasm/js','bridges/expo']) {rmSync(`${dir}/LICENSES`,{recursive:true,force:true});cpSync(output,`${dir}/LICENSES`,{recursive:true});}
execFileSync('tar',['-czf','dist/aiux-third-party.tar.gz','-C','dist','third-party']);
console.log(`Preserved notices for ${entries.length} third-party crates, including MPL source`);
