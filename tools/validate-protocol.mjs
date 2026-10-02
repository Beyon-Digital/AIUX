/**
 * protocol-validate CI gate (plan §17): compile every v1 JSON schema, cross-
 * check the version manifest against the on-disk event schemas, and validate
 * every conformance fixture event against its `events/<type>.json` schema.
 * Exits non-zero on any malformed schema or violating fixture.
 */
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import Ajv from "ajv";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const schemaDir = join(repoRoot, "protocol", "schemas", "v1");
const eventSchemaDir = join(schemaDir, "events");
const fixtureDir = join(repoRoot, "conformance", "fixtures");
const manifestPath = join(repoRoot, "protocol", "versions", "v1.json");

const ajv = new Ajv({ allErrors: true, strict: false });
// schemars emits Rust numeric formats ajv doesn't know; enforce them so
// `sequence`/progress values can't silently drift off-spec.
ajv.addFormat("uint64", { type: "number", validate: (n) => Number.isSafeInteger(n) && n >= 0 });
ajv.addFormat("uint32", { type: "number", validate: (n) => Number.isInteger(n) && n >= 0 && n <= 0xffffffff });
ajv.addFormat("uint8", { type: "number", validate: (n) => Number.isInteger(n) && n >= 0 && n <= 0xff });
ajv.addFormat("double", { type: "number", validate: (n) => typeof n === "number" });

let failures = 0;
const fail = (msg) => {
  failures += 1;
  console.error(`FAIL ${msg}`);
};

/** Recursively collect *.json files under dir. */
const jsonFiles = (dir) =>
  readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? jsonFiles(join(dir, e.name)) : e.name.endsWith(".json") ? [join(dir, e.name)] : [],
  );

// 1. Every schema file parses AND compiles.
const validators = new Map();
for (const file of jsonFiles(schemaDir)) {
  let schema;
  try {
    schema = JSON.parse(readFileSync(file, "utf8"));
  } catch (e) {
    fail(`${file}: invalid JSON — ${e.message}`);
    continue;
  }
  try {
    validators.set(file, ajv.compile(schema));
  } catch (e) {
    fail(`${file}: does not compile as a JSON Schema — ${e.message}`);
  }
}

// 2. Manifest eventTypes must exactly cover events/*.json schemas.
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
const onDisk = new Set(
  readdirSync(eventSchemaDir)
    .filter((f) => f.endsWith(".json"))
    .map((f) => f.replace(/\.json$/, "")),
);
const declared = new Set(manifest.eventTypes);
for (const t of declared) {
  if (!onDisk.has(t)) fail(`manifest eventType ${t} has no protocol/schemas/v1/events/${t}.json`);
}
for (const t of onDisk) {
  if (!declared.has(t)) fail(`events/${t}.json is not declared in the v1 manifest eventTypes`);
}

// 3. Every conformance fixture event validates against its event schema.
const eventValidator = (type) => {
  const file = join(eventSchemaDir, `${type}.json`);
  let v = validators.get(file);
  if (!v) {
    const schema = JSON.parse(readFileSync(file, "utf8"));
    v = ajv.compile(schema);
    validators.set(file, v);
  }
  return v;
};

for (const file of jsonFiles(fixtureDir)) {
  const fixture = JSON.parse(readFileSync(file, "utf8"));
  for (const [i, event] of (fixture.events ?? []).entries()) {
    const type = event?.type;
    if (!type || !onDisk.has(type)) {
      fail(`${file}: event[${i}] has unknown or missing type ${JSON.stringify(type)}`);
      continue;
    }
    const v = eventValidator(type);
    if (v(event) !== true) {
      fail(`${file}: event[${i}] (${type}) fails schema — ${JSON.stringify(v.errors?.slice(0, 3))}`);
    }
  }
}

if (failures > 0) {
  console.error(`protocol-validate: ${failures} failure(s)`);
  process.exit(1);
}
console.log(
  `protocol-validate: ${validators.size} schemas compiled, ` +
    `${declared.size} event types cross-checked, fixtures conform.`,
);
