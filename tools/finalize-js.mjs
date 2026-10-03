// tsc's Bundler resolution leaves extensionless imports; published ESM must
// resolve in Node as well as Metro/Vite. Rewrite emitted code and declarations.
import { existsSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname, extname } from 'node:path';
const root = resolve(process.argv[2] ?? '.', 'dist');
function walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const file = resolve(dir, entry.name);
    if (entry.isDirectory()) { walk(file); continue; }
    if (!/\.(js|jsx|ts)$/.test(file)) continue;
    const source = readFileSync(file, 'utf8');
    const fixed = source.replace(/((?:from\s*|import\s*\(|import\s*)["'])(\.[^"']+)(["'])/g, (all, prefix, spec, quote) => {
      if (extname(spec)) {
        if (spec.endsWith(".jsx") && !existsSync(resolve(dirname(file), spec)) && existsSync(resolve(dirname(file), spec.slice(0, -1)))) return prefix + spec.slice(0, -1) + quote;
        return all;
      }
      const target = resolve(dirname(file), spec);
      const suffix = existsSync(target + '.js') ? '.js' : existsSync(target + '.jsx') ? '.jsx' : existsSync(resolve(target, 'index.js')) ? '/index.js' : null;
      if (!suffix) throw new Error(`Unresolved emitted import: ${file}: ${spec}`);
      return prefix + spec + suffix + quote;
    });
    writeFileSync(file, fixed);
  }
}
walk(root);
