import type { AiuxError, AiuxEvent, Tool } from "@beyond-digital/aiux-protocol-types";
import {
  createEventFactory,
  isTerminalEvent,
  type AdapterIssue,
  type EventBatchSource,
  type EventFactory,
  type NormalizeTarget,
} from "@beyond-digital/aiux-transport-js";

/**
 * Structural shape of a Vercel AI SDK stream part — accepts both the
 * `TextStreamPart`/`StreamPart` family (`text-delta`, `tool-call`,
 * `tool-result`, `finish`, `error`) and the v5 `UIMessageChunk` family
 * (`text-delta`, `tool-input-*`, `tool-output-*`, `finish`, `error`). The
 * `ai` package itself is intentionally not a dependency — anything shaped
 * like this is accepted.
 */
export interface AiSdkStreamPart {
  type: string;
  [key: string]: unknown;
}

export interface AiSdkAdapterOptions {
  /** Session the minted envelopes belong to. */
  sessionId: string;
  /** Ids mapped events point at (run/message/part). */
  target: NormalizeTarget;
  /** Factory override (e.g. to resume sequence). One is created otherwise. */
  factory?: EventFactory;
  /**
   * Called for parts this adapter doesn't map (`start`, `start-step`,
   * `finish-step`, `text-start`, `text-end`, `reasoning-*`, `source-*`,
   * `file`, `data-*`, `finish` variants it already handles excluded).
   */
  onIssue?: (issue: AdapterIssue) => void;
}

const isRecord = (v: unknown): v is Record<string, unknown> =>
  typeof v === "object" && v !== null && !Array.isArray(v);

const firstString = (...vals: unknown[]): string | undefined => {
  for (const v of vals) if (typeof v === "string" && v.length > 0) return v;
  return undefined;
};

const asError = (v: unknown, fallback: string): AiuxError => {
  if (isRecord(v) && typeof v["code"] === "string" && typeof v["message"] === "string") {
    return v as unknown as AiuxError;
  }
  return { code: "stream_error", message: typeof v === "string" ? v : fallback };
};

const toolIdOf = (part: AiSdkStreamPart, fallbackSeq: number): string =>
  firstString(part["toolCallId"], part["toolId"], part["id"]) ?? `tool-${fallbackSeq}`;

/**
 * Map one AI SDK stream part → AIUX events. Returns [] for parts the
 * protocol has no lifecycle event for (they're reported via `onIssue`).
 */
export function mapAiSdkPart(
  part: AiSdkStreamPart,
  factory: EventFactory,
  target: NormalizeTarget,
  onIssue: (issue: AdapterIssue) => void,
): AiuxEvent[] {
  const skip = (reason: string): AiuxEvent[] => {
    onIssue({ kind: "unhandled", reason, raw: part.type });
    return [];
  };

  switch (part.type) {
    case "text-delta": {
      const delta = firstString(part["delta"], part["textDelta"], part["text"]);
      if (delta === undefined) return skip("missing-delta");
      return [factory.textDelta(target.messageId, target.partId, delta)];
    }
    // v4 tool-call / v5 tool-input-available → tool.started
    case "tool-call":
    case "tool-input-available": {
      const tool: Tool = {
        id: toolIdOf(part, factory.peekSequence()),
        name: firstString(part["toolName"], part["name"]) ?? "tool",
        status: "running",
        ...(part["args"] !== undefined && { input: part["args"] }),
        ...(part["input"] !== undefined && { input: part["input"] }),
      };
      return [factory.toolStarted(tool)];
    }
    // v5 tool-input-start: call begins, args stream in later.
    case "tool-input-start": {
      const tool: Tool = {
        id: toolIdOf(part, factory.peekSequence()),
        name: firstString(part["toolName"], part["name"]) ?? "tool",
        status: "running",
      };
      return [factory.toolStarted(tool)];
    }
    // v4 tool-result / v5 tool-output-available → tool.completed
    case "tool-result":
    case "tool-output-available": {
      const result = part["result"] ?? part["output"];
      return [factory.toolCompleted(toolIdOf(part, factory.peekSequence()), result)];
    }
    case "tool-error":
    case "tool-output-error": {
      const error = asError(part["error"] ?? part["errorText"], "tool error");
      return [factory.toolFailed(toolIdOf(part, factory.peekSequence()), error)];
    }
    // Run lifecycle.
    case "finish":
      return [
        factory.runCompleted(target.runId, {
          ...(part["finishReason"] !== undefined && { finishReason: part["finishReason"] }),
          ...(part["usage"] !== undefined && { usage: part["usage"] }),
        }),
      ];
    case "error": {
      const raw = part["error"];
      const message =
        firstString(part["errorText"]) ??
        (raw instanceof Error ? raw.message : undefined) ??
        (typeof raw === "string" ? raw : "ai-sdk stream error");
      return [
        factory.runFailed(target.runId, {
          code: "stream_error",
          message,
          ...(isRecord(raw) && raw["code"] !== undefined ? { detail: raw } : {}),
        }),
      ];
    }
    case "abort":
      return [factory.runCancelled(target.runId, firstString(part["reason"]))];
    // Lifecycle/structural parts the protocol doesn't model — informational.
    case "start":
    case "start-step":
    case "finish-step":
    case "text-start":
    case "text-end":
    case "message-metadata":
      return skip("no-protocol-event");
    default:
      return skip("unhandled-part");
  }
}

/**
 * Adapt an AI SDK stream (`streamText().fullStream`, `UIMessageStream`, or
 * any `AsyncIterable` of part-shaped objects) into `AIUXEvent[]` batches —
 * one batch per mapped part. Pair with `streamToBatches` to re-chunk for
 * `dispatchBatch`.
 */
export function createAiSdkAdapter(
  stream: AsyncIterable<AiSdkStreamPart>,
  options: AiSdkAdapterOptions,
): EventBatchSource {
  const onIssue = options.onIssue ?? (() => undefined);
  const factory = options.factory ?? createEventFactory(options.sessionId);
  const streamRef = stream;

  async function* iterate(): AsyncGenerator<AiuxEvent[]> {
    // v5 streams tool-input-start → tool-input-delta* → tool-input-available.
    // `tool.started` must fire exactly once per call (the core reducer
    // rejects a second start for the same tool id), so starts are buffered
    // and emitted when tool-input-available lands with the full input — or
    // flushed early when another part references the call, a terminal part
    // arrives, or the stream ends.
    const pendingStarts = new Map<string, Tool>();
    const flush = function* (onlyId?: string): Generator<AiuxEvent[]> {
      for (const [id, tool] of pendingStarts) {
        if (onlyId !== undefined && id !== onlyId) continue;
        pendingStarts.delete(id);
        yield [factory.toolStarted(tool)];
      }
    };
    for await (const part of streamRef) {
      let current = part;
      if (current.type === "tool-input-start") {
        const id = toolIdOf(current, factory.peekSequence());
        pendingStarts.set(id, {
          id,
          name: firstString(current["toolName"], current["name"]) ?? "tool",
          status: "running",
        });
        continue;
      }
      if (current.type === "tool-input-available") {
        const id = toolIdOf(current, factory.peekSequence());
        const pending = pendingStarts.get(id);
        if (pending !== undefined) {
          pendingStarts.delete(id);
          if (firstString(current["toolName"], current["name"]) === undefined) {
            current = { ...current, toolName: pending.name };
          }
        }
      } else if (current.type === "tool-input-delta") {
        // Argument fragments belong to the buffered start — the complete
        // input arrives in `tool-input-available`. Flushing the pending
        // start here would mint a second `tool.started` when `available`
        // lands (the reducer rejects duplicates for the same tool id).
        continue;
      } else if (current.type.startsWith("tool-")) {
        yield* flush(toolIdOf(current, factory.peekSequence()));
      } else if (
        current.type === "finish" ||
        current.type === "error" ||
        current.type === "abort"
      ) {
        yield* flush();
      }
      const events = mapAiSdkPart(current, factory, options.target, onIssue);
      if (events.length > 0) yield events;
      if (events.some(isTerminalEvent)) return;
    }
    yield* flush();
  }

  let iterator: AsyncGenerator<AiuxEvent[]> | undefined;
  return {
    [Symbol.asyncIterator]() {
      iterator ??= iterate();
      return iterator;
    },
    close() {
      void iterator?.return(undefined).catch(() => undefined);
    },
  };
}
