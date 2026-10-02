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
    const { normalize: normalizeFailed } = make();
    const failed = normalizeFailed({
      type: "error",
      error: { code: "x", message: "m" },
    });
    expect(failed[0]!.type).toBe("run.failed");
    validator.assertValid(failed[0]!);
    const { normalize: normalizeDone } = make();
    expect(normalizeDone("[DONE]")[0]!.type).toBe("run.completed");
  });

  it("emits at most one terminal run event per stream", () => {
    const { normalize } = make();
    expect(
      normalize({ choices: [{ delta: {}, finish_reason: "stop" }] })[0]!.type,
    ).toBe("run.completed");
    // `finish_reason` followed by `[DONE]` must not emit run.completed twice —
    // the reducer rejects the duplicate.
    expect(normalize("[DONE]")).toEqual([]);
    expect(normalize({ type: "finish" })).toEqual([]);
  });

  it("a suppressed terminal must not consume a sequence", () => {
    const { normalize } = make();
    const first = normalize({ choices: [{ delta: {}, finish_reason: "stop" }] });
    // Second terminal is dropped — and must not have minted an envelope
    // first, else the dropped sequence leaves a hole in the reorder buffer.
    normalize({ type: "finish" });
    const delta = normalize({ type: "text.delta", delta: "x" })[0]!;
    expect(delta.sequence).toBe(first[0]!.sequence + 1);
  });

  it("defers tool.started until streamed arguments parse complete", () => {
    const { normalize } = make();
    const named = normalize({
      choices: [
        {
          delta: {
            tool_calls: [
              { id: "call_1", function: { name: "f", arguments: '{"q":' } },
            ],
          },
        },
      ],
    });
    expect(named).toEqual([]);
    const out = [
      ...normalize({
        choices: [
          {
            delta: {
              tool_calls: [
                { index: 0, function: { arguments: " 1}" } },
              ],
            },
          },
        ],
      }),
      ...normalize({ choices: [{ delta: {}, finish_reason: "stop" }] }),
    ];
    expect(out.map((e) => e.type)).toEqual(["tool.started", "run.completed"]);
    const started = out[0]!;
    expect(started.type).toBe("tool.started");
    expect((started.payload as { tool: { input: unknown } }).tool.input).toEqual({
      q: 1,
    });
    for (const e of out) validator.assertValid(e);
  });

  it("seals pending tool calls on finish() — clean EOF without a terminal", () => {
    const { normalize } = make();
    normalize({
      choices: [
        {
          delta: {
            tool_calls: [
              { id: "call_1", function: { name: "f", arguments: '{"q":' } },
            ],
          },
        },
      ],
    });
    const out = normalize.finish?.() ?? [];
    expect(out.map((e) => e.type)).toEqual(["tool.started"]);
    expect(
      (out[0]!.payload as { tool: { input: unknown } }).tool.input,
    ).toEqual({ arguments: '{"q":' });
    for (const e of out) validator.assertValid(e);
  });

  it("does not freeze input on a scalar-complete args prefix", () => {
    const { normalize } = make();
    // Fragments "1" then "2" — "1" parses as valid JSON but is not an
    // object, so the start must wait for the real boundary.
    const named = normalize({
      choices: [
        {
          delta: {
            tool_calls: [{ id: "call_1", function: { name: "f", arguments: "1" } }],
          },
        },
      ],
    });
    expect(named).toEqual([]);
    const out = normalize({ choices: [{ delta: {}, finish_reason: "stop" }] });
    expect(out.map((e) => e.type)).toEqual(["tool.started", "run.completed"]);
    expect(
      (out[0]!.payload as { tool: { input: unknown } }).tool.input,
    ).toEqual({ arguments: "1" });
  });

  it("seals a truncated tool call best-effort before the terminal", () => {
    const { normalize } = make();
    normalize({
      choices: [
        {
          delta: {
            tool_calls: [
              { id: "call_1", function: { name: "f", arguments: '{"q":' } },
            ],
          },
        },
      ],
    });
    const out = normalize({ choices: [{ delta: {}, finish_reason: "stop" }] });
    expect(out.map((e) => e.type)).toEqual(["tool.started", "run.completed"]);
    expect(
      (out[0]!.payload as { tool: { input: unknown } }).tool.input,
    ).toEqual({ arguments: '{"q":' });
    for (const e of out) validator.assertValid(e);
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
