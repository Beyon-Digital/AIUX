#!/usr/bin/env node
// Detects which CI lanes a push/PR actually touched and emits one boolean
// output per lane (`<lane>=true|false`) for the `detect` job to gate on.
// Unresolvable diff ranges (new branches, force pushes, missing objects)
// resolve to "everything" — a skipped lane must never hide a real break.
//
// Usage:
//   node tools/ci-changes.mjs                # resolve range from GITHUB_EVENT_PATH
//   node tools/ci-changes.mjs --base <rev>   # diff <rev>...HEAD (local/debug)
//   node tools/ci-changes.mjs --all          # force every lane true
import {execFileSync} from 'node:child_process';
import {appendFileSync, readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

const notice = msg => console.log(`::notice ::${msg.replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A')}`);

const WORKFLOWS = '.github/workflows/**';
const CARGO = ['Cargo.toml', 'Cargo.lock', 'clippy.toml', 'rustfmt.toml'];
const PNPM = ['package.json', 'pnpm-lock.yaml', 'pnpm-workspace.yaml', 'tsconfig.base.json'];

// Lane → pathspecs. Patterns are either exact paths or `<dir>/**` prefixes.
// `core/` + Cargo manifests feed every lane that builds or binds Rust code.
export const LANES = {
  proto: [
    'protocol/**',
    'conformance/fixtures/**',
    'conformance/expected/**',
    'tools/validate-protocol.mjs',
    ...PNPM,
    WORKFLOWS,
  ],
  rust: [
    'core/**',
    'benches/**',
    'conformance/**',
    'tools/git-consumers.sh',
    ...CARGO,
    WORKFLOWS,
  ],
  swift: [
    'bindings/swift/**',
    'bindings/uniffi/**',
    'renderers/swiftui/**',
    'examples/ios-native/**',
    'core/**',
    ...CARGO,
    WORKFLOWS,
  ],
  kotlin: [
    'bindings/kotlin/**',
    'bindings/uniffi/**',
    'renderers/compose/**',
    'gradle/**',
    'examples/android-native/**',
    'build.gradle.kts',
    'settings.gradle.kts',
    'gradle.properties',
    'gradlew',
    'gradlew.bat',
    'core/**',
    ...CARGO,
    WORKFLOWS,
  ],
  js: [
    'adapters/**',
    'transports/**',
    'bindings/wasm/js/**',
    'renderers/web/**',
    'bridges/**',
    'examples/**',
    'tools/**',
    'Cargo.toml', // release-check asserts Cargo version == package.json version
    ...PNPM,
    WORKFLOWS,
  ],
  web: [
    'bindings/wasm/**',
    'renderers/web/**',
    'examples/web/**',
    'core/**',
    ...CARGO,
    ...PNPM,
    WORKFLOWS,
  ],
  expo: [
    'bridges/expo/**',
    'examples/expo/**',
    'renderers/compose/**',
    'renderers/swiftui/**',
    'core/**',
    ...CARGO,
    ...PNPM,
    WORKFLOWS,
  ],
  flutter: [
    'bindings/dart/**',
    'renderers/flutter/**',
    'examples/flutter/**',
    'tools/git-consumers.sh',
    'core/**',
    ...CARGO,
    WORKFLOWS,
  ],
  conformance: [
    'conformance/**',
    'protocol/**',
    'core/**',
    ...CARGO,
    WORKFLOWS,
  ],
};

export const matchPattern = (pattern, file) =>
  pattern.endsWith('/**') ? file.startsWith(pattern.slice(0, -3) + '/') : file === pattern;

export function classify(files) {
  const out = {};
  for (const [lane, patterns] of Object.entries(LANES)) {
    out[lane] = patterns.some(p => files.some(f => matchPattern(p, f)));
  }
  return out;
}

const git = args => execFileSync('git', args, {encoding: 'utf8'}).trim();
const diff = spec => git(['diff', '--name-only', spec]).split('\n').filter(Boolean);
const hasCommit = rev => {try {git(['cat-file', '-e', `${rev}^{commit}`]); return true;} catch {return false;}};

// Returns the changed file list, or null when the range cannot be resolved
// (first push, force push, shallow history) — callers then run every lane.
export function changedFiles(event) {
  if (event.pull_request) {
    const sha = event.pull_request.base?.sha;
    if (sha && hasCommit(sha)) return diff(`${sha}...HEAD`);
    const ref = event.pull_request.base?.ref;
    if (ref) {
      git(['fetch', '--no-tags', 'origin', `+refs/heads/${ref}:refs/remotes/origin/${ref}`]);
      return diff(`origin/${ref}...HEAD`);
    }
    return null;
  }
  const before = event.before;
  if (before && !/^0+$/.test(before) && hasCommit(before)) return diff(`${before}...HEAD`);
  return null;
}

export function emit(results, {outFile = process.env.GITHUB_OUTPUT, files = null} = {}) {
  for (const [lane, hit] of Object.entries(results)) {
    if (outFile) appendFileSync(outFile, `${lane}=${hit}\n`);
    console.log(`  ${hit ? 'run ' : 'skip'} ${lane}`);
  }
  if (files) {
    const lanes = Object.keys(LANES);
    const unmatched = files.filter(f =>
      !lanes.some(l => LANES[l].some(p => matchPattern(p, f))));
    for (const f of unmatched) console.log(`  (no lane) ${f}`);
    if (unmatched.length) {
      notice(`${unmatched.length} changed file(s) match no CI lane — extend tools/ci-changes.mjs if they can break a build:\n${unmatched.join('\n')}`);
    }
  }
}

export function main(argv = process.argv.slice(2)) {
  const arg = i => argv[i + 1];
  let files = null;
  if (argv.includes('--all')) {
    files = null;
  } else if (argv.includes('--base')) {
    files = diff(`${arg(argv.indexOf('--base'))}...HEAD`);
  } else {
    const eventPath = process.env.GITHUB_EVENT_PATH;
    const event = eventPath ? JSON.parse(readFileSync(eventPath, 'utf8')) : {};
    files = changedFiles(event);
  }
  if (files === null) {
    console.log('Diff range unresolvable — running every lane.');
    emit(Object.fromEntries(Object.keys(LANES).map(l => [l, true])));
    return;
  }
  console.log(`${files.length} changed file(s):`);
  emit(classify(files), {files});
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
