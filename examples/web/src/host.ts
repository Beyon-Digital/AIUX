/**
 * Example host — the code a real application embedder writes:
 *   init wasm → AiuxSession → createEventDriver → <AIConversation/>
 * plus a minimal host policy that turns user actions back into protocol
 * events (composer echo + scripted assistant stream, approval resolutions).
 */
import {
  AiuxSession,
  wasmCore,
  type AiuxEvent,
} from "@beyondigital/aiux-core";
import {
  AIUX_ACTIONS,
  createEventDriver,
  type AiuxAction,
  type AiuxEventDriver,
} from "@beyondigital/aiux-web";
import init, * as wasm from "@beyondigital/aiux-core/wasm";
import wasmUrl from "@beyondigital/aiux-core/wasm/aiux_wasm_bg.wasm?url";

let coreReady: Promise<ReturnType<typeof wasmCore>> | undefined;

export function loadCore(): Promise<ReturnType<typeof wasmCore>> {
  coreReady ??= init({ module_or_path: wasmUrl }).then(() => wasmCore(wasm));
  return coreReady;
}

export interface LiveSession {
  session: AiuxSession;
  driver: AiuxEventDriver;
  /** Next sequence for host-synthesized events (fixture events carry their own). */
  seq: number;
  dispose(): void;
}

interface SerializedState {
  nextExpectedSequence?: number;
}

function nextSequence(session: AiuxSession): number {
  const state = JSON.parse(session.serialize()) as SerializedState;
  return state.nextExpectedSequence ?? 0;
}

/** Open an empty session. */
export function openSession(): Promise<LiveSession> {
  return loadCore().then((core) => {
    const session = AiuxSession.create(core, "{}");
    const driver = createEventDriver(session, { flushIntervalMs: 32 });
    return {
      session,
      driver,
      seq: 0,
      dispose() {
        driver.close();
        session.dispose();
      },
    };
  });
}

/** Replay a conformance fixture — instant or streamed through EventBuffer. */
export async function replayFixture(
  live: LiveSession,
  events: readonly AiuxEvent[],
  mode: "instant" | "stream",
  onProgress?: (done: number, total: number) => void,
): Promise<void> {
  const { session, driver } = live;
  if (mode === "instant") {
    session.dispatchBatch(events);
    onProgress?.(events.length, events.length);
  } else {
    for (const [i, event] of events.entries()) {
      driver.queue(event);
      onProgress?.(i + 1, events.length);
      // Let the EventBuffer coalesce a few deltas per flush — this is the
      // exact path a live transport takes (§22).
      await sleep(18);
    }
    driver.flush();
  }
  live.seq = nextSequence(session);
}

/* ── Host policy: turn renderer actions into protocol events ────────── */

function hostEvent(
  live: LiveSession,
  type: string,
  payload: Record<string, unknown>,
): AiuxEvent {
  const sequence = live.seq++;
  return {
    protocolVersion: "0.1",
    sessionId: "s1",
    sequence,
    timestamp: new Date().toISOString(),
    eventId: `host-${type}-${sequence}-${Math.random().toString(36).slice(2, 8)}`,
    type,
    payload: { protocolVersion: "0.1", ...payload },
  };
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * The demo's tiny scripted agent: acknowledges the user's message with a
 * streamed assistant reply — exercising part.added + text.delta batching.
 */
async function scriptedReply(
  live: LiveSession,
  userText: string,
): Promise<void> {
  const { driver } = live;
  const runId = `run-${live.seq}`;
  const messageId = `asst-${live.seq}`;
  const partId = `asst-${live.seq}-p0`;
  const reply =
    `You said “${userText.slice(0, 140)}”. This is a scripted ` +
    `streaming reply — every token travelled through ` +
    `EventBuffer → dispatchBatch on the real wasm core.`;

  const emit = (type: string, payload: Record<string, unknown>) =>
    driver.queue(hostEvent(live, type, payload));

  emit("run.started", {
    run: { id: runId, status: "running", startedAt: new Date().toISOString() },
  });
  emit("message.created", {
    message: { id: messageId, role: "assistant", status: "streaming" },
  });
  emit("part.added", {
    messageId,
    part: { id: partId, type: "text", text: "" },
  });
  driver.flush();
  for (const token of reply.split(/(?<=\s)/)) {
    emit("text.delta", { messageId, partId, delta: token });
    await sleep(24);
  }
  emit("message.updated", { messageId, status: "complete" });
  emit("run.completed", { runId, result: { ok: true } });
  // Keep the driver open — the next composer submit queues more events.
  driver.flush();
}

/** Host action handler — every AIUX action lands here (§23). */
export function createActionHandler(
  live: LiveSession,
  log: (line: string) => void,
): (action: AiuxAction) => void {
  const { session } = live;
  return (action) => {
    log(`${action.id} ${JSON.stringify(action.payload ?? {})}`);
    switch (action.id) {
      case AIUX_ACTIONS.composerSubmit: {
        const text = String(action.payload?.text ?? "").trim();
        if (!text) return;
        session.dispatch(
          hostEvent(live, "message.created", {
            message: {
              id: `user-${live.seq}`,
              role: "user",
              status: "complete",
              parts: [
                {
                  id: `user-${live.seq}-p0`,
                  type: "text",
                  text,
                },
              ],
            },
          }),
        );
        void scriptedReply(live, text);
        return;
      }
      case AIUX_ACTIONS.approvalResolve: {
        const { approvalId, decision } = action.payload ?? {};
        session.dispatch(
          hostEvent(live, "approval.resolved", {
            approvalId,
            resolution: {
              decision,
              resolvedBy: "user",
              resolvedAt: new Date().toISOString(),
            },
          }),
        );
        return;
      }
      case AIUX_ACTIONS.errorRetry:
      case AIUX_ACTIONS.artifactOpen:
      case AIUX_ACTIONS.surfaceInput:
      case AIUX_ACTIONS.composerAttach:
      default:
        // Logged above — deeper host behaviors (re-run, upload, artifact
        // viewer) are app policy, not renderer concern.
        return;
    }
  };
}
