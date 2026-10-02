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

/**
 * The slice of the `WebSocket` contract the adapter needs — satisfied by the
 * browser/Node-22 global and by `ws`. Both `addEventListener` and the
 * `on*` property handlers are supported.
 */
export interface WebSocketLike {
  readonly readyState?: number;
  send(data: string): void;
  close(code?: number, reason?: string): void;
  addEventListener?(type: string, listener: (event: never) => void): void;
  removeEventListener?(type: string, listener: (event: never) => void): void;
  onopen?: ((event: unknown) => void) | null;
  onmessage?: ((event: { data: unknown }) => void) | null;
  onclose?: ((event: { code: number; reason?: string }) => void) | null;
  onerror?: ((event: unknown) => void) | null;
}

export type WebSocketFactory = (
  url: string,
  protocols?: string | string[],
) => WebSocketLike;

export interface WsReconnectPolicy {
  /** Max reconnect attempts after an abnormal close. Default Infinity. */
  maxRetries?: number;
  /** First retry delay in ms. Default 500. */
  initialDelayMs?: number;
  /** Delay cap in ms. Default 30_000. */
  maxDelayMs?: number;
}

export interface WsAdapterOptions {
  url: string;
  /** Subprotocols for the handshake. */
  protocols?: string | string[];
  /** Socket factory — defaults to the global `WebSocket` (browser/Node 22+,
   * RN). Pass `ws`'s constructor on older Node. */
  webSocketFactory?: WebSocketFactory;
  /** Session the minted envelopes belong to. */
  sessionId: string;
  /** Ids normalized events point at (run/message/part). */
  target: NormalizeTarget;
  factory?: EventFactory;
  normalize?: WireNormalizer;
  /** Reconnect after abnormal close. `true` = defaults. Default true. */
  reconnect?: boolean | WsReconnectPolicy;
  signal?: AbortSignal;
  onIssue?: (issue: AdapterIssue) => void;
}

export interface WsAdapter extends EventBatchSource {
  /** Number of times the socket has (re)connected — diagnostics. */
  readonly connections: number;
  /** Send a frame on the live socket, if connected. */
  send(data: string): void;
}

const DEFAULT_RETRY: Required<WsReconnectPolicy> = {
  maxRetries: Number.POSITIVE_INFINITY,
  initialDelayMs: 500,
  maxDelayMs: 30_000,
};

const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

/** Push→pull bridge between socket callbacks and the async iterator. */
class EventQueue {
  private items: AiuxEvent[][] = [];
  private waiters: Array<{
    resolve: (r: IteratorResult<AiuxEvent[]>) => void;
    reject: (e: unknown) => void;
  }> = [];
  private done = false;
  private failure: unknown;

  push(batch: AiuxEvent[]): void {
    if (this.done || batch.length === 0) return;
    const w = this.waiters.shift();
    if (w) w.resolve({ value: batch, done: false });
    else this.items.push(batch);
  }

  finish(): void {
    if (this.done) return;
    this.done = true;
    for (const w of this.waiters.splice(0))
      w.resolve({ value: undefined, done: true });
  }

  fail(error: unknown): void {
    if (this.done) return;
    this.done = true;
    this.failure = error;
    // A pending read must see the transport error, not a clean completion.
    // Buffered batches are kept: next() drains them in order before the
    // stored failure throws once — a socket error must not discard events
    // the server already delivered.
    for (const w of this.waiters.splice(0)) w.reject(error);
  }

  async next(): Promise<IteratorResult<AiuxEvent[]>> {
    const item = this.items.shift();
    if (item !== undefined) return { value: item, done: false };
    if (this.done) {
      if (this.failure !== undefined) {
        const f = this.failure;
        this.failure = undefined;
        throw f;
      }
      return { value: undefined, done: true };
    }
    return new Promise((resolve, reject) =>
      this.waiters.push({ resolve, reject }),
    );
  }
}

const CLOSED_BY_US = 1000;

/**
 * Consume a WebSocket endpoint as `AIUXEvent[]` batches — the same
 * normalization surface as the SSE adapter.
 *
 * Ordering: a single WebSocket connection delivers messages in order, so
 * batches within one connection preserve wire order. Across a reconnect the
 * server may resend or skip frames — sequence continuity is *not*
 * guaranteed; the core's reorder buffer + idempotency ledger absorb both
 * duplicates and gaps (conformance: `out-of-order-events`,
 * `duplicate-events`). Servers should resume from a checkpoint token in the
 * URL/subprotocol when ordering must survive reconnects.
 *
 * Malformed frames are reported via `onIssue` and skipped; the adapter never
 * throws mid-stream. Abnormal closes reconnect with exponential backoff
 * until the retry budget is exhausted, then the iterator throws.
 */
export function createWebSocketAdapter(options: WsAdapterOptions): WsAdapter {
  const wsFactory: WebSocketFactory | undefined =
    options.webSocketFactory ??
    (typeof globalThis !== "undefined" && "WebSocket" in globalThis
      ? ((url, protocols) => new WebSocket(url, protocols) as unknown as WebSocketLike)
      : undefined);
  const onIssue = options.onIssue ?? (() => undefined);
  const factory = options.factory ?? createEventFactory(options.sessionId);
  const normalize =
    options.normalize ??
    createWireNormalizer({ factory, target: options.target, onIssue });
  const reconnect =
    options.reconnect === false
      ? null
      : { ...DEFAULT_RETRY, ...(typeof options.reconnect === "object" ? options.reconnect : {}) };

  const queue = new EventQueue();
  const state = {
    closed: false,
    connections: 0,
    socket: undefined as WebSocketLike | undefined,
    sawTerminal: false,
    attempt: 0,
    intentionalClose: false,
  };
  options.signal?.addEventListener("abort", () => adapter.close?.(), { once: true });

  const detach = (ws: WebSocketLike): void => {
    ws.onopen = ws.onmessage = ws.onclose = ws.onerror = null;
  };

  const wire = (ws: WebSocketLike): void => {
    ws.onopen = () => {
      state.connections += 1;
      state.attempt = 0;
    };
    ws.onmessage = (ev: { data: unknown }) => {
      let parsed: unknown;
      try {
        parsed = typeof ev.data === "string" ? JSON.parse(ev.data) : ev.data;
      } catch {
        onIssue({ kind: "malformed", reason: "invalid-json", raw: ev.data });
        return;
      }
      const events = normalize(parsed);
      queue.push(events);
      if (events.some(isTerminalEvent)) {
        state.sawTerminal = true;
        // The run ended — close the socket instead of waiting for the server.
        adapter.close?.();
      }
    };
    ws.onerror = (ev: unknown) => {
      onIssue({ kind: "transport", reason: "socket-error", raw: String(ev) });
    };
    ws.onclose = (ev: { code: number; reason?: string }) => {
      detach(ws);
      if (state.socket === ws) state.socket = undefined;
      const normal = ev.code === CLOSED_BY_US || state.intentionalClose;
      if (state.closed || state.sawTerminal || normal) {
        queue.finish();
        return;
      }
      if (reconnect === null || state.attempt >= reconnect.maxRetries) {
        if (reconnect === null) {
          queue.fail(new Error(`WebSocket closed abnormally (code ${ev.code})`));
        } else {
          queue.fail(
            new Error(`WebSocket reconnect budget exhausted (code ${ev.code})`),
          );
        }
        return;
      }
      const delayMs = Math.min(
        reconnect.initialDelayMs * 2 ** state.attempt,
        reconnect.maxDelayMs,
      );
      state.attempt += 1;
      onIssue({
        kind: "transport",
        reason: "reconnecting",
        raw: { attempt: state.attempt, delayMs, code: ev.code },
      });
      void sleep(delayMs).then(() => {
        if (state.closed) return;
        try {
          connect();
        } catch (error) {
          queue.fail(error);
        }
      });
    };
  };

  const connect = (): void => {
    if (!wsFactory) throw new Error("no WebSocket implementation — pass webSocketFactory");
    const ws = wsFactory(options.url, options.protocols);
    state.socket = ws;
    wire(ws);
  };

  let pumpStarted = false;
  const adapter: WsAdapter = {
    get connections() {
      return state.connections;
    },
    send(data: string) {
      state.socket?.send(data);
    },
    [Symbol.asyncIterator]() {
      if (!pumpStarted) {
        pumpStarted = true;
        try {
          connect();
        } catch (error) {
          queue.fail(error);
        }
      }
      const queueIt = queue as unknown as AsyncIterator<AiuxEvent[]>;
      let finished = false;
      // A consumed queue failure held while buffered starts drain — thrown
      // on the read after they are delivered so the transport error
      // surfaces exactly once (EventQueue clears `failure` as it throws).
      let heldFailure: { error: unknown } | undefined;
      const drain = (): AiuxEvent[] => {
        finished = true;
        return normalize.finish?.() ?? [];
      };
      // `for await..of` breaking early calls `return()` — route it to
      // `close()` so the socket (and reconnect loop) tears down too.
      return {
        next: async () => {
          if (heldFailure !== undefined) {
            const { error } = heldFailure;
            heldFailure = undefined;
            throw error;
          }
          try {
            const result = await queueIt.next();
            if (!result.done || finished) return result;
            // Queue drained — seal buffered tool calls so a truncated call
            // still emits `tool.started` before the stream reports done.
            const finishing = drain();
            if (finishing.length > 0) return { value: finishing, done: false };
            return result;
          } catch (error) {
            // A terminal socket failure must still surface buffered starts
            // first — consumers stop iterating on the rejection.
            if (finished) throw error;
            const finishing = drain();
            if (finishing.length > 0) {
              heldFailure = { error };
              return { value: finishing, done: false };
            }
            throw error;
          }
        },
        return: async () => {
          adapter.close?.();
          return { value: undefined, done: true };
        },
      };
    },
    close() {
      if (state.closed) return;
      state.closed = true;
      state.intentionalClose = true;
      try {
        state.socket?.close(CLOSED_BY_US, "adapter closed");
      } finally {
        if (state.socket) detach(state.socket);
        state.socket = undefined;
        queue.finish();
      }
    },
  };
  return adapter;
}
