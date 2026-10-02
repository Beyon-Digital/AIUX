import { describe, expect, it } from "vitest";

import type { AdapterIssue } from "../src/index";
import { createEventValidator } from "../../../adapters/shared/src/testing";
import { createEventFactory, createWireNormalizer } from "../src/index";

const validator = createEventValidator();
const target = { runId: "r1", messageId: "m1", partId: "p1" };

const make = () => {
  const issues: AdapterIssue[] = [];
  const factory = createEventFactory("s1", { now: () => "2026-01-01T00:00:00Z" });
  const normalize = createWireNormalizer({
    factory,
    target,
    onIssue: (i) => issues.push(i),
  });
  return { issues, normalize };
};

describe("createWireNormalizer", () => {
  it("passes canonical envelopes through untouched", () => {
    const { normalize, issues } = make();
    const canonical = {
      eventId: "e1",
      sessionId: "s1",
      sequence: 3,
      timestamp: "2026-01-01T00:00:00Z",
      type: "run.completed",
      payload: { protocolVersion: "0.1", runId: "r1" },
    };
    expect(normalize(canonical)).toEqual([canonical]);
    expect(issues).toHaveLength(0);
  });

  it("maps OpenAI-style chunks: content, tool_calls, finish_reason", () => {
    const { normalize } = make();
    const out = [
      ...normalize({ choices: [{ delta: { content: "hi" } }] }),
      ...normalize({
        choices: [
          {
            delta: {
              tool_calls: [
                { id: "call_1", function: { name: "f", arguments: "{}" } },
              ],
            },
          },
        ],
      }),
      ...normalize({ choices: [{ delta: {}, finish_reason: "stop" }] }),
    ];
    expect(out.map((e) => e.type)).toEqual([
      "text.delta",
      "tool.started",
      "run.completed",
    ]);
    for (const e of out) validator.assertValid(e);
  });

  it("maps Anthropic-style content_block_delta and message_stop", () => {
    const { normalize } = make();
    const out = [
      ...normalize({
        type: "content_block_delta",
        delta: { type: "text_delta", text: "chunk" },
      }),
      ...normalize({ type: "message_stop" }),
    ];
    expect(out.map((e) => e.type)).toEqual(["text.delta", "run.completed"]);
    for (const e of out) validator.assertValid(e);
  });

  it("maps run.cancelled / run.failed shapes and [DONE]", () => {
    const { normalize } = make();
    expect(normalize({ type: "cancelled", reason: "bye" })[0]!.type).toBe(
      "run.cancelled",
    );
    const failed = normalize({ type: "error", error: { code: "x", message: "m" } });
    expect(failed[0]!.type).toBe("run.failed");
    validator.assertValid(failed[0]!);
    expect(normalize("[DONE]")[0]!.type).toBe("run.completed");
  });

  it("never throws on unrecognizable items — reports instead", () => {
    const { normalize, issues } = make();
    for (const item of [
      42,
      null,
      { no: "fields" },
      { type: "totally.unknown" },
      [],
    ]) {
      expect(normalize(item)).toEqual([]);
    }
    expect(issues).toHaveLength(5);
    expect(issues.map((i) => i.kind)).toEqual(
      Array(5).fill("malformed"),
    );
  });
});
