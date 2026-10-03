// Install tarballs in an isolated npm consumer, never through workspace links.
// --registry installs the exact published versions instead, for post-publish proof.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
const manifest = JSON.parse(readFileSync('dist/npm/manifest.json'));
const hasExpo = manifest.some(p => p.name.endsWith('/aiux-expo'));
const dir = mkdtempSync(join(tmpdir(), 'aiux-consumer-'));
const packages = Object.fromEntries(manifest.map(p => [p.name, process.argv.includes('--registry') ? p.version : `file:${resolve('dist/npm', p.filename)}`]));
writeFileSync(join(dir, 'package.json'), JSON.stringify({ private: true, type: 'module', dependencies: { ...packages, react: '19.2.3', 'react-dom': '19.2.3', ...(hasExpo ? {expo: '57.0.0', 'react-native': '0.86.0'} : {}), typescript: '5.9.2', '@types/react': '^19.2.2', '@types/node': '22.20.4', vite: '^7.1.0' } }, null, 2));
const run = (cmd, args) => execFileSync(cmd, args, { cwd: dir, stdio: 'inherit', env: {...process.env, npm_config_cache: join(dir, '.npm-cache'), npm_config_userconfig: join(dir, '.npmrc')} });
run('npm', ['install', '--ignore-scripts', '--no-audit', '--no-fund', '--registry=https://registry.npmjs.org']);
writeFileSync(join(dir, 'smoke.mjs'), `
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { AiuxSession, wasmCore } from '@beyond-digital/aiux-core';
import { EventBuffer } from '@beyond-digital/aiux-core/buffer';
import init, * as wasm from '@beyond-digital/aiux-core/wasm';
import { AIConversation } from '@beyond-digital/aiux-web';
import { createElement } from 'react';
import { renderToString } from 'react-dom/server';
await init({ module_or_path: readFileSync(import.meta.resolve('@beyond-digital/aiux-core/wasm/aiux_wasm_bg.wasm').replace('file://', '')) });
const session = AiuxSession.create(wasmCore(wasm), '{}');
assert.ok(session.snapshot());
assert.equal(typeof session.serialize(), 'string');
assert.ok(renderToString(createElement(AIConversation, {session})).includes('aiux'));
session.reset(); session.dispose();
assert.equal(typeof EventBuffer, 'function');
assert.equal(typeof AIConversation, 'function');
for (const name of ['aiux-protocol-types','aiux-transport-js','aiux-adapter-sse','aiux-adapter-websocket','aiux-adapter-ai-sdk']) await import('@beyond-digital/' + name);
console.log('Real packaged WASM lifecycle, buffer export, renderer and adapter imports passed');
`);
run('node', ['smoke.mjs']);
writeFileSync(join(dir, 'check.tsx'), `
import { AiuxSession, wasmCore } from '@beyond-digital/aiux-core';
import { EventBuffer } from '@beyond-digital/aiux-core/buffer';
import { AIConversation as Web } from '@beyond-digital/aiux-web';
${hasExpo ? "import { AIConversation as Native, createAIUXTransport } from '@beyond-digital/aiux-expo';" : ''}
import { createSseAdapter } from '@beyond-digital/aiux-adapter-sse';
void [AiuxSession, wasmCore, EventBuffer, Web, ${hasExpo ? 'Native, createAIUXTransport,' : ''} createSseAdapter];
`);
writeFileSync(join(dir, 'tsconfig.json'), JSON.stringify({ compilerOptions: { target: 'ES2022', module: 'NodeNext', moduleResolution: 'NodeNext', strict: true, jsx: 'react-jsx', skipLibCheck: true, noEmit: true }, include: ['check.tsx'] }));
run('npx', ['tsc']);
writeFileSync(join(dir, 'index.html'), '<div id="root"></div><script type="module" src="/main.tsx"></script>');
writeFileSync(join(dir, 'main.tsx'), `import {AIConversation} from '@beyond-digital/aiux-web'; import '@beyond-digital/aiux-web/styles.css'; import init from '@beyond-digital/aiux-core/wasm'; import url from '@beyond-digital/aiux-core/wasm/aiux_wasm_bg.wasm?url'; console.log(AIConversation); await init({module_or_path:url});`);
run('npx', ['vite', 'build', '--target=esnext']);
writeFileSync('dist/consumer-path.txt', dir);
console.log('Clean consumer NodeNext declarations + Vite WASM/CSS build passed:', dir);

if (process.argv.includes('--native')) {
  const platform = process.platform === 'darwin' ? 'ios' : 'android';
  writeFileSync(join(dir, 'app.json'), JSON.stringify({expo:{name:'AIUXConsumer',slug:'aiux-consumer',newArchEnabled:true,ios:{bundleIdentifier:'in.beyondigital.aiux.consumer'},android:{package:'in.beyondigital.aiux.consumer'}}}));
  writeFileSync(join(dir, 'App.tsx'), "import {AIConversation} from '@beyond-digital/aiux-expo'; export default function App(){ return <AIConversation sessionId='consumer'/>; }");
  writeFileSync(join(dir, 'index.js'), "import {registerRootComponent} from 'expo'; import App from './App'; registerRootComponent(App);");
  const pkg = JSON.parse(readFileSync(join(dir, 'package.json'))); pkg.main='index.js'; writeFileSync(join(dir, 'package.json'), JSON.stringify(pkg));
  run('npx', ['expo', 'prebuild', '--platform', platform, '--no-install']);
  run('npm', ['install', '--ignore-scripts', '--no-audit', '--no-fund']);
  if (platform === 'android') execFileSync('./gradlew', ['assembleDebug','--no-daemon'], {cwd:join(dir,'android'),stdio:'inherit'});
  else {
    execFileSync('pod', ['install'], {cwd:join(dir,'ios'),stdio:'inherit'});
    execFileSync('xcodebuild', ['-workspace','AIUXConsumer.xcworkspace','-scheme','AIUXConsumer','-sdk','iphonesimulator','-destination','generic/platform=iOS Simulator','CODE_SIGNING_ALLOWED=NO','build'], {cwd:join(dir,'ios'),stdio:'inherit'});
  }
  console.log('Clean Expo consumer native compilation passed:', platform);
}
