import type {
  AiuxError,
  AiuxEvent,
  AiuxEventOf,
  ContextEntity,
  Message,
  Part,
  Progress,
  Run,
  Session,
  Tool,
} from "@beyond-digital/aiux-protocol-types";

import type { EventFactory } from "./factory";
import type { AdapterIssue } from "./types";

/** Ids normalized lifecycle/delta events point at when the wire doesn't say. */
export interface NormalizeTarget {
  /** Run id for run.* lifecycle events produced from wire signals. */
  runId: string;
  /** Message id `text.delta` appends to. */
  messageId: string;
  /** Part id `text.delta` appends to. */
  partId: string;
}

export interface WireNormalizerOptions {
  /** Mints envelopes for normalized shapes. Bound to the session. */
  factory: EventFactory;
  target: NormalizeTarget;
  /** Called per item that produced no events — never thrown. */
  onIssue?: (issue: AdapterIssue) => void;
}

/**
 * A parsed wire item → zero or more `AIUXEvent`s. Zero means the item was
 * skipped (reported via `onIssue`, never thrown mid-stream).
 *
 * `finish()` seals any state the normalizer holds across items (buffered
 * tool calls) and emits their final events — transports must call it when
 * their stream ends, including clean EOF with no terminal marker.
 */
export type WireNormalizer = ((item: unknown) => AiuxEvent[]) & {
  finish?(): AiuxEvent[];
};

const isRecord = (v: unknown): v is Record<string, unknown> =>
  typeof v === "object" && v !== null && !Array.isArray(v);

/** Envelope sniff: does this already look like a canonical AIUX event? */
const looksCanonical = (item: Record<string, unknown>): boolean =>
  typeof item["eventId"] === "string" &&
  typeof item["sessionId"] === "string" &&
  typeof item["type"] === "string" &&
  typeof item["sequence"] === "number" &&
  "payload" in item;

const asError = (v: unknown, fallbackMessage: string): AiuxError => {
  if (isRecord(v) && typeof v["code"] === "string" && typeof v["message"] === "string") {
    return v as unknown as AiuxError;
  }
  return {
    code: "stream_error",
    message: typeof v === "string" ? v : fallbackMessage,
  };
};

const firstString = (...vals: unknown[]): string | undefined => {
  for (const v of vals) if (typeof v === "string" && v.length > 0) return v;
  return undefined;
};

/**
 * Default wire→events normalization shared by the SSE / WebSocket adapters:
 *
 * - Canonical envelopes (eventId+sessionId+sequence+type+payload) pass
 *   through untouched — the server already sequenced them.
 * - AIUX-ish typed items (`{"type":"text.delta", ...}` without envelope)
 *   are re-enveloped by the factory.
 * - Common provider shapes (OpenAI `choices[].delta`, Anthropic
 *   `content_block_delta`/`message_stop`, `[DONE]`) map onto
 *   `text.delta`/`run.*` lifecycle events against `target`.
 * - Anything else is reported through `onIssue` and yields nothing —
 *   normalization never throws mid-stream.
 */
export function createWireNormalizer(options: WireNormalizerOptions): WireNormalizer {
  const { factory, target, onIssue } = options;

  const skip = (reason: string, raw?: unknown): AiuxEvent[] => {
    onIssue?.({ kind: "malformed", reason, raw });
    return [];
  };

  // A run emits exactly one terminal event — `finish_reason` chunks and
  // `[DONE]` sentinels (or provider-specific terminal types) often arrive
  // back to back, and the reducer rejects the second `run.completed`.
  // The mint is a callback: gating must run BEFORE the factory consumes a
  // sequence, else a suppressed terminal leaves a hole in the reorder
  // buffer that stalls every later event.
  let terminalEmitted = false;
  const terminalOnce = (mint: () => AiuxEvent[]): AiuxEvent[] => {
    if (terminalEmitted) return skip("duplicate-terminal");
    terminalEmitted = true;
    return mint();
  };

  // OpenAI streams `tool_calls` as fragments keyed by `index`: the first
  // carries `id`+`name`, later chunks only append `arguments` string pieces
  // (name omitted). `tool.started` carries the tool's complete input, so it
  // emits once the accumulated arguments parse as JSON — or best-effort
  // when the slot seals (a new named fragment, or the run ending). Once
  // emitted, further fragments stream out as `tool.progress`.
  interface PendingToolCall {
    id: string;
    name: string;
    args: string;
    emitted: boolean;
  }
  const pendingToolCalls = new Map<string, PendingToolCall>();

  // `arguments` is a JSON object per the function-calling spec — a scalar
  // prefix like `"1"` parses fine but is not a complete input (`12` can
  // still follow). Only an object parse completes the args early; anything
  // else seals best-effort at the slot/run boundary.
  const tryParseArgs = (args: string): Record<string, unknown> | undefined => {
    if (args === "") return undefined;
    try {
      const parsed: unknown = JSON.parse(args);
      return isRecord(parsed) ? parsed : undefined;
    } catch {
      return undefined;
    }
  };

  const emitStart = (pending: PendingToolCall, force = false): AiuxEvent[] => {
    if (pending.emitted) return [];
    const parsed = tryParseArgs(pending.args);
    if (!force && parsed === undefined) return [];
    pending.emitted = true;
    const tool: Tool = { id: pending.id, name: pending.name, status: "running" };
    if (parsed !== undefined) tool.input = parsed;
    else if (pending.args !== "") tool.input = { arguments: pending.args };
    return [factory.toolStarted(tool)];
  };

  const sealPending = (key: string): AiuxEvent[] => {
    const pending = pendingToolCalls.get(key);
    if (pending === undefined) return [];
    const out = emitStart(pending, true);
    pendingToolCalls.delete(key);
    return out;
  };

  const sealAllPending = (): AiuxEvent[] => {
    const out: AiuxEvent[] = [];
    for (const key of [...pendingToolCalls.keys()]) out.push(...sealPending(key));
    return out;
  };

  // Id-less fallbacks must be unique per invocation, not per slot — a
  // named fragment can legitimately replace a truncated call in the same
  // slot, and reusing `tool-${key}` makes the reducer reject the second
  // start as a duplicate. The `tool-call-` prefix keeps this namespace
  // disjoint from `toolId`'s `tool-${sequence}` fallbacks below.
  let fallbackToolCallCounter = 0;

  const runId = (item: Record<string, unknown>): string =>
    firstString(item["runId"], item["run_id"]) ?? target.runId;

  const textDelta = (delta: unknown): AiuxEvent[] => {
    if (typeof delta !== "string" || delta.length === 0) {
      return skip("missing-delta", delta);
    }
    return [factory.textDelta(target.messageId, target.partId, delta)];
  };

  const toolId = (item: Record<string, unknown>): string =>
    firstString(item["toolCallId"], item["tool_call_id"], item["toolId"], item["id"]) ??
    `tool-${factory.peekSequence()}`;

  const toolStarted = (item: Record<string, unknown>): AiuxEvent[] => {
    const name = firstString(item["toolName"], item["tool_name"], item["name"]);
    if (!name) return skip("missing-tool-name", item);
    const tool: Tool = {
      id: toolId(item),
      name,
      status: "running",
      ...(item["input"] !== undefined && { input: item["input"] }),
      ...(item["args"] !== undefined && { input: item["args"] }),
      ...(item["startedAt"] !== undefined && {
        startedAt: item["startedAt"] as Tool["startedAt"],
      }),
    };
    return [factory.toolStarted(tool)];
  };

  const normalizeType = (item: Record<string, unknown>, type: string): AiuxEvent[] => {
    switch (type) {
      // --- AIUX lifecycle names (bare payloads, no envelope) ----------------
      case "session.created": {
        if (!isRecord(item["session"])) return skip("missing-session", item);
        return [factory.sessionCreated(item["session"] as unknown as Session)];
      }
      case "run.started": {
        if (!isRecord(item["run"])) return skip("missing-run", item);
        const ctx = Array.isArray(item["context"])
          ? (item["context"] as ContextEntity[])
          : undefined;
        return [factory.runStarted(item["run"] as unknown as Run, ctx)];
      }
      case "run.completed":
      case "finish":
      case "done":
      case "message_stop":
        return [
          ...sealAllPending(),
          ...terminalOnce(() => [
            factory.runCompleted(runId(item), item["result"]),
          ]),
        ];
      case "run.failed":
      case "error":
        return [
          ...sealAllPending(),
          ...terminalOnce(() => [
            factory.runFailed(
              runId(item),
              asError(item["error"] ?? item["message"] ?? item, "stream error"),
            ),
          ]),
        ];
      case "run.cancelled":
      case "cancelled":
      case "aborted":
      case "abort":
        return [
          ...sealAllPending(),
          ...terminalOnce(() => [
            factory.runCancelled(runId(item), firstString(item["reason"])),
          ]),
        ];
      case "message.created": {
        if (!isRecord(item["message"])) return skip("missing-message", item);
        return [factory.messageCreated(item["message"] as unknown as Message)];
      }
      case "part.added": {
        const messageId = firstString(item["messageId"]) ?? target.messageId;
        if (!isRecord(item["part"])) return skip("missing-part", item);
        return [factory.partAdded(messageId, item["part"] as unknown as Part)];
      }
      // --- text deltas ------------------------------------------------------
      case "text.delta":
      case "text-delta":
      case "text_delta":
        return textDelta(
          firstString(item["delta"], item["textDelta"], item["text"]) ?? item["delta"],
        );
      case "content_block_delta": {
        // Anthropic-style: {type:'content_block_delta', delta:{type:'text_delta', text}}
        const delta = item["delta"];
        if (isRecord(delta)) return textDelta(delta["text"]);
        return skip("bad-content-block-delta", item);
      }
      // --- tools ------------------------------------------------------------
      case "tool.started":
      case "tool-call":
      case "tool_call":
      case "tool-input-available":
        return toolStarted(item);
      case "tool.progress": {
        const progress = item["progress"];
        if (!isRecord(progress)) return skip("missing-progress", item);
        return [factory.toolProgress(toolId(item), progress as unknown as Progress)];
      }
      case "tool.completed":
      case "tool-result":
      case "tool_result":
      case "tool-output-available":
        return [
          factory.toolCompleted(
            toolId(item),
            item["result"] ?? item["output"],
          ),
        ];
      case "tool.failed":
      case "tool-error":
      case "tool_error":
      case "tool-output-error":
        return [
          factory.toolFailed(
            toolId(item),
            asError(item["error"] ?? item["errorText"], "tool error"),
          ),
        ];
      default:
        return skip("unknown-type", item);
    }
  };

  /** OpenAI chat.completion.chunk-ish shapes. */
  const normalizeChoices = (item: Record<string, unknown>): AiuxEvent[] => {
    const choices = item["choices"];
    if (!Array.isArray(choices) || choices.length === 0) return skip("empty-choices", item);
    const out: AiuxEvent[] = [];
    for (const raw of choices) {
      if (!isRecord(raw)) continue;
      const delta = isRecord(raw["delta"]) ? (raw["delta"] as Record<string, unknown>) : undefined;
      if (delta) {
        if (typeof delta["content"] === "string" && delta["content"] !== "") {
          out.push(...textDelta(delta["content"]));
        }
        const toolCalls = delta["tool_calls"];
        if (Array.isArray(toolCalls)) {
          for (let i = 0; i < toolCalls.length; i += 1) {
            const tc = toolCalls[i];
            if (!isRecord(tc)) continue;
            const fn = isRecord(tc["function"]) ? (tc["function"] as Record<string, unknown>) : {};
            const key = `${typeof raw["index"] === "number" ? raw["index"] : i}:${
              typeof tc["index"] === "number" ? tc["index"] : i
            }`;
            const name = firstString(fn["name"], tc["name"]);
            const argFragment =
              typeof fn["arguments"] === "string" ? fn["arguments"] : "";
            if (name) {
              // A named fragment begins a call at this slot. An un-emitted
              // pending for the slot is a truncated predecessor — seal it
              // best-effort before replacing.
              out.push(...sealPending(key));
              const pending: PendingToolCall = {
                id:
                  firstString(tc["id"], tc["toolCallId"]) ??
                  `tool-call-${fallbackToolCallCounter++}`,
                name,
                args: argFragment,
                emitted: false,
              };
              pendingToolCalls.set(key, pending);
              // Single-shot arguments (complete JSON in one fragment) emit
              // immediately; streamed args emit once they parse complete.
              out.push(...emitStart(pending));
              continue;
            }
            const pending = pendingToolCalls.get(key);
            if (pending) {
              pending.args += argFragment;
              if (!pending.emitted) {
                // A fragment may still carry the real provider id — safe to
                // adopt while the start is un-emitted.
                if (typeof tc["id"] === "string") pending.id = tc["id"];
                out.push(...emitStart(pending));
              } else if (argFragment !== "") {
                out.push(
                  factory.toolProgress(pending.id, {
                    label: "arguments",
                    arguments: pending.args,
                  }),
                );
              }
              continue;
            }
            onIssue?.({ kind: "malformed", reason: "missing-tool-name", raw: tc });
          }
        }
      }
      const finish = firstString(raw["finish_reason"], raw["finishReason"]);
      if (finish)
        out.push(
          // Tool starts seal before the terminal mint — their sequences
          // precede it, keeping the run's event order intact.
          ...sealAllPending(),
          ...terminalOnce(() => [
            factory.runCompleted(runId(item), { finishReason: finish }),
          ]),
        );
    }
    if (out.length === 0 && pendingToolCalls.size === 0)
      return skip("unhandled-choices", item);
    return out;
  };

  const normalize = (item: unknown): AiuxEvent[] => {
    // Raw non-JSON values (e.g. `[DONE]` sentinels) get a tiny mapping too.
    if (typeof item === "string") {
      if (item.trim() === "[DONE]")
        return [
          ...sealAllPending(),
          ...terminalOnce(() => [factory.runCompleted(target.runId)]),
        ];
      return skip("unparseable-string", item);
    }
    if (!isRecord(item)) return skip("not-an-object", item);
    if (looksCanonical(item)) {
      // Canonical envelopes keep their own sequence — advance the factory
      // past it so a later bare item can't mint a duplicate sequence.
      factory.observeSequence(item["sequence"] as number);
      return [item as unknown as AiuxEventOf<Record<string, unknown>>];
    }
    const type = item["type"];
    if (typeof type === "string") return normalizeType(item, type);
    if ("choices" in item || "delta" in item) return normalizeChoices(item);
    return skip("unknown-shape", item);
  };

  // Transports must call this once their stream ends — including clean EOF
  // with no terminal marker — so pending tool calls seal (and emit) instead
  // of disappearing silently.
  normalize.finish = sealAllPending;
  return normalize;
}
