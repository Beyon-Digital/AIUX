/**
 * Golden DOM snapshots (plan §16 Phase 8 — "golden/screenshot tests where the
 * platform allows"). Every conformance fixture's final `serialize()` output
 * is projected into the render snapshot shape and mounted through the REAL
 * renderer components — `AIConversation` for message/part coverage and
 * `AISurface` for each declared surface — then the DOM is byte-compared
 * against the committed `__snapshots__` file.
 *
 * This is the CI-verifiable visual gate for the web renderer (jsdom — no
 * browser needed): any markup, ARIA, or structural drift fails `vitest run`.
 * Regenerate after intentional changes with `pnpm test -u` in
 * `renderers/web`, review the diff, and commit the updated snapshot.
 *
 * Browser-pixel goldens remain a manual gate — see
 * docs/renderers/accessibility.md for the per-platform matrix.
 */
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { AIConversation } from "../src/AIConversation.jsx";
import { AISurface } from "../src/AISurface.jsx";
import type { AiuxSnapshot } from "../src/types.js";
import { renderWithContext, stubSession } from "./helpers.jsx";

const here = dirname(fileURLToPath(import.meta.url));
const expectedDir = join(here, "..", "..", "..", "conformance", "expected");

/** Persisted `serialize()` envelope → render-facing `AiuxSnapshot`. */
function toSnapshot(file: string): AiuxSnapshot {
  const persisted = JSON.parse(readFileSync(join(expectedDir, file), "utf8"));
  const state = persisted.state ?? {};
  return {
    protocolVersion: persisted.protocolVersion,
    sessionId: persisted.sessionId,
    session: state.session,
    messages: state.messages ?? [],
    tools: state.tools ?? [],
    approvals: state.approvals ?? [],
    artifacts: state.artifacts ?? [],
    surfaces: state.surfaces ?? [],
    context: state.context ?? [],
    runs: state.runs ?? [],
    activeRunId: state.activeRunId,
  };
}

const fixtures = readdirSync(expectedDir)
  .filter((f) => f.endsWith(".json"))
  .sort();

describe("golden DOM snapshots", () => {
  for (const file of fixtures) {
    const name = file.replace(/\.json$/, "");
    it(`renders ${name} identically`, () => {
      const snapshot = toSnapshot(file);
      const { container, unmount } = renderWithContext(
        <AIConversation session={stubSession(snapshot)} />,
      );
      expect(container.innerHTML).toMatchSnapshot();
      unmount();
    });
  }

  it("renders every fixture surface through AISurface identically", () => {
    const markup: string[] = [];
    for (const file of fixtures) {
      const snapshot = toSnapshot(file);
      for (const surface of snapshot.surfaces ?? []) {
        const { container, unmount } = renderWithContext(
          <AISurface surface={surface} />,
        );
        markup.push(`<!-- ${file} :: ${surface.id} -->\n${container.innerHTML}`);
        unmount();
      }
    }
    expect(markup.join("\n")).toMatchSnapshot();
  });
});
