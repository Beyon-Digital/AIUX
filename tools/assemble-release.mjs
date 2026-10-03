// Flatten CI artifacts into unique, downloadable asset names and checksums.
import {readdirSync, readFileSync, mkdirSync, copyFileSync, writeFileSync} from 'node:fs';
import {join, basename, relative, resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
export const sha256 = path => createHash('sha256').update(readFileSync(path)).digest('hex');
export function assemble(input, output) {
  mkdirSync(output, {recursive:true});
  if (readdirSync(output).length) throw new Error('Asset output must be empty');
  const files=[];
  function walk(dir) { for(const entry of readdirSync(dir,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name,'en'))) { const path=join(dir,entry.name); if(entry.isDirectory()) walk(path); else if(entry.isFile()) files.push(path); else throw new Error(`Unsupported artifact entry: ${path}`); } }
  walk(input);
  const assets=new Map();
  for(const path of files) {
    const hash=sha256(path), name=basename(path);
    let target=name;
    if(assets.has(target)) {
      if([...assets.values()].includes(hash)) continue;
      target=relative(input,path).split(/[\\/]/).join('-');
      if(assets.has(target)) throw new Error(`Conflicting asset name: ${target}`);
    }
    copyFileSync(path,join(output,target)); assets.set(target,hash);
  }
  writeFileSync(join(output,'SHA256SUMS'), [...assets].sort(([a],[b])=>a.localeCompare(b,'en')).map(([name,hash])=>`${hash}  ${name}\n`).join(''));
  return assets;
}
if(process.argv[1] && import.meta.url===pathToFileURL(resolve(process.argv[1])).href) console.log(`Assembled ${assemble(process.argv[2]??'release',process.argv[3]??'release-assets').size} unique release assets`);
