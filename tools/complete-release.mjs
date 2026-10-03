// Repair a partial draft using original CI bytes; never replace existing assets.
import {execFileSync} from 'node:child_process';
import {readFileSync, readdirSync} from 'node:fs';
import {join} from 'node:path';
import assert from 'node:assert/strict';
import {sha256} from './assemble-release.mjs';
const [tag,dir]=process.argv.slice(2);
assert.match(tag??'',/^v\d+\.\d+\.\d+$/);
const gh=args=>execFileSync('gh',args,{encoding:'utf8'}).trim();
const repository=JSON.parse(gh(['repo','view','--json','nameWithOwner'])).nameWithOwner;
// GitHub's by-tag endpoint hides drafts; the CLI resolves drafts from listings.
const id=JSON.parse(gh(['release','view',tag,'--json','databaseId'])).databaseId;
const release=JSON.parse(gh(['api',`repos/${repository}/releases/${id}`]));
assert.equal(release.tag_name,tag);
const files=readdirSync(dir).sort();
// Preflight all existing files before any write. GitHub digests attest uploaded bytes.
for(const name of files) {
  const old=release.assets.find(a=>a.name===name);
  if(old) assert.equal(old.digest,`sha256:${sha256(join(dir,name))}`,`Existing immutable asset differs: ${name}`);
}
if(!release.draft) {
  assert.ok(files.every(name=>release.assets.some(a=>a.name===name)),'Public releases may not receive missing assets');
  console.log('Preserve complete immutable public release'); process.exit(0);
}
const sums=new Map(readFileSync(join(dir,'SHA256SUMS'),'utf8').trim().split('\n').map(s=>{const [hash,name]=s.split(/\s+/);return[name,hash];}));
for(const name of files.filter(n=>n!=='SHA256SUMS')) assert.equal(sha256(join(dir,name)),sums.get(name),`Checksum: ${name}`);
for(const name of files) {
  if(release.assets.some(a=>a.name===name)) {console.log(`Preserve identical ${name}`);continue;}
  gh(['release','upload',tag,join(dir,name)]); console.log(`Uploaded missing ${name}`);
}
const complete=JSON.parse(gh(['api',`repos/${repository}/releases/${id}`]));
for(const name of files) assert.equal(complete.assets.find(a=>a.name===name)?.digest,`sha256:${sha256(join(dir,name))}`,`Final asset: ${name}`);
console.log('All draft assets independently match original CI bytes');
