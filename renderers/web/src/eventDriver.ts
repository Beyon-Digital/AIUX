import {
  EventBuffer,
  type AiuxEvent,
  type DispatchReport,
  type EventBufferPolicy,
  type JsonString,
} from "@beyondigital/aiux-core";

/**
 * Web transport adapter (plan §12): the bridge between a host event source
 * (SSE/WebSocket/mock) and the core session. `queue()` accumulates protocol
 * events in an `EventBuffer` so streaming deltas reach the core as batched
 * `dispatchBatch` calls — never one FFI call per token (plan §22).
 */
export interface AiuxEventDriver {
  /** Reduce one event immediately. */
  dispatch(event: AiuxEvent | JsonString): DispatchReport;
  /** Queue an event for batched dispatch on the flush policy. */
  queue(event: AiuxEvent | JsonString): void;
  /** Force-dispatch everything queued. */
  flush(): DispatchReport | undefined;
  /** Flush and stop accepting events. */
  close(): DispatchReport | undefined;
  /** Events waiting in the buffer. */
  readonly pending: number;
}

interface SessionDispatch {
  dispatch(event: AiuxEvent | JsonString): DispatchReport;
  dispatchBatch(
    events: readonly (AiuxEvent | JsonString)[] | JsonString,
  ): DispatchReport;
}

export function createEventDriver(
  session: SessionDispatch,
  policy: EventBufferPolicy = {},
): AiuxEventDriver {
  const buffer = new EventBuffer<DispatchReport>(
    (eventsJson) => session.dispatchBatch(eventsJson),
    policy,
  );
  return {
    dispatch: (event) => session.dispatch(event),
    queue: (event) => buffer.push(event),
    flush: () => buffer.flush(),
    close: () => buffer.close(),
    get pending() {
      return buffer.pending;
    },
  };
}
