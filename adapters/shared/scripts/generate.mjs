#!/usr/bin/env node
/**
 * Generates TS types from `protocol/schemas/v1` (JSON Schema draft-07) plus
 * constants from `protocol/versions/v1.json`.
 *
 * Output (committed):
 *   src/generated/<entity>.ts          — one file per top-level schema
 *   src/generated/events/<name>.ts     — one file per event envelope schema
 *   src/generated/constants.ts         — protocolVersion / eventTypes / entities
 *   src/generated/index.ts             — dedup'd barrel (first definition wins)
 *
 * Regenerate: `pnpm --filter @beyond-digital/aiux-protocol-types generate`.
 */
import { compile } from "json-schema-to-typescript";
import {
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const pkgDir = dirname(dirname(fileURLToPath(import.meta.url)));
const repoRoot = join(pkgDir, "..", "..");
const schemaDir = join(repoRoot, "protocol", "schemas", "v1");
const eventsDir = join(schemaDir, "events");
const manifestPath = join(repoRoot, "protocol", "versions", "v1.json");
const outDir = join(pkgDir, "src", "generated");
const outEventsDir = join(outDir, "events");

const BANNER = `// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyond-digital/aiux-protocol-types generate
/* eslint-disable */
`;

const pascal = (name) =>
  name
    .split(/[^A-Za-z0-9]+/)
    .filter(Boolean)
    .map((s) => s[0].toUpperCase() + s.slice(1))
    .join("");

const kebab = (name) => name.replace(/\./g, "-");

/** Nicer top-level names than the filename gives (avoids shadowing builtins). */
const TOP_NAME_OVERRIDES = {
  event: "AiuxEvent",
  error: "AiuxError",
};

/** Names of exported declarations in emitted TS (interfaces, type aliases, consts). */
const exportedNames = (ts) => {
  const names = [];
  const re = /export\s+(?:declare\s+)?(?:interface|type|const|enum|class|function)\s+([A-Za-z_$][\w$]*)/g;
  for (const m of ts.matchAll(re)) names.push(m[1]);
  return names;
};

/**
 * Keys that carry no structural constraint. A node made of ONLY these
 * (e.g. `{"description": "Optional run result."}` — how schemars emits
 * `serde_json::Value`) accepts ANY JSON; force `unknown` via the
 * json-schema-to-typescript `tsType` extension so generated types don't
 * pretend these fields are objects.
 */
const DESCRIPTIVE_KEYS = new Set([
  "$comment",
  "$id",
  "$schema",
  "deprecated",
  "description",
  "default",
  "discriminator",
  "examples",
  "format",
  "markdownDescription",
  "readOnly",
  "title",
  "tsType",
  "writeOnly",
]);

const markUnconstrained = (node) => {
  if (Array.isArray(node)) {
    for (const v of node) markUnconstrained(v);
    return;
  }
  if (node === null || typeof node !== "object") return;
  if (Object.keys(node).every((k) => DESCRIPTIVE_KEYS.has(k))) {
    node.tsType = "unknown";
    return; // no structural children to visit
  }
  for (const v of Object.values(node)) markUnconstrained(v);
};

const load = (file) => {
  const schema = JSON.parse(readFileSync(file, "utf8"));
  // The schemars-emitted `title` would force an ugly top-level name
  // (e.g. AiuxEvent_for_TextDelta); drop it so `compile` uses our name.
  delete schema.title;
  markUnconstrained(schema);
  return schema;
};

/** Compile one schema file; returns { file, ts, names }. */
const compileFile = async (file, topName, destDir) => {
  const ts = await compile(load(file), topName, {
    bannerComment: BANNER,
    additionalProperties: true,
    strictIndexSignatures: true,
    // Unconstrained schema fields (Rust serde_json::Value) → `unknown`,
    // not `any` — keeps strict TS usable.
    unknownAny: true,
  });
  return { file, ts, names: exportedNames(ts), destDir };
};

const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));

// Compile order decides dedup winners: shared entities first, events last.
const entityFiles = readdirSync(schemaDir)
  .filter((f) => f.endsWith(".json"))
  .sort();
const eventFiles = readdirSync(eventsDir)
  .filter((f) => f.endsWith(".json"))
  .sort();

const compiled = [];
for (const f of entityFiles) {
  const base = f.slice(0, -5);
  compiled.push(
    await compileFile(join(schemaDir, f), TOP_NAME_OVERRIDES[base] ?? pascal(base), outDir),
  );
}
for (const f of eventFiles) {
  const base = f.slice(0, -5); // e.g. text.delta
  compiled.push(
    await compileFile(join(eventsDir, f), `${pascal(base)}Event`, outEventsDir),
  );
}

rmSync(outDir, { recursive: true, force: true });
mkdirSync(outEventsDir, { recursive: true });

// Write each compiled file and build the dedup'd barrel.
const seen = new Set();
const barrel = [BANNER];
for (const { file, ts, names, destDir } of compiled) {
  const base = file.split("/").pop().slice(0, -5); // e.g. "part", "text.delta"
  const outFile =
    destDir === outEventsDir
      ? join(outEventsDir, `${kebab(base)}.ts`)
      : join(outDir, `${kebab(base)}.ts`);
  writeFileSync(outFile, ts);
  const fresh = names.filter((n) => !seen.has(n));
  for (const n of names) seen.add(n);
  const mod = `./${relative(outDir, outFile).replace(/\.ts$/, "")}`;
  if (fresh.length > 0) {
    barrel.push(`export type { ${fresh.sort().join(", ")} } from "${mod}";`);
  }
}

// Constants from the version manifest.
const constants = `${BANNER}
/** Protocol version carried by envelopes and payloads (protocol/versions/v1.json). */
export const PROTOCOL_VERSION = ${JSON.stringify(manifest.protocolVersion)} as const;

/** The ${manifest.eventTypes.length} lifecycle event type names of Protocol v1 (plan §3). */
export const EVENT_TYPES = ${JSON.stringify(manifest.eventTypes, null, 2)} as const;

/** Union of the ${manifest.eventTypes.length} wire event type names. */
export type EventTypeName = (typeof EVENT_TYPES)[number];

/** Top-level entity schema names of Protocol v1. */
export const ENTITIES = ${JSON.stringify(manifest.entities, null, 2)} as const;
`;
writeFileSync(join(outDir, "constants.ts"), constants);
barrel.push(`export { ENTITIES, EVENT_TYPES, PROTOCOL_VERSION } from "./constants";`);
barrel.push(`export type { EventTypeName } from "./constants";`);

writeFileSync(join(outDir, "index.ts"), barrel.join("\n") + "\n");

console.log(
  `generated ${compiled.length} schema files → ${relative(pkgDir, outDir)} (${seen.size} exported names)`,
);
