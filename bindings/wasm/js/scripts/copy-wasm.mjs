// Copy the wasm-bindgen artifacts (bindings/wasm/pkg/) next to the JS package
// so `import "@beyondigital/aiux-core/wasm"` resolves to real, pinned bytes.
// `pkg/` is gitignored — this script runs inside `aiux-core`'s build so CI
// produces it from source before packing. Fails loudly when pkg/ is absent:
// run `bindings/wasm/scripts/build-wasm.mjs` first.
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const pkg = join(here, "..", "..", "pkg");
const out = join(here, "..", "wasm");

if (!existsSync(join(pkg, "aiux_wasm.js"))) {
  console.error(
    "aiux-core: bindings/wasm/pkg/ is missing — build it first with " +
      "`node bindings/wasm/scripts/build-wasm.mjs` (needs the wasm32 target " +
      "and wasm-bindgen-cli matching Cargo.lock).",
  );
  process.exit(1);
}

mkdirSync(out, { recursive: true });
for (const name of readdirSync(pkg)) {
  if (/\.(js|d\.ts|wasm)$/.test(name)) {
    copyFileSync(join(pkg, name), join(out, name));
  }
}
console.log(`aiux-core: wasm artifacts → ${out}`);
