import { getNativeModule } from "./AIUXNative";
import type {
  AIUXCapability,
  AIUXContextEntity,
  AIUXDispatchReport,
  AIUXEventLike,
} from "./types";

function requireNative() {
  const native = getNativeModule();
  if (!native) {
    throw new Error(
      "@beyondigital/aiux-expo: native module not linked. " +
        "Run `expo prebuild` (or open the app in a dev client build).",
    );
  }
  return native;
}

/** Parameters for the seed `session.created` emitted by `createAIUXSession`. */
export interface AIUXSessionBootstrap {
  sessionId: string;
  title?: string | undefined;
  context?: AIUXContextEntity[] | undefined;
  capabilities?: AIUXCapability[] | undefined;
  /**
   * Sequence for the seed event. The bootstrap is the FIRST event of the
   * session stream, so the seed consumes `sequence: 0` — a producer emitting
   * its own `session.created` must start its sequence after the seed.
   */
  sequence?: number;
}

function asJsonString(value: AIUXEventLike): string {
  return typeof value === "string" ? value : JSON.stringify(value);
}

/** In-flight creates keyed by sessionId — serializes concurrent callers. */
const sessionCreates = new Map<string, Promise<void>>();

/**
 * Create the native `AiuxSession` for `sessionId` and, when a `title`,
 * `context`, or `capabilities` seed is provided, dispatch a `session.created`
 * event carrying them (consumed as the stream's `sequence: 0`).
 *
 * Idempotent at the JS layer: a second call for a session that already holds
 * a session entity skips the seed so producer-owned bootstrap always wins.
 */
export async function createAIUXSession(
  bootstrap: AIUXSessionBootstrap,
): Promise<void> {
  // Serialize per sessionId — two concurrent callers would each pass the
  // empty-snapshot check and both emit the seed at `sequence: 0`.
  const prior = sessionCreates.get(bootstrap.sessionId);
  const run = (prior ?? Promise.resolve())
    .catch(() => undefined)
    .then(() => createSessionOnce(bootstrap));
  sessionCreates.set(bootstrap.sessionId, run);
  try {
    await run;
  } finally {
    if (sessionCreates.get(bootstrap.sessionId) === run) {
      sessionCreates.delete(bootstrap.sessionId);
    }
  }
}

async function createSessionOnce(
  bootstrap: AIUXSessionBootstrap,
): Promise<void> {
  const native = requireNative();
  const { sessionId, title, context, capabilities, sequence = 0 } = bootstrap;
  await native.createSession(
    sessionId,
    JSON.stringify({ protocolVersion: "0.1", sessionId }),
  );

  const wantsSeed =
    title !== undefined || context !== undefined || capabilities !== undefined;
  if (!wantsSeed) return;

  const snapshot = JSON.parse(await native.snapshot(sessionId)) as {
    session?: unknown;
  };
  if (snapshot.session != null) return; // producer already bootstrapped

  const seed = {
    eventId: `bootstrap-${sessionId}`,
    sessionId,
    sequence,
    timestamp: new Date().toISOString(),
    type: "session.created",
    payload: {
      protocolVersion: "0.1",
      session: {
        id: sessionId,
        ...(title !== undefined ? { title } : {}),
        ...(context !== undefined ? { context } : {}),
        ...(capabilities !== undefined ? { capabilities } : {}),
      },
    },
  };
  await native.dispatchBatch(sessionId, JSON.stringify([seed]));
}

/** Dispatch a raw batch of protocol events (JSON strings or objects). */
export async function dispatchAIUXBatch(
  sessionId: string,
  events: AIUXEventLike[],
): Promise<AIUXDispatchReport> {
  const native = requireNative();
  return native.dispatchBatch(
    sessionId,
    JSON.stringify(events.map(asJsonString).map((s) => JSON.parse(s))),
  );
}

/** Serialize the session for persistence/replay. */
export async function serializeAIUXSession(sessionId: string): Promise<string> {
  return requireNative().serialize(sessionId);
}

/** Restore a session previously produced by `serializeAIUXSession`. */
export async function restoreAIUXSession(serializedJson: string): Promise<void> {
  return requireNative().restore(serializedJson);
}

/** Clear all session state (the session remains registered). */
export async function resetAIUXSession(sessionId: string): Promise<void> {
  return requireNative().reset(sessionId);
}

/** Canonical render snapshot for the session (parsed). */
export async function getAIUXSnapshot(
  sessionId: string,
): Promise<Record<string, unknown>> {
  const native = requireNative();
  return JSON.parse(await native.snapshot(sessionId)) as Record<
    string,
    unknown
  >;
}
