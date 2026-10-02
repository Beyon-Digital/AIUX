/**
 * Scripted agent emitting protocol-v1 events — a TypeScript port of
 * `examples/android-native/MockAgent.kt` (the Phase 4 canonical scenario):
 * user prompt → stream → tool start/finish → approval → resolve →
 * surface result, plus an error+retry branch and run cancellation.
 * Sequence numbers are contiguous per session, matching conformance fixtures.
 */

type JsonObject = Record<string, unknown>;

export type AiuxEventObject = {
  eventId: string;
  sessionId: string;
  sequence: number;
  timestamp: string;
  type: string;
  payload: JsonObject;
};

export class MockAgent {
  private sequence: number;
  private eventN = 0;

  /**
   * `idNamespace` prefixes every generated `eventId`; `startSequence`
   * resumes the sequence counter — both matter after a JS remount against
   * a persisted native session (fresh counters would replay colliding
   * ids/sequences and get rejected as InvalidEvent).
   */
  constructor(
    private readonly sessionId: string = "s1",
    private readonly idNamespace: string = "",
    startSequence = 0,
  ) {
    this.sequence = startSequence;
  }

  private event(type: string, payload: JsonObject): AiuxEventObject {
    const sequence = this.sequence++;
    return {
      eventId: `${this.idNamespace}e${++this.eventN}`,
      sessionId: this.sessionId,
      sequence,
      timestamp: `2026-01-01T00:00:${String(sequence).padStart(2, "0")}Z`,
      type,
      payload,
    };
  }

  sessionCreated(title: string): AiuxEventObject {
    return this.event("session.created", {
      protocolVersion: "0.1",
      session: {
        id: this.sessionId,
        title,
        createdAt: "2026-01-01T00:00:00Z",
        context: [
          {
            id: "ctx-repo",
            kind: "repo",
            label: "Beyon-Digital/AIUX",
            description: "Working copy",
          },
          {
            id: "ctx-branch",
            kind: "branch",
            label: "devin/phase4-expo",
            description: "Current branch",
          },
        ],
      },
    });
  }

  userMessage(id: string, text: string): AiuxEventObject[] {
    return [
      this.event("message.created", {
        protocolVersion: "0.1",
        message: { id, role: "user", status: "complete" },
      }),
      this.partAdded(id, { id: `${id}-p1`, type: "text", text }),
    ];
  }

  runStarted(runId: string, retryOf?: string): AiuxEventObject {
    return this.event("run.started", {
      protocolVersion: "0.1",
      run: {
        id: runId,
        status: "running",
        startedAt: "2026-01-01T00:00:01Z",
        ...(retryOf ? { retryOf } : {}),
      },
    });
  }

  runFailed(runId: string, code: string, message: string): AiuxEventObject {
    return this.event("run.failed", {
      protocolVersion: "0.1",
      runId,
      error: { code, message, retryable: true },
    });
  }

  runCancelled(runId: string): AiuxEventObject {
    return this.event("run.cancelled", {
      protocolVersion: "0.1",
      runId,
    });
  }

  assistantMessage(id: string): AiuxEventObject {
    return this.event("message.created", {
      protocolVersion: "0.1",
      message: { id, role: "assistant", status: "streaming" },
    });
  }

  textPart(messageId: string, partId: string, text = ""): AiuxEventObject {
    return this.partAdded(messageId, { id: partId, type: "text", text });
  }

  textDelta(messageId: string, partId: string, delta: string): AiuxEventObject {
    return this.event("text.delta", {
      protocolVersion: "0.1",
      messageId,
      partId,
      delta,
    });
  }

  markdownPart(
    messageId: string,
    partId: string,
    markdown: string,
  ): AiuxEventObject {
    return this.partAdded(messageId, {
      id: partId,
      type: "markdown",
      markdown,
    });
  }

  errorPart(
    messageId: string,
    partId: string,
    code: string,
    message: string,
    retryable = true,
  ): AiuxEventObject {
    return this.partAdded(messageId, {
      id: partId,
      type: "error",
      error: { code, message, retryable },
    });
  }

  toolStarted(id: string, name: string, input: JsonObject): AiuxEventObject {
    return this.event("tool.started", {
      protocolVersion: "0.1",
      tool: { id, name, status: "running", input },
    });
  }

  toolProgress(
    id: string,
    current: number,
    total: number,
    label: string,
  ): AiuxEventObject {
    return this.event("tool.progress", {
      protocolVersion: "0.1",
      toolId: id,
      progress: { current, total, label },
    });
  }

  toolCompleted(id: string, result: JsonObject): AiuxEventObject {
    return this.event("tool.completed", {
      protocolVersion: "0.1",
      toolId: id,
      result,
    });
  }

  toolFailed(id: string, code: string, message: string): AiuxEventObject {
    return this.event("tool.failed", {
      protocolVersion: "0.1",
      toolId: id,
      error: { code, message, retryable: true },
    });
  }

  toolPart(messageId: string, partId: string, toolId: string): AiuxEventObject {
    return this.partAdded(messageId, {
      id: partId,
      type: "tool",
      toolId,
    });
  }

  approvalRequested(
    id: string,
    prompt: string,
    description: string,
  ): AiuxEventObject {
    return this.event("approval.requested", {
      protocolVersion: "0.1",
      approval: {
        id,
        prompt,
        description,
        status: "requested",
        action: {
          id: "invoice.publish",
          payload: { invoiceId: "inv-9" },
        },
      },
    });
  }

  approvalPart(
    messageId: string,
    partId: string,
    approvalId: string,
  ): AiuxEventObject {
    return this.partAdded(messageId, {
      id: partId,
      type: "approval",
      approvalId,
    });
  }

  approvalResolved(
    id: string,
    decision: string,
    resolvedBy: string,
  ): AiuxEventObject {
    return this.event("approval.resolved", {
      protocolVersion: "0.1",
      approvalId: id,
      resolution: {
        decision,
        resolvedBy,
        resolvedAt: "2026-01-01T00:00:30Z",
      },
    });
  }

  resultSurface(id: string): AiuxEventObject {
    return this.event("surface.created", {
      protocolVersion: "0.1",
      surface: {
        id,
        name: "invoice-card",
        revision: 0,
        root: {
          type: "surface",
          children: [
            {
              type: "card",
              title: "Invoice INV-9",
              children: [
                {
                  type: "keyValue",
                  items: [
                    { key: "Total", value: "$420.00" },
                    { key: "Status", value: "sent" },
                  ],
                },
                { type: "status", text: "Delivered to Acme", tone: "success" },
              ],
            },
          ],
        },
      },
    });
  }

  surfacePart(
    messageId: string,
    partId: string,
    surfaceId: string,
  ): AiuxEventObject {
    return this.partAdded(messageId, {
      id: partId,
      type: "surface",
      surfaceId,
    });
  }

  messageComplete(id: string): AiuxEventObject {
    return this.event("message.updated", {
      protocolVersion: "0.1",
      messageId: id,
      status: "complete",
    });
  }

  runCompleted(id: string): AiuxEventObject {
    return this.event("run.completed", {
      protocolVersion: "0.1",
      runId: id,
    });
  }

  private partAdded(messageId: string, part: JsonObject): AiuxEventObject {
    return this.event("part.added", {
      protocolVersion: "0.1",
      messageId,
      part,
    });
  }
}
