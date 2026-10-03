/** Canonical fixtures + expected serializations, bundled by Vite. */
import type { AiuxEvent } from "@beyond-digital/aiux-core";

interface FixtureFile {
  name?: string;
  protocolVersion?: string;
  events: AiuxEvent[];
}

const fixtureModules = import.meta.glob<FixtureFile>(
  "../../../conformance/fixtures/*.json",
  { eager: true, import: "default" },
);
const expectedModules = import.meta.glob<string>(
  "../../../conformance/expected/*.json",
  { eager: true, query: "?raw", import: "default" },
);

function key(path: string): string {
  return path.replace(/^.*\//, "").replace(/\.json$/, "");
}

export interface FixtureEntry {
  name: string;
  events: AiuxEvent[];
  /** Canonical `serialize()` bytes this fixture must produce (plan §17). */
  expectedSerialized?: string | undefined;
}

export const FIXTURES: FixtureEntry[] = Object.entries(fixtureModules)
  .map(([path, mod]) => {
    const name = key(path);
    const expectedKey = Object.keys(expectedModules).find(
      (p) => key(p) === name,
    );
    return {
      name,
      events: mod.events,
      expectedSerialized: expectedKey
        ? expectedModules[expectedKey]
        : undefined,
    };
  })
  .filter((f) => !f.name.includes("manifest"))
  .sort((a, b) => a.name.localeCompare(b.name));
