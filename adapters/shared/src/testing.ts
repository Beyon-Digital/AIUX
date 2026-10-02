/**
 * Test support for the adapters/transports lane — loads the v1 JSON schemas
 * and conformance fixtures straight from the repo. Not part of the package's
 * public API (deliberately absent from `src/index.ts`); import it via the
 * relative path inside this monorepo's tests.
 */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import Ajv from "ajv";
import type { ErrorObject, ValidateFunction } from "ajv";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "..");

export const SCHEMA_DIR = join(repoRoot, "protocol", "schemas", "v1");
export const EVENT_SCHEMA_DIR = join(SCHEMA_DIR, "events");
export const FIXTURE_DIR = join(repoRoot, "conformance", "fixtures");
export const VERSION_MANIFEST_PATH = join(repoRoot, "protocol", "versions", "v1.json");

export interface EventValidation {
  ok: boolean;
  errors: ErrorObject[] | null | undefined;
}

/** ajv validator for `events/<type>.json` schemas, compiled lazily per type. */
export interface EventValidator {
  /** Validate one envelope against its `events/<type>.json` schema. */
  validate(event: { type: string }): EventValidation;
  /** Assert-validate; throws a descriptive error when invalid. */
  assertValid(event: { type: string }): void;
}

export function createEventValidator(): EventValidator {
  const ajv = new Ajv({ allErrors: true, strict: false });
  // schemars emits Rust numeric formats ajv doesn't know; enforce them so
  // `sequence`/progress values can't silently drift off-spec.
  ajv.addFormat("uint64", { type: "number", validate: (n) => Number.isSafeInteger(n) && n >= 0 });
  ajv.addFormat("uint32", { type: "number", validate: (n) => Number.isInteger(n) && n >= 0 && n <= 0xffffffff });
  ajv.addFormat("uint8", { type: "number", validate: (n) => Number.isInteger(n) && n >= 0 && n <= 0xff });
  ajv.addFormat("double", { type: "number", validate: (n) => typeof n === "number" });
  const cache = new Map<string, ValidateFunction>();
  const forType = (type: string): ValidateFunction => {
    let v = cache.get(type);
    if (!v) {
      const schema = JSON.parse(
        readFileSync(join(EVENT_SCHEMA_DIR, `${type}.json`), "utf8"),
      );
      v = ajv.compile(schema);
      cache.set(type, v);
    }
    return v;
  };
  return {
    validate(event) {
      const v = forType(event.type);
      const ok = v(event) === true;
      return { ok, errors: v.errors };
    },
    assertValid(event) {
      const { ok, errors } = this.validate(event);
      if (!ok) {
        throw new Error(
          `event ${event.type} failed schema validation: ${JSON.stringify(errors)}`,
        );
      }
    },
  };
}

export interface ConformanceFixture {
  events: Array<Record<string, unknown> & { type: string; sequence: number }>;
}

export function loadFixture(name: string): ConformanceFixture {
  return JSON.parse(readFileSync(join(FIXTURE_DIR, `${name}.json`), "utf8"));
}

export function loadVersionManifest(): {
  protocolVersion: string;
  eventTypes: string[];
  entities: string[];
} {
  return JSON.parse(readFileSync(VERSION_MANIFEST_PATH, "utf8"));
}
