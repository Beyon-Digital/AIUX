import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
const publisher = resolve('tools/publish-js.mjs');
function scenario(mode,extra=[]) {
  const dir=mkdtempSync(join(tmpdir(),'aiux-publisher-test-'));
  mkdirSync(join(dir,'dist/npm'),{recursive:true});
  const bytes=Buffer.from('validated artifact');
  const integrity='sha512-'+createHash('sha512').update(bytes).digest('base64');
  writeFileSync(join(dir,'dist/npm/one.tgz'),bytes);
  writeFileSync(join(dir,'dist/npm/manifest.json'),JSON.stringify([{name:'@beyond-digital/one',version:'0.1.1',filename:'one.tgz'}]));
  const bin=join(dir,'bin');mkdirSync(bin);
  writeFileSync(join(bin,'npm'),`#!${process.execPath}
const fs=require('node:fs');
const args=process.argv.slice(2);
fs.appendFileSync(process.env.CALLS,JSON.stringify(args)+'\\n');
if(args[0]==='view'){
 if(process.env.MODE==='different'){console.log(JSON.stringify('sha512-mismatched'));process.exit(0)}
 if(process.env.MODE==='network'){console.error('npm error code ENOTFOUND');process.exit(1)}
 if(process.env.MODE==='array'){console.log(JSON.stringify([process.env.INTEGRITY]));process.exit(0)}
 if(process.env.MODE==='ambiguous'){console.log(JSON.stringify([process.env.INTEGRITY,process.env.INTEGRITY]));process.exit(0)}
 if(process.env.MODE==='identical'||fs.existsSync(process.env.PUBLISHED)){console.log(JSON.stringify(process.env.INTEGRITY));process.exit(0)}
 console.error('npm error code E404');process.exit(1);
}
if(args[0]==='publish'){fs.writeFileSync(process.env.PUBLISHED,'yes');process.exit(0)}
process.exit(2);
`,{mode:0o755});
  const result=spawnSync(process.execPath,[publisher,...extra],{cwd:dir,encoding:'utf8',env:{...process.env,PATH:bin+':'+process.env.PATH,MODE:mode,INTEGRITY:integrity,CALLS:join(dir,'calls'),PUBLISHED:join(dir,'published')}});
  const calls=readFileSync(join(dir,'calls'),'utf8').trim().split('\n').map(JSON.parse);
  return {result,calls};
}
test('existing identical immutable version is not republished',()=>{const s=scenario('identical');assert.equal(s.result.status,0,s.result.stderr);assert.equal(s.calls.filter(c=>c[0]==='publish').length,0)});
test('different existing bytes stop before any publication',()=>{const s=scenario('different');assert.notEqual(s.result.status,0);assert.equal(s.calls.filter(c=>c[0]==='publish').length,0)});
test('network failure is never treated as an unpublished version',()=>{const s=scenario('network');assert.notEqual(s.result.status,0);assert.equal(s.calls.filter(c=>c[0]==='publish').length,0)});
test('missing version publishes once and independently checks integrity',()=>{const s=scenario('missing');assert.equal(s.result.status,0,s.result.stderr);assert.equal(s.calls.filter(c=>c[0]==='publish').length,1);assert.equal(s.calls.filter(c=>c[0]==='view').length,2)});

test('npm array integrity resolves one exact immutable version',()=>{const s=scenario('array');assert.equal(s.result.status,0,s.result.stderr);assert.equal(s.calls.filter(c=>c[0]==='publish').length,0)});
test('ambiguous npm integrity result fails before any publication',()=>{const s=scenario('ambiguous');assert.notEqual(s.result.status,0);assert.equal(s.calls.filter(c=>c[0]==='publish').length,0)});
test('verification-only mode cannot publish missing versions',()=>{const s=scenario('missing',['--verify-only']);assert.notEqual(s.result.status,0);assert.equal(s.calls.filter(c=>c[0]==='publish').length,0)});
