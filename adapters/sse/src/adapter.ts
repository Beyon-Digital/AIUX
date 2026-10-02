import type { AiuxEvent } from "@beyondigital/aiux-protocol-types";
import {
  createEventFactory,
  createWireNormalizer,
  isTerminalEvent,
  type AdapterIssue,
  type EventBatchSource,
  type EventFactory,
  type NormalizeTarget,
  type WireNormalizer,
} from "@beyondigital/aiux-transport-js";

export interface SseReconnectPolicy {
  /** Max reconnect attempts after a drop/failure. Default Infinity. */
  maxRetries?: number;
  /** First retry delay in ms. Default 500. */
  initialDelayMs?: number;
  /** Delay cap in ms. Default 30_000. */
  maxDelayMs?: number;
  /** Honor the stream's `retry:` field for the next delay. Default true. */
  honorServerRetry?: boolean;
}

export interface SseAdapterOptions {
  /** SSE endpoint. The adapter sends `Accept: text/event-stream`. */
  url: string;
  /** Extra fetch init — headers, method/body for POST-style SSE, credentials. */
  init?: RequestInit;
  /** Custom fetch (auth wrappers, RN/test shims). Defaults to globalThis.fetch. */
  fetchFn?: typeof fetch;
  /** Session the minted envelopes belong to. */
  sessionId: string;
  /** Ids normalized events point at (run/message/part). */
  target: NormalizeTarget;
  /** Factory override (e.g. to resume sequence). One is created otherwise. */
  factory?: EventFactory;
  /** Custom wire→events mapping; defaults to `createWireNormalizer`. */
  normalize?: WireNormalizer;
  /** Reconnect on transport failure/drop. `true` = defaults. Default true. */
  reconnect?: boolean | SseReconnectPolicy;
  /** External cancellation — aborts in-flight fetches and ends the stream. */
  signal?: AbortSignal;
  /** Non-fatal observations: malformed lines, skipped items, retries. */
  onIssue?: (issue: AdapterIssue) => void;
}

export interface SseAdapter extends EventBatchSource {
  /** Most recent `id:` field — sent as `Last-Event-ID` on reconnect. */
  readonly lastEventId: string | undefined;
  readonly lastEventIdHeader: string | undefined;
}

/** One decoded SSE message (spec §9: `data`/`event`/`id`/`retry` fields). */
interface SseMessage {
  data: string;
  event?: string;
}

const DEFAULT_RETRY: Required<Omit<SseReconnectPolicy, "honorServerRetry">> = {
  maxRetries: Number.POSITIVE_INFINITY,
  initialDelayMs: 500,
  maxDelayMs: 30_000,
};

const sleep = (ms: number, signal: AbortSignal): Promise<void> =>
  new Promise((resolve, reject) => {
    const t = setTimeout(() => {
      signal.removeEventListener("abort", onAbort);
      resolve();
    }, ms);
    const onAbort = () => {
      clearTimeout(t);
      reject(new Error("aborted"));
    };
    if (signal.aborted) {
      clearTimeout(t);
      reject(new Error("aborted"));
      return;
    }
    signal.addEventListener("abort", onAbort, { once: true });
  });

/** Parse complete SSE lines out of a text chunk; returns emitted messages. */
class SseLineParser {
  private buffer = "";
  private dataLines: string[] = [];
  private eventField: string | undefined;
  private lastId: string | undefined;
  /** Latest `retry:` field value seen, for the next reconnect delay. */
  serverRetryMs: number | undefined;

  constructor(private readonly onIssue: (issue: AdapterIssue) => void) {}

  get lastEventId(): string | undefined {
    return this.lastId;
  }

  feed(chunk: string): SseMessage[] {
    this.buffer += chunk;
    const out: SseMessage[] = [];
    let idx;
    // Split on \n, \r\n, or \r per the SSE spec.
    while ((idx = this.buffer.search(/\r\n|\r|\n/)) >= 0) {
      const line = this.buffer.slice(0, idx);
      const sep = this.buffer[idx] === "\r" && this.buffer[idx + 1] === "\n" ? 2 : 1;
      this.buffer = this.buffer.slice(idx + sep);
      const msg = this.line(line);
      if (msg) out.push(msg);
    }
    return out;
  }

  /** Flush any trailing unterminated line at EOF. */
  end(): SseMessage[] {
    const out: SseMessage[] = [];
    if (this.buffer.length > 0) {
      const msg = this.line(this.buffer);
      if (msg) out.push(msg);
    }
    this.buffer = "";
    const msg = this.dispatch();
    if (msg) out.push(msg);
    return out;
  }

  private dispatch(): SseMessage | undefined {
    if (this.dataLines.length === 0) {
      this.eventField = undefined;
      return undefined;
    }
    const msg: SseMessage = {
      data: this.dataLines.join("\n"),
      ...(this.eventField !== undefined && { event: this.eventField }),
    };
    this.dataLines = [];
    this.eventField = undefined;
    return msg;
  }

  private line(line: string): SseMessage | undefined {
    if (line === "") return this.dispatch();
    if (line.startsWith(":")) return undefined; // comment / keep-alive
    const colon = line.indexOf(":");
    const field = colon === -1 ? line : line.slice(0, colon);
    // A leading space after the colon is stripped, exactly one.
    let value = colon === -1 ? "" : line.slice(colon + 1);
    if (value.startsWith(" ")) value = value.slice(1);
    switch (field) {
      case "data":
        this.dataLines.push(value);
        break;
      case "event":
        this.eventField = value;
        break;
      case "id":
        // Spec: an `id` containing NUL must not update lastEventId.
        if (!value.includes("\u0000")) this.lastId = value;
        break;
      case "retry": {
        const ms = Number(value);
        if (Number.isFinite(ms) && ms >= 0) this.serverRetryMs = ms;
        break;
      }
      default:
        // Unknown fields are ignored per spec — not malformed.
        break;
    }
    return undefined;
  }
}

/**
 * Consume an SSE endpoint as `AIUXEvent[]` batches. Uses `fetch` +
 * `ReadableStream` (portable across browsers, Node 18+, and RN fetch
 * polyfills) rather than `EventSource`, so POST bodies and custom auth
 * headers work everywhere.
 *
 * Malformed `data` JSON and unrecognized items are reported via `onIssue`
 * and skipped — the stream never throws mid-iteration. Transport failures
 * trigger reconnect (with `Last-Event-ID` and server `retry:` honored)
 * until the retry budget is exhausted, then the generator throws the last
 * transport error.
 */
export function createSseAdapter(options: SseAdapterOptions): SseAdapter {
  const fetchFn = options.fetchFn ?? globalThis.fetch?.bind(globalThis);
  const onIssue = options.onIssue ?? (() => undefined);
  const factory = options.factory ?? createEventFactory(options.sessionId);
  const normalize =
    options.normalize ??
    createWireNormalizer({ factory, target: options.target, onIssue });
  const reconnect =
    options.reconnect === false
      ? null
      : { ...DEFAULT_RETRY, ...(typeof options.reconnect === "object" ? options.reconnect : {}) };
  const honorServerRetry = reconnect !== null &&
    (typeof options.reconnect !== "object" || options.reconnect.honorServerRetry !== false);

  const control = new AbortController();
  const external = options.signal;
  external?.addEventListener("abort", () => control.abort(), { once: true });
  if (external?.aborted) control.abort();

  const state = { closed: false, lastEventId: undefined as string | undefined };

  const transportError = (reason: string, error: unknown): void => {
    onIssue({ kind: "transport", reason, raw: error instanceof Error ? error.message : error });
  };

  async function* iterate(): AsyncGenerator<AiuxEvent[]> {
    if (!fetchFn) throw new Error("no fetch implementation available — pass fetchFn");
    let attempt = 0;
    let serverRetryMs: number | undefined;
    let sawTerminal = false;

    while (!state.closed && !control.signal.aborted) {
      try {
        const headers = new Headers(options.init?.headers);
        headers.set("Accept", "text/event-stream");
        if (state.lastEventId !== undefined) {
          headers.set("Last-Event-ID", state.lastEventId);
        }
        const response = await fetchFn(options.url, {
          ...options.init,
          headers,
          signal: control.signal,
        });
        if (!response.ok) {
          throw new Error(`SSE HTTP ${response.status}`);
        }
        if (!response.body) {
          throw new Error("SSE response has no body stream");
        }

        const parser = new SseLineParser(onIssue);
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        try {
          for (;;) {
            const { done, value } = await reader.read();
            const messages = done
              ? parser.end()
              : parser.feed(decoder.decode(value, { stream: true }));
            for (const msg of messages) {
              if (parser.lastEventId !== undefined) {
                state.lastEventId = parser.lastEventId;
              }
              if (parser.serverRetryMs !== undefined) {
                serverRetryMs = parser.serverRetryMs;
              }
              let parsed: unknown;
              try {
                parsed = JSON.parse(msg.data);
              } catch {
                const trimmed = msg.data.trim();
                if (trimmed === "[DONE]") {
                  // Provider stream terminator — the normalizer owns the
                  // sentinel→lifecycle mapping.
                  parsed = trimmed;
                } else {
                  try {
                    // Providers sometimes split a JSON string across `data:`
                    // lines; the spec joins them with real newlines, which
                    // strict JSON rejects. Escape raw control whitespace so
                    // the payload still parses (newlines survive as content).
                    parsed = JSON.parse(
                      trimmed
                        .replace(/\n/g, "\\n")
                        .replace(/\r/g, "\\r")
                        .replace(/\t/g, "\\t"),
                    );
                  } catch {
                    onIssue({
                      kind: "malformed",
                      reason: "invalid-json",
                      raw: msg.data,
                    });
                    continue;
                  }
                }
              }
              // The `event:` field supplies `type` when the data lacks one.
              if (
                msg.event !== undefined &&
                typeof parsed === "object" &&
                parsed !== null &&
                !Array.isArray(parsed) &&
                (parsed as Record<string, unknown>)["type"] === undefined
              ) {
                parsed = { type: msg.event, ...(parsed as Record<string, unknown>) };
              }
              const events = normalize(parsed);
              if (events.length > 0) {
                if (events.some(isTerminalEvent)) sawTerminal = true;
                yield events;
              }
            }
            if (done) break;
          }
        } finally {
          reader.releaseLock();
        }
        // Clean EOF: stop on terminal event or when reconnect is disabled;
        // otherwise treat as a drop and reconnect.
        if (sawTerminal || state.closed || reconnect === null) return;
      } catch (error) {
        if (state.closed || control.signal.aborted) return;
        transportError("transport-failure", error);
        if (reconnect === null) throw error;
      }

      if (reconnect === null) return;
      if (attempt >= reconnect.maxRetries) {
        throw new Error(`SSE reconnect budget exhausted after ${attempt} attempts`);
      }
      const base = honorServerRetry && serverRetryMs !== undefined && attempt === 0
        ? serverRetryMs
        : reconnect.initialDelayMs * 2 ** attempt;
      const delayMs = Math.min(base, reconnect.maxDelayMs);
      onIssue({ kind: "transport", reason: "reconnecting", raw: { attempt, delayMs } });
      await sleep(delayMs, control.signal);
      attempt += 1;
    }
  }

  let iterator: AsyncGenerator<AiuxEvent[]> | undefined;
  return {
    get lastEventId() {
      return state.lastEventId;
    },
    get lastEventIdHeader() {
      return state.lastEventId;
    },
    [Symbol.asyncIterator]() {
      iterator ??= iterate();
      return iterator;
    },
    close() {
      state.closed = true;
      control.abort();
      void iterator?.return(undefined).catch(() => undefined);
    },
  };
}
