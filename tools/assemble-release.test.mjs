import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,readdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {assemble,sha256} from './assemble-release.mjs';
test('duplicate platform notice names preserve distinct bytes and reuse identical bytes',()=>{
 const root=mkdtempSync(join(tmpdir(),'aiux-assets-')),input=join(root,'input'),output=join(root,'out');
 for(const [name,bytes] of [['android-artifacts','android'],['apple-artifacts','apple'],['rust-targets','apple']]) {mkdirSync(join(input,name),{recursive:true});writeFileSync(join(input,name,'aiux-third-party.tar.gz'),bytes);}
 const assets=assemble(input,output);
 assert.equal(assets.size,2);
 assert.equal(readFileSync(join(output,'aiux-third-party.tar.gz'),'utf8'),'android');
 assert.equal(readFileSync(join(output,'apple-artifacts-aiux-third-party.tar.gz'),'utf8'),'apple');
 for(const line of readFileSync(join(output,'SHA256SUMS'),'utf8').trim().split('\n')) {const [hash,name]=line.split(/\s+/);assert.equal(hash,sha256(join(output,name)));}
 assert.throws(()=>assemble(input,output),/must be empty/);
 assert.equal(readdirSync(output).length,3);
});
