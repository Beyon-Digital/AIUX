// Reproducible aiux-wasm build for Node/CI (mirrors scripts/build.sh):
//   cargo build -p aiux-wasm --release --target wasm32-unknown-unknown
//   wasm-bindgen --target web --out-dir bindings/wasm/pkg
// The wasm-bindgen CLI version must match Cargo.lock (currently 0.2.129).
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..", "..");
const targetDir = join(repoRoot, "target");
const pkgDir = join(repoRoot, "bindings", "wasm", "pkg");

const WASM_BINDGEN_VERSION = "0.2.129";

function run(cmd, args) {
  const res = spawnSync(cmd, args, { cwd: repoRoot, stdio: "inherit" });
  if (res.error) {
    console.error(`failed to run ${cmd}: ${res.error.message}`);
    process.exit(1);
  }
  if (res.status !== 0) process.exit(res.status ?? 1);
}

run("cargo", [
  "build",
  "-p",
  "aiux-wasm",
  "--release",
  "--target",
  "wasm32-unknown-unknown",
]);

run("wasm-bindgen", [
  "--out-dir",
  pkgDir,
  "--out-name",
  "aiux_wasm",
  "--target",
  "web",
  "--omit-default-module-path",
  join(targetDir, "wasm32-unknown-unknown", "release", "aiux_wasm.wasm"),
]);

console.log(
  `aiux-wasm: built ${pkgDir} (wasm-bindgen ${WASM_BINDGEN_VERSION})`,
);
