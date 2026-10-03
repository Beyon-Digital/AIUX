/**
 * Phase-5 gate (plan §16/§17): every canonical fixture replays through the
 * SAME wasm core the browser renderer ships — `serialize()` must byte-match
 * `conformance/expected/<name>.json`. This is the same check the Rust
 * `aiux-conformance verify` harness runs, through the exact JS path
 * (`@beyond-digital/aiux-core` → `aiux-wasm`) the renderer uses.
 *
 * Requires `bindings/wasm/pkg/` — build with
 * `pnpm --filter @beyond-digital/aiux-core build:wasm`. Skips loudly when the
 * artifacts are absent (e.g. the Rust-less CI `js` job).
 */
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { describe, expect, it } from "vitest";
import {
  AiuxSession,
  wasmCore,
  type AiuxWasmModule,
} from "@beyond-digital/aiux-core";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, "..", "..", "..");
const fixturesDir = join(repoRoot, "conformance", "fixtures");
const expectedDir = join(repoRoot, "conformance", "expected");
const pkgDir = join(repoRoot, "bindings", "wasm", "pkg");
const wasmJs = join(pkgDir, "aiux_wasm.js");
const wasmBin = join(pkgDir, "aiux_wasm_bg.wasm");

const havePkg = existsSync(wasmJs) && existsSync(wasmBin);

async function loadCore() {
  const mod = (await import(
    /* @vite-ignore */ pathToFileURL(wasmJs).href
  )) as AiuxWasmModule & {
    default(input: {
      module_or_path: BufferSource;
    }): Promise<unknown>;
  };
  // Feed init() the wasm bytes directly — no fetch(), works in node + jsdom.
  await mod.default({ module_or_path: readFileSync(wasmBin) });
  return wasmCore(mod);
}

describe.skipIf(!havePkg)("wasm conformance gate (plan §17)", () => {
  it("serializes every fixture byte-identically to expected/*.json", async () => {
    const core = await loadCore();
    const fixtures = readdirSync(fixturesDir)
      .filter((f) => f.endsWith(".json"))
      .sort();
    expect(fixtures.length).toBeGreaterThan(0);

    const failures: string[] = [];
    for (const file of fixtures) {
      const name = file.replace(/\.json$/, "");
      const fixture = JSON.parse(
        readFileSync(join(fixturesDir, file), "utf8"),
      ) as { events: unknown[] };
      const session = AiuxSession.create(core, "{}");
      try {
        for (const event of fixture.events) {
          session.dispatch(event as Record<string, unknown>);
        }
        const serialized = session.serialize();
        const expected = readFileSync(
          join(expectedDir, file),
          "utf8",
        );
        if (serialized !== expected) failures.push(name);
      } catch (e) {
        failures.push(`${name} (dispatch error: ${(e as Error).message})`);
      } finally {
        session.dispose();
      }
    }
    expect(failures, `non-conformant: ${failures.join(", ")}`).toEqual([]);
  });

  it("dispatchBatch produces the same state as per-event dispatch", async () => {
    const core = await loadCore();
    const file = "tool-success.json";
    const fixture = JSON.parse(
      readFileSync(join(fixturesDir, file), "utf8"),
    ) as { events: unknown[] };

    const one = AiuxSession.create(core, "{}");
    const batched = AiuxSession.create(core, "{}");
    try {
      for (const e of fixture.events) one.dispatch(e as never);
      batched.dispatchBatch(fixture.events as never[]);
      expect(batched.serialize()).toBe(one.serialize());
    } finally {
      one.dispose();
      batched.dispose();
    }
  });
});
