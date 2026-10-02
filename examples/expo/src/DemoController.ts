import type { AIUXAction, AIUXTransport } from "@beyondigital/aiux-expo";
import {
  createAIUXTransport,
  getAIUXSnapshot,
} from "@beyondigital/aiux-expo";

import { MockAgent, type AiuxEventObject } from "./mockAgent";
import {
  streamChatCompletion,
  type ChatMessage,
  type StreamHandle,
  type ToolCall,
} from "./openrouter";

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

const LIVE_SYSTEM_PROMPT =
  "You are the demo agent inside the AIUX protocol examples. Answer " +
  "concisely in markdown. When the user asks to publish, send, or charge " +
  "an invoice, call the publish_invoice tool — never claim to have " +
  "published without calling it.";

const PUBLISH_INVOICE_TOOL = {
  type: "function" as const,
  function: {
    name: "publish_invoice",
    description:
      "Publish an invoice to the customer — charges the amount and marks " +
      "it sent. Requires user approval before it executes.",
    parameters: {
      type: "object",
      properties: {
        invoiceId: { type: "string", description: "e.g. inv-9" },
      },
      required: ["invoiceId"],
      additionalProperties: false,
    },
  },
};

/**
 * Host-side driver for the mocked agent interaction (Phase 4 gate) — a port
 * of `examples/android-native/DemoController.kt`. `AIUXAction`s flow
 * native → JS here; the library never executes them (plan §23).
 *
 * The transport is the batched `EventBuffer` adapter — every `send()` below
 * coalesces into `dispatchBatch` calls (16–50 ms flush), so streaming deltas
 * never cross the boundary per token.
 */
type ActiveRun = {
  runId: string;
  cancelRequested: boolean;
  // toolTurnPending: a live run whose stream ended in a tool_call — the
  // tool turn owns run completion (the first stream's onDone must not
  // complete it). messageId lets cancel close the streaming message.
  toolTurnPending?: boolean;
  messageId?: string;
};

export class DemoController {
  readonly sessionId: string;
  private readonly transport: AIUXTransport;
  private readonly agent: MockAgent;
  private pendingApproval: ((approved: boolean) => void) | null = null;
  private activeRun: ActiveRun | null = null;
  private messageN = 0;
  private closed = false;
  // Live mode: real OpenRouter inference. `liveHistory` is the chat
  // transcript the model sees (system + prior turns); `liveHandle` is the
  // in-flight stream so cancel can abort it.
  private live = false;
  private liveKey: string | undefined;
  private liveModel = "openrouter/free";
  private liveHistory: ChatMessage[] = [];
  private liveHandle: StreamHandle | undefined;
  private lastPrompt = "";
  /**
   * Per-controller id epoch. A JS remount spawns a fresh controller while
   * the native session persists — entity ids (`m`,`r`,`t`,`a`,`sf`,`u`,`e`)
   * must not collide with ones already committed, or the replayed batch
   * gets rejected and poisons the transport queue.
   */
  private readonly idEpoch: string;

  private constructor(
    sessionId: string,
    idEpoch: string,
    startSequence: number,
    fresh: boolean,
  ) {
    this.sessionId = sessionId;
    this.idEpoch = idEpoch;
    this.agent = new MockAgent(sessionId, `${idEpoch}:`, startSequence);
    this.transport = createAIUXTransport(sessionId, {
      policy: {
        onFlushError: (error) => console.warn("[aiux] dispatchBatch failed", error),
      },
    });
    // Only a brand-new session gets the seed — re-emitting session.created
    // into a persisted session is an InvalidEvent replay.
    if (fresh) {
      this.transport.push(this.agent.sessionCreated("AIUX Expo demo"));
    }
  }

  /**
   * Build a controller that resumes against the persisted native session:
   * sequences continue from `next_expected_sequence`, entity ids carry a
   * fresh epoch, and the session seed is skipped when one already exists.
   */
  static async create(sessionId: string): Promise<DemoController> {
    const snapshot = await getAIUXSnapshot(sessionId).catch(
      () => ({}) as Record<string, unknown>,
    );
    const nextSeq =
      typeof snapshot.next_expected_sequence === "number"
        ? snapshot.next_expected_sequence
        : 0;
    const fresh = snapshot.session == null;
    const idEpoch = `${Date.now().toString(36)}${Math.random()
      .toString(36)
      .slice(2, 5)}`;
    return new DemoController(sessionId, idEpoch, nextSeq, fresh);
  }

  private id(prefix: string, n: number): string {
    return `${prefix}${this.idEpoch}-${n}`;
  }

  /** Toggle real-LLM mode; `key`/`model` apply on the next prompt. */
  setLive(enabled: boolean, key?: string, model?: string): void {
    this.live = enabled;
    if (key !== undefined) this.liveKey = key;
    if (model) this.liveModel = model;
  }

  /** Router for semantic actions emitted by the native surface. */
  onAction(action: AIUXAction): void {
    switch (action.id) {
      case "aiux.composer.send": {
        const text = action.payload["text"];
        if (typeof text === "string" && text.trim()) void this.track(this.sendPrompt(text));
        break;
      }
      case "aiux.composer.cancel": {
        const run = this.activeRun;
        if (run) {
          run.cancelRequested = true;
          this.liveHandle?.abort();
          this.liveHandle = undefined;
          this.transport.push(this.agent.runCancelled(run.runId));
          if (run.messageId) {
            this.transport.push(this.agent.messageComplete(run.messageId));
          }
          this.activeRun = null;
          // Unblock a run parked on the approval gate so its continuation
          // can observe cancelRequested and bail instead of pushing
          // resolution/completion events after runCancelled.
          this.pendingApproval?.(false);
          this.pendingApproval = null;
        }
        break;
      }
      case "aiux.approval.approve":
        this.pendingApproval?.(true);
        break;
      case "aiux.approval.reject":
        this.pendingApproval?.(false);
        break;
      case "aiux.approval.resolve": {
        const decision = action.payload["decision"];
        this.pendingApproval?.(decision === "approved");
        break;
      }
      case "aiux.error.retry": {
        const run = this.activeRun;
        if (run) {
          void this.track(
            this.live && this.liveKey
              ? this.liveRetry(run.runId)
              : this.retryRun(run.runId),
          );
        }
        break;
      }
      default:
        // Navigation actions (context.open, citation.open, surface custom
        // ids like invoice.publish…) are host policy — the demo ignores them.
        break;
    }
  }

  private send(...events: AiuxEventObject[]) {
    if (this.closed) return; // runs resumed by close() can't push into a closed transport
    for (const event of events) this.transport.push(event);
  }

  /** Watch a scripted run — swallow rejections surfacing after close(). */
  private track(task: Promise<void>): Promise<void> {
    return task.catch((error) => {
      if (!this.closed) console.warn("[aiux] demo run failed", error);
    });
  }

  /** Routes to the live model or the scripted scenario. */
  async sendPrompt(text: string): Promise<void> {
    if (this.live && this.liveKey) {
      this.lastPrompt = text;
      return this.livePrompt(text);
    }
    return this.scriptedPrompt(text);
  }

  /**
   * Real OpenRouter inference: prompt → streamed markdown answer → optional
   * real tool_call → approval → executed + follow-up summary → done.
   * Errors surface as the protocol's retryable error part + failed run.
   */
  private async livePrompt(text: string): Promise<void> {
    const n = ++this.messageN;
    const messageId = this.id("m", n);
    const runId = this.id("r", n);
    const run: ActiveRun = { runId, cancelRequested: false, messageId };
    this.activeRun = run;

    this.send(...this.agent.userMessage(this.id("u", n), text));
    this.send(this.agent.runStarted(runId));
    this.send(this.agent.assistantMessage(messageId));
    this.send(this.agent.textPart(messageId, "p1"));

    if (this.liveHistory.length === 0) {
      this.liveHistory.push({ role: "system", content: LIVE_SYSTEM_PROMPT });
    }
    this.liveHistory.push({ role: "user", content: text });
    let answer = "";
    this.liveHandle = streamChatCompletion(
      this.liveKey!,
      this.liveModel,
      this.liveHistory.slice(-20),
      [PUBLISH_INVOICE_TOOL],
      {
        onDelta: (delta) => {
          if (run.cancelRequested || this.closed) return;
          answer += delta;
          this.send(this.agent.textDelta(messageId, "p1", delta));
        },
        onToolCalls: (calls) => {
          if (run.cancelRequested || this.closed) return;
          // The stream is done; the tool turn completes the run — clear
          // the handle and mark it so this stream's onDone stays out.
          this.liveHandle = undefined;
          run.toolTurnPending = true;
          void this.track(this.liveToolTurn(run, messageId, calls));
        },
        onDone: () => {
          if (run.cancelRequested || run.toolTurnPending || this.closed) return;
          if (this.liveHandle === undefined) return;
          this.liveHandle = undefined;
          this.liveHistory.push({ role: "assistant", content: answer });
          this.send(this.agent.messageComplete(messageId));
          this.send(this.agent.runCompleted(runId));
          if (this.activeRun === run) this.activeRun = null;
        },
        onError: (code, message) => {
          if (run.cancelRequested || this.closed) return;
          this.liveHandle = undefined;
          this.send(this.agent.errorPart(messageId, "p2", code, message, true));
          this.send(this.agent.messageComplete(messageId));
          this.send(this.agent.runFailed(runId, code, message));
          this.activeRun = run;
        },
      },
    );
  }

  /**
   * The model called `publish_invoice`: real tool card → approval gate →
   * executed/denied → result fed back to the model for the final answer.
   */
  private async liveToolTurn(
    run: ActiveRun,
    messageId: string,
    calls: ToolCall[],
  ): Promise<void> {
    const toolId = this.id("t", this.messageN);
    const approvalId = this.id("a", this.messageN);
    const call = calls[0]!;
    let args: Record<string, unknown> = {};
    try {
      const parsed: unknown = JSON.parse(call.function.arguments || "{}");
      if (typeof parsed === "object" && parsed !== null) {
        args = parsed as Record<string, unknown>;
      }
    } catch {
      /* malformed args — surface empty input */
    }
    this.send(this.agent.toolStarted(toolId, call.function.name || "tool", args));
    this.send(this.agent.toolPart(messageId, "p2", toolId));

    const invoiceId = typeof args["invoiceId"] === "string" ? args["invoiceId"] : "inv-9";
    this.send(
      this.agent.approvalRequested(
        approvalId,
        `Run ${call.function.name}?`,
        `Model requested publish of ${invoiceId}.`,
      ),
    );
    this.send(this.agent.approvalPart(messageId, "p3", approvalId));

    const approved = await new Promise<boolean>((resolve) => {
      this.pendingApproval = resolve;
    });
    this.pendingApproval = null;
    if (this.closed || run.cancelRequested) return;
    this.send(
      this.agent.approvalResolved(approvalId, approved ? "approved" : "rejected", "user"),
    );

    if (approved) {
      this.send(this.agent.approvalResolved(approvalId, "executed", "host"));
      this.send(this.agent.toolCompleted(toolId, { invoiceId, status: "sent" }));
      this.liveHistory.push(
        { role: "assistant", content: null, tool_calls: [call] },
        {
          role: "tool",
          tool_call_id: call.id,
          content: JSON.stringify({ invoiceId, status: "sent" }),
        },
      );
      let tail = "";
      this.liveHandle = streamChatCompletion(
        this.liveKey!,
        this.liveModel,
        this.liveHistory.slice(-20),
        undefined,
        {
          onDelta: (delta) => {
            if (run.cancelRequested || this.closed) return;
            tail += delta;
            this.send(this.agent.textDelta(messageId, "p1", delta));
          },
          onToolCalls: () => {},
          onDone: () => {
            if (run.cancelRequested || this.closed) return;
            this.liveHandle = undefined;
            this.liveHistory.push({ role: "assistant", content: tail });
            this.send(this.agent.messageComplete(messageId));
            this.send(this.agent.runCompleted(run.runId));
            if (this.activeRun === run) this.activeRun = null;
          },
          onError: (code, message) => {
            if (run.cancelRequested || this.closed) return;
            this.liveHandle = undefined;
            this.send(this.agent.errorPart(messageId, "p4", code, message, true));
            this.send(this.agent.messageComplete(messageId));
            this.send(this.agent.runFailed(run.runId, code, message));
            this.activeRun = run;
          },
        },
      );
    } else {
      this.send(this.agent.toolFailed(toolId, "DENIED", "user rejected the action"));
      this.send(
        this.agent.textPart(messageId, "p4", "Cancelled — invoice was not published."),
      );
      this.send(this.agent.messageComplete(messageId));
      this.send(this.agent.runCompleted(run.runId));
      if (this.activeRun === run) this.activeRun = null;
    }
  }

  /** Live retry: new run re-asking the last prompt against the same history. */
  private async liveRetry(previousRunId: string): Promise<void> {
    const n = ++this.messageN;
    const runId = this.id("r", n);
    const text = this.lastPrompt;
    this.send(this.agent.runStarted(runId, previousRunId));
    // Splice the new run's ids into livePrompt bookkeeping, then run it —
    // the user message was already pushed; just re-stream the answer.
    const messageId = this.id("m", n);
    const run: ActiveRun = { runId, cancelRequested: false, messageId };
    this.activeRun = run;
    this.send(this.agent.assistantMessage(messageId));
    this.send(this.agent.textPart(messageId, "p1"));
    let answer = "";
    this.liveHandle = streamChatCompletion(
      this.liveKey!,
      this.liveModel,
      this.liveHistory.slice(-20),
      [PUBLISH_INVOICE_TOOL],
      {
        onDelta: (delta) => {
          if (run.cancelRequested || this.closed) return;
          answer += delta;
          this.send(this.agent.textDelta(messageId, "p1", delta));
        },
        onToolCalls: (calls) => {
          if (run.cancelRequested || this.closed) return;
          this.liveHandle = undefined;
          run.toolTurnPending = true;
          void this.track(this.liveToolTurn(run, messageId, calls));
        },
        onDone: () => {
          if (run.cancelRequested || run.toolTurnPending || this.closed) return;
          if (this.liveHandle === undefined) return;
          this.liveHandle = undefined;
          this.liveHistory.push({ role: "assistant", content: answer });
          this.send(this.agent.messageComplete(messageId));
          this.send(this.agent.runCompleted(runId));
          if (this.activeRun === run) this.activeRun = null;
        },
        onError: (code, message) => {
          if (run.cancelRequested || this.closed) return;
          this.liveHandle = undefined;
          this.send(this.agent.errorPart(messageId, "p2", code, message, true));
          this.send(this.agent.messageComplete(messageId));
          this.send(this.agent.runFailed(runId, code, message));
          this.activeRun = run;
        },
      },
    );
  }

  /** user prompt → stream → tool → approval → resolve → surface result. */
  async scriptedPrompt(text: string): Promise<void> {
    const n = ++this.messageN;
    const messageId = this.id("m", n);
    const runId = this.id("r", n);
    const toolId = this.id("t", n);
    const approvalId = this.id("a", n);
    const surfaceId = this.id("sf", n);
    const run = { runId, cancelRequested: false };
    this.activeRun = run;

    this.send(...this.agent.userMessage(this.id("u", n), text));
    this.send(this.agent.runStarted(runId));
    this.send(this.agent.assistantMessage(messageId));

    const scripted =
      "Searching the AIUX spec for invoice matches, drafting the result card…";
    this.send(this.agent.textPart(messageId, "p1"));
    for (const word of scripted.split(" ")) {
      if (run.cancelRequested || this.closed) return;
      await sleep(60);
      this.send(this.agent.textDelta(messageId, "p1", `${word} `));
    }
    this.send(
      this.agent.markdownPart(
        messageId,
        "p2",
        "**Found:** invoice `inv-9` for **$420.00** — publish requires approval.",
      ),
    );

    this.send(this.agent.toolStarted(toolId, "search", { q: "invoice inv-9" }));
    await sleep(400);
    if (run.cancelRequested || this.closed) return;
    this.send(this.agent.toolProgress(toolId, 1, 3, "querying"));
    await sleep(400);
    if (this.closed) return;
    this.send(this.agent.toolProgress(toolId, 3, 3, "ranking"));
    await sleep(300);

    if (text.toLowerCase().includes("fail")) {
      // Error+retry branch: tool + run fail retryable; `aiux.error.retry`
      // replays the run via retryRun().
      this.send(this.agent.toolFailed(toolId, "TIMEOUT", "search backend timed out after 30s"));
      this.send(this.agent.errorPart(messageId, "p3", "UPSTREAM_503", "backend unavailable", true));
      this.send(this.agent.messageComplete(messageId));
      this.send(this.agent.runFailed(runId, "UPSTREAM_503", "backend unavailable"));
      return;
    }

    this.send(this.agent.toolCompleted(toolId, { hits: 2, top: "inv-9" }));
    this.send(this.agent.toolPart(messageId, "p3", toolId));

    this.send(
      this.agent.approvalRequested(
        approvalId,
        "Publish invoice INV-9?",
        "Charges $420.00 to Acme.",
      ),
    );
    this.send(this.agent.approvalPart(messageId, "p4", approvalId));

    const approved = await new Promise<boolean>((resolve) => {
      this.pendingApproval = resolve;
    });
    if (this.closed || run.cancelRequested) return;
    this.pendingApproval = null;

    this.send(
      this.agent.approvalResolved(approvalId, approved ? "approved" : "rejected", "user"),
    );
    if (approved) {
      await sleep(250);
      this.send(this.agent.approvalResolved(approvalId, "executed", "host"));
      this.send(this.agent.resultSurface(surfaceId));
      this.send(this.agent.surfacePart(messageId, "p5", surfaceId));
      this.send(this.agent.textPart(messageId, "p6", "Done — INV-9 sent."));
    } else {
      this.send(
        this.agent.textPart(messageId, "p5", "Cancelled — invoice was not published."),
      );
    }
    this.send(this.agent.messageComplete(messageId));
    this.send(this.agent.runCompleted(runId));
    if (this.activeRun === run) this.activeRun = null;
  }

  /** Retry branch: same message, a `retryOf` run that succeeds. */
  private async retryRun(previousRunId: string): Promise<void> {
    const n = ++this.messageN;
    const messageId = this.id("m", n);
    const runId = this.id("r", n);
    const run = { runId, cancelRequested: false };
    this.activeRun = run;

    this.send(this.agent.runStarted(runId, previousRunId));
    this.send(this.agent.assistantMessage(messageId));
    this.send(this.agent.textPart(messageId, "p1", "Retry succeeded."));
    await sleep(300);
    if (this.closed) return;
    this.send(this.agent.messageComplete(messageId));
    this.send(this.agent.runCompleted(runId));
    if (this.activeRun === run) this.activeRun = null;
  }

  close(): void {
    this.closed = true;
    // Unblock runs waiting on the approval gate; their trailing sends
    // no-op via `send()` instead of throwing into the closed transport.
    this.pendingApproval?.(false);
    this.pendingApproval = null;
    this.activeRun = null;
    // Fire-and-forget: rejects only if native delivery is down, which the
    // app already surfaces through the transport policy.
    void this.transport.close().catch(() => {});
  }
}
