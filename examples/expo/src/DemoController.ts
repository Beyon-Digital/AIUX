import type { AIUXAction, AIUXTransport } from "@beyondigital/aiux-expo";
import { createAIUXTransport } from "@beyondigital/aiux-expo";

import { MockAgent, type AiuxEventObject } from "./mockAgent";

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

/**
 * Host-side driver for the mocked agent interaction (Phase 4 gate) — a port
 * of `examples/android-native/DemoController.kt`. `AIUXAction`s flow
 * native → JS here; the library never executes them (plan §23).
 *
 * The transport is the batched `EventBuffer` adapter — every `send()` below
 * coalesces into `dispatchBatch` calls (16–50 ms flush), so streaming deltas
 * never cross the boundary per token.
 */
export class DemoController {
  readonly sessionId: string;
  private readonly transport: AIUXTransport;
  private readonly agent: MockAgent;
  private pendingApproval: ((approved: boolean) => void) | null = null;
  private activeRun: { runId: string; cancelRequested: boolean } | null = null;
  private messageN = 0;
  private closed = false;

  constructor(sessionId: string) {
    this.sessionId = sessionId;
    this.agent = new MockAgent(sessionId);
    this.transport = createAIUXTransport(sessionId, {
      policy: {
        onFlushError: (error) => console.warn("[aiux] dispatchBatch failed", error),
      },
    });
    this.transport.push(this.agent.sessionCreated("AIUX Expo demo"));
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
          this.transport.push(this.agent.runCancelled(run.runId));
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
        if (run) void this.track(this.retryRun(run.runId));
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

  /** user prompt → stream → tool → approval → resolve → surface result. */
  async sendPrompt(text: string): Promise<void> {
    const n = ++this.messageN;
    const messageId = `m${n}`;
    const runId = `r${n}`;
    const toolId = `t${n}`;
    const approvalId = `a${n}`;
    const surfaceId = `sf${n}`;
    const run = { runId, cancelRequested: false };
    this.activeRun = run;

    this.send(...this.agent.userMessage(`u${n}`, text));
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
    if (this.closed) return;
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
    const messageId = `m${n}`;
    const runId = `r${n}`;
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
