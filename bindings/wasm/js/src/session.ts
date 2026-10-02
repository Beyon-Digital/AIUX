import type { AiuxCore, SessionHandle } from "./core.js";
import { parseCoreJson, translateCoreErrors } from "./errors.js";
import type {
  AiuxEvent,
  DispatchReport,
  JsonObject,
  JsonString,
  SessionConfig,
  SessionSnapshot,
} from "./types.js";

/** Session lifecycle: `active` after create/restore, `disposed` after dispose(). */
export type SessionLifecycle = "active" | "disposed";

/** Called with the fresh snapshot after every successful state mutation. */
export type SnapshotListener = (snapshot: SessionSnapshot) => void;

export interface AiuxSessionOptions {
  /**
   * Sink for exceptions thrown by snapshot listeners. Defaults to rethrowing
   * each one asynchronously so a renderer bug can never corrupt or silently
   * abort the dispatch path.
   */
  onListenerError?: (error: unknown, listener: SnapshotListener) => void;
}

/** Thrown when a session method is called after `dispose()`. */
export class SessionDisposedError extends Error {
  constructor() {
    super("aiux-core: session is disposed");
    this.name = "SessionDisposedError";
  }
}

function toJsonString(value: JsonObject | JsonString): string {
  return typeof value === "string" ? value : JSON.stringify(value);
}

/**
 * JS wrapper over the frozen AIUX session facade (docs/PLAN.md §4, ADR 0005).
 *
 * Mirrors the Rust contract exactly — `dispatch`, `dispatchBatch`,
 * `snapshot`, `serialize`, `reset` — and adds only ergonomics: typed parse of
 * returned JSON, `subscribe()` snapshot observation for renderers, and
 * disposal lifecycle guarding use-after-free. All state semantics stay in the
 * core; this class never inspects payloads.
 */
export class AiuxSession {
  readonly #core: AiuxCore;
  readonly #onListenerError: AiuxSessionOptions["onListenerError"];
  #handle: SessionHandle | undefined;
  #lifecycle: SessionLifecycle = "active";
  #listeners = new Set<SnapshotListener>();

  private constructor(
    core: AiuxCore,
    handle: SessionHandle,
    options: AiuxSessionOptions,
  ) {
    this.#core = core;
    this.#handle = handle;
    this.#onListenerError = options.onListenerError;
  }

  /** Create a session from a config object or its JSON serialization. */
  static create(
    core: AiuxCore,
    config: SessionConfig | JsonString,
    options: AiuxSessionOptions = {},
  ): AiuxSession {
    const configJson = toJsonString(config);
    const handle = translateCoreErrors(() => core.createSession(configJson));
    return new AiuxSession(core, handle, options);
  }

  /** Restore a session from a previous `serialize()` payload. */
  static restore(
    core: AiuxCore,
    serializedJson: JsonString,
    options: AiuxSessionOptions = {},
  ): AiuxSession {
    const handle = translateCoreErrors(() =>
      core.restoreSession(serializedJson),
    );
    return new AiuxSession(core, handle, options);
  }

  get lifecycle(): SessionLifecycle {
    return this.#lifecycle;
  }

  /** Reduce one event into session state. */
  dispatch(event: AiuxEvent | JsonString): DispatchReport {
    const reportJson = translateCoreErrors(() =>
      this.#core.dispatch(this.#requireHandle(), toJsonString(event)),
    );
    const report = parseCoreJson(reportJson, "dispatch report");
    this.#notify();
    return report as DispatchReport;
  }

  /**
   * Reduce an ordered array of events in one core call (plan §22 — streaming
   * deltas batch here; pair with {@link EventBuffer}).
   */
  dispatchBatch(events: readonly (AiuxEvent | JsonString)[] | JsonString): DispatchReport {
    const eventsJson =
      typeof events === "string"
        ? events
        : `[${events.map((e) => toJsonString(e)).join(",")}]`;
    const reportJson = translateCoreErrors(() =>
      this.#core.dispatchBatch(this.#requireHandle(), eventsJson),
    );
    const report = parseCoreJson(reportJson, "dispatch report");
    this.#notify();
    return report as DispatchReport;
  }

  /** Canonical-JSON render snapshot for the current state (parsed). */
  snapshot(): SessionSnapshot {
    const snapshotJson = translateCoreErrors(() =>
      this.#core.snapshot(this.#requireHandle()),
    );
    return parseCoreJson(snapshotJson, "snapshot") as SessionSnapshot;
  }

  /** Canonical-JSON serialized session state (persistence/replay). */
  serialize(): JsonString {
    return translateCoreErrors(() =>
      this.#core.serialize(this.#requireHandle()),
    );
  }

  /** Clear all session state. */
  reset(): void {
    translateCoreErrors(() => this.#core.reset(this.#requireHandle()));
    this.#notify();
  }

  /**
   * Observe snapshots for rendering. The listener fires synchronously once
   * with the current snapshot, then again after every successful
   * `dispatch`/`dispatchBatch`/`reset`. Returns an unsubscribe function.
   */
  subscribe(listener: SnapshotListener): () => void {
    this.#requireHandle();
    this.#listeners.add(listener);
    try {
      this.#notifyOne(listener);
    } catch (error) {
      this.#listeners.delete(listener);
      throw error;
    }
    return () => {
      this.#listeners.delete(listener);
    };
  }

  /**
   * Release the session. Idempotent; frees the wasm handle when the core
   * provides `freeSession`. All other methods throw `SessionDisposedError`
   * afterwards.
   */
  dispose(): void {
    if (this.#lifecycle === "disposed") return;
    this.#lifecycle = "disposed";
    this.#listeners.clear();
    const handle = this.#handle;
    this.#handle = undefined;
    this.#core.freeSession?.(handle);
  }

  #requireHandle(): SessionHandle {
    if (this.#lifecycle === "disposed" || this.#handle === undefined) {
      throw new SessionDisposedError();
    }
    return this.#handle;
  }

  #notify(): void {
    if (this.#listeners.size === 0) return;
    // snapshot() reads current state; failures propagate as core errors.
    const snapshot = this.snapshot();
    for (const listener of this.#listeners) {
      try {
        listener(snapshot);
      } catch (error) {
        this.#reportListenerError(error, listener);
      }
    }
  }

  #notifyOne(listener: SnapshotListener): void {
    // A snapshot() failure is a core error — propagate it (the caller never
    // got the promised initial snapshot), do not misroute it to the
    // listener-error sink.
    const snapshot = this.snapshot();
    try {
      listener(snapshot);
    } catch (error) {
      this.#reportListenerError(error, listener);
    }
  }

  #reportListenerError(error: unknown, listener: SnapshotListener): void {
    const handler = this.#onListenerError;
    if (handler) {
      try {
        handler(error, listener);
      } catch (handlerError) {
        // The error handler itself threw — report it asynchronously so a
        // completed dispatch is never reported as failed.
        queueMicrotask(() => {
          throw handlerError;
        });
      }
      return;
    }
    // A listener bug must not corrupt or silently abort the dispatch path —
    // surface it asynchronously instead.
    queueMicrotask(() => {
      throw error;
    });
  }
}
