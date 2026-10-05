import {test, beforeEach, afterEach} from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';

import {LANES, matchPattern, classify, changedFiles} from './ci-changes.mjs';

const TOOL = fileURLToPath(new URL('./ci-changes.mjs', import.meta.url));
const git = (dir, args) => execFileSync('git', args, {cwd: dir, encoding: 'utf8'}).trim();
const seed = (dir, file, text = 'x') => {
  const path = join(dir, file);
  mkdirSync(join(path, '..'), {recursive: true});
  writeFileSync(path, text);
};

let dir;
let saved;
beforeEach(() => {
  saved = {cwd: process.cwd(), ev: process.env.GITHUB_EVENT_PATH, out: process.env.GITHUB_OUTPUT};
  dir = mkdtempSync(join(tmpdir(), 'aiux-ci-changes-'));
  git(dir, ['init', '-q']);
  git(dir, ['config', 'user.email', 't@t']);
  git(dir, ['config', 'user.name', 't']);
  process.chdir(dir);
});
afterEach(() => {
  process.chdir(saved.cwd);
  process.env.GITHUB_EVENT_PATH = saved.ev;
  process.env.GITHUB_OUTPUT = saved.out;
  rmSync(dir, {recursive: true, force: true});
});

const commit = (files) => {
  for (const [f, t] of Object.entries(files)) seed(dir, f, t);
  git(dir, ['add', '-A']);
  git(dir, ['commit', '-qm', 'c']);
  return git(dir, ['rev-parse', 'HEAD']);
};
const eventPath = (event) => {
  const p = join(dir, 'event.json');
  writeFileSync(p, JSON.stringify(event));
  return p;
};

test('matchPattern: exact + dir prefix only', () => {
  assert.equal(matchPattern('adapters/**', 'adapters/sse/index.ts'), true);
  assert.equal(matchPattern('adapters/**', 'adaptersx/sse'), false);
  assert.equal(matchPattern('Cargo.toml', 'Cargo.toml'), true);
  assert.equal(matchPattern('Cargo.toml', 'x/Cargo.toml'), false);
});

test('classify: docs-only change runs nothing', () => {
  const r = classify(['docs/integration/install.md', 'TASKS.md']);
  assert.deepEqual(Object.values(r).every(v => v === false), true);
});

test('classify: core change fans out to rust-derived lanes', () => {
  const r = classify(['core/rust/protocol/src/lib.rs']);
  for (const lane of ['rust', 'swift', 'kotlin', 'web', 'expo', 'flutter', 'conformance']) {
    assert.equal(r[lane], true, lane);
  }
  assert.equal(r.proto, false);
  assert.equal(r.js, false);
});

test('classify: workspace manifests hit the JS lanes', () => {
  const r = classify(['package.json', 'pnpm-lock.yaml']);
  for (const lane of ['js', 'web', 'expo', 'proto']) assert.equal(r[lane], true, lane);
  assert.equal(r.rust, false);
  assert.equal(r.flutter, false);
});

test('classify: every lane has a matching file and CI edits run everything', () => {
  const probes = {
    proto: 'protocol/events/x.json', rust: 'core/rust/src/x.rs',
    swift: 'bindings/swift/x.swift', kotlin: 'bindings/kotlin/x.gradle',
    js: 'adapters/sse/x.ts', web: 'bindings/wasm/x.rs', expo: 'bridges/expo/src/x.ts',
    flutter: 'bindings/dart/x.dart', conformance: 'conformance/fixtures/x.json',
  };
  for (const [lane, file] of Object.entries(probes)) {
    assert.equal(classify([file])[lane], true, `${lane} probe ${file}`);
  }
  const ci = classify(['.github/workflows/ci.yml']);
  assert.deepEqual(Object.values(ci).every(Boolean), true);
});

test('changedFiles: push event diffs before..HEAD; zero before → null', () => {
  const a = commit({'docs/a.md': 'a'});
  const b = commit({'core/rust/x.rs': 'rs'});
  process.env.GITHUB_EVENT_PATH = eventPath({before: a, after: b});
  assert.deepEqual(changedFiles({before: a}), ['core/rust/x.rs']);
  process.env.GITHUB_EVENT_PATH = eventPath({before: '0'.repeat(40)});
  assert.equal(changedFiles({before: '0'.repeat(40)}), null);
});

test('changedFiles: pull_request diffs base sha..HEAD', () => {
  const base = commit({'docs/a.md': 'a'});
  commit({'renderers/flutter/lib/x.dart': 'd'});
  const ev = {pull_request: {base: {sha: base, ref: 'main'}}};
  assert.deepEqual(changedFiles(ev), ['renderers/flutter/lib/x.dart']);
});

test('CLI --all emits every lane true to GITHUB_OUTPUT', () => {
  commit({'docs/a.md': 'a'});
  const out = join(dir, 'out.txt');
  process.env.GITHUB_OUTPUT = out;
  execFileSync('node', [TOOL, '--all'], {cwd: dir, encoding: 'utf8'});
  const lines = readFileSync(out, 'utf8').trim().split('\n');
  for (const lane of Object.keys(LANES)) assert.ok(lines.includes(`${lane}=true`), lane);
});
