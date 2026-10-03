import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {spawnSync} from 'node:child_process';
import {assemble,sha256} from './assemble-release.mjs';
function fixture({conflict=false,publicRelease=false}={}) {
 const root=mkdtempSync(join(tmpdir(),'aiux-draft-')),input=join(root,'input'),out=join(root,'out'),bin=join(root,'bin');
 mkdirSync(input);mkdirSync(bin);writeFileSync(join(input,'a.tgz'),'old');writeFileSync(join(input,'b.tgz'),'new');assemble(input,out);
 const state=join(root,'state.json');writeFileSync(state,JSON.stringify({id:1,tag_name:'v0.1.1',draft:!publicRelease,assets:[{name:'a.tgz',digest:conflict?'sha256:wrong':`sha256:${sha256(join(out,'a.tgz'))}`}]}));
 writeFileSync(join(bin,'gh'),`#!/usr/bin/env node
const fs=require('fs'),crypto=require('crypto'),path=require('path'),a=process.argv.slice(2),p=process.env.STATE,s=JSON.parse(fs.readFileSync(p));
if(a[0]==='repo') console.log(JSON.stringify({nameWithOwner:'owner/repo'}));
else if(a[0]==='release'&&a[1]==='view') console.log(JSON.stringify({databaseId:1}));
else if(a[0]==='api') {if(a[1]!=='repos/owner/repo/releases/1') throw Error('Draft must use ID endpoint');console.log(JSON.stringify(s));}
else if(a[0]==='release'&&a[1]==='upload') {const name=path.basename(a[3]);if(s.assets.some(x=>x.name===name))throw Error('overwrite attempted');s.assets.push({name,digest:'sha256:'+crypto.createHash('sha256').update(fs.readFileSync(a[3])).digest('hex')});fs.writeFileSync(p,JSON.stringify(s));}
else throw Error('Unexpected gh command');
`,{mode:0o755});
 const result=spawnSync(process.execPath,[resolve('tools/complete-release.mjs'),'v0.1.1',out],{encoding:'utf8',env:{...process.env,STATE:state,PATH:`${bin}:${process.env.PATH}`}});
 return{result,state:JSON.parse(readFileSync(state))};
}
test('partial draft completion preserves bytes and verifies all missing uploads',()=>{const {result,state}=fixture();assert.equal(result.status,0,result.stderr);assert.equal(state.assets.length,3);});
test('existing conflicting asset stops before any upload',()=>{const {result,state}=fixture({conflict:true});assert.notEqual(result.status,0);assert.match(result.stderr,/immutable asset differs/);assert.equal(state.assets.length,1);});
test('public release cannot receive missing assets',()=>{const {result,state}=fixture({publicRelease:true});assert.notEqual(result.status,0);assert.match(result.stderr,/may not receive missing assets/);assert.equal(state.assets.length,1);});
