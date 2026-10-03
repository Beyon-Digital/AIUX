import {
  PROTOCOL_VERSION,
  type AiuxError,
  type AiuxEventOf,
  type Approval,
  type ApprovalResolution,
  type ApprovalResolved,
  type ApprovalRequested,
  type Artifact,
  type ArtifactCreated,
  type ArtifactUpdated,
  type ContextEntity,
  type Message,
  type MessageCreated,
  type MessageRole,
  type MessageStatus,
  type MessageUpdated,
  type Part,
  type PartAdded,
  type PartUpdated,
  type Progress,
  type Run,
  type RunCancelled,
  type RunCompleted,
  type RunFailed,
  type RunStarted,
  type Session,
  type SessionCreated,
  type Surface,
  type SurfaceCreated,
  type SurfaceNode,
  type SurfaceUpdated,
  type TextDelta,
  type Tool,
  type ToolCompleted,
  type ToolFailed,
  type ToolProgress,
  type ToolStarted,
} from "@beyond-digital/aiux-protocol-types";

export interface EventFactoryOptions {
  /** Clock; defaults to `new Date().toISOString()`. Inject for deterministic tests. */
  now?: () => string;
  /** eventId minter; defaults to `evt-<seq36>-<random>` (unique per factory). */
  eventId?: (sequence: number) => string;
  /** First sequence number to mint (e.g. resuming a stream). Default 0. */
  startSequence?: number;
}

/**
 * Mints canonical `AIUXEvent` envelopes for one session: `eventId`,
 * `sequence` (0-based, monotonic), `timestamp`, and `protocolVersion` are
 * filled automatically; every payload also carries `protocolVersion` per the
 * v1 payload schemas. Adapters use it to normalize wire shapes; hosts may use
 * it directly.
 */
export interface EventFactory {
  readonly sessionId: string;
  /** Sequence the next minted event will get (for assertions / diagnostics). */
  peekSequence(): number;
  /**
   * Advance the minted sequence past `n` — used when a canonical envelope
   * passes through untouched so a later factory-minted event can't reuse
   * its sequence.
   */
  observeSequence(n: number): void;
  /** Mint an event for any wire `type` — use the typed helpers when possible. */
  emit<P extends object>(type: string, payload: P): AiuxEventOf<P>;
  sessionCreated(session: Session): AiuxEventOf<SessionCreated>;
  runStarted(run: Run, context?: ContextEntity[]): AiuxEventOf<RunStarted>;
  runCancelled(runId: string, reason?: string): AiuxEventOf<RunCancelled>;
  runCompleted(runId: string, result?: unknown): AiuxEventOf<RunCompleted>;
  runFailed(runId: string, error: AiuxError): AiuxEventOf<RunFailed>;
  messageCreated(message: Message): AiuxEventOf<MessageCreated>;
  messageUpdated(
    messageId: string,
    patch: { status?: MessageStatus; role?: MessageRole; metadata?: unknown },
  ): AiuxEventOf<MessageUpdated>;
  partAdded(messageId: string, part: Part): AiuxEventOf<PartAdded>;
  partUpdated(messageId: string, partId: string, part: Part): AiuxEventOf<PartUpdated>;
  textDelta(messageId: string, partId: string, delta: string): AiuxEventOf<TextDelta>;
  toolStarted(tool: Tool): AiuxEventOf<ToolStarted>;
  toolProgress(toolId: string, progress: Progress): AiuxEventOf<ToolProgress>;
  toolCompleted(toolId: string, result?: unknown): AiuxEventOf<ToolCompleted>;
  toolFailed(toolId: string, error: AiuxError): AiuxEventOf<ToolFailed>;
  approvalRequested(approval: Approval): AiuxEventOf<ApprovalRequested>;
  approvalResolved(
    approvalId: string,
    resolution: ApprovalResolution,
  ): AiuxEventOf<ApprovalResolved>;
  artifactCreated(artifact: Artifact): AiuxEventOf<ArtifactCreated>;
  artifactUpdated(
    artifactId: string,
    patch: { title?: string; content?: string; uri?: string; metadata?: unknown },
  ): AiuxEventOf<ArtifactUpdated>;
  surfaceCreated(surface: Surface): AiuxEventOf<SurfaceCreated>;
  surfaceUpdated(surfaceId: string, root: SurfaceNode): AiuxEventOf<SurfaceUpdated>;
}

const defaultEventId = (sequence: number): string =>
  `evt-${sequence.toString(36)}-${Math.random().toString(36).slice(2, 10)}`;

export function createEventFactory(
  sessionId: string,
  options: EventFactoryOptions = {},
): EventFactory {
  const now = options.now ?? (() => new Date().toISOString());
  const mintEventId = options.eventId ?? defaultEventId;
  let sequence = options.startSequence ?? 0;

  const emit = <P extends object>(type: string, payload: P): AiuxEventOf<P> => {
    const event: AiuxEventOf<P> = {
      eventId: mintEventId(sequence),
      sessionId,
      sequence,
      timestamp: now(),
      type,
      protocolVersion: PROTOCOL_VERSION,
      payload: payload as AiuxEventOf<P>["payload"],
    };
    sequence += 1;
    return event;
  };

  const v = { protocolVersion: PROTOCOL_VERSION };

  return {
    sessionId,
    peekSequence: () => sequence,
    observeSequence: (n: number) => {
      if (Number.isInteger(n) && n >= sequence) sequence = n + 1;
    },
    emit,
    sessionCreated: (session) =>
      emit<SessionCreated>("session.created", { ...v, session }),
    runStarted: (run, context = []) =>
      emit<RunStarted>("run.started", { ...v, run, context }),
    runCancelled: (runId, reason) =>
      emit<RunCancelled>("run.cancelled", { ...v, runId, ...(reason !== undefined && { reason }) }),
    runCompleted: (runId, result) =>
      emit<RunCompleted>("run.completed", { ...v, runId, ...(result !== undefined && { result }) }),
    runFailed: (runId, error) =>
      emit<RunFailed>("run.failed", { ...v, runId, error }),
    messageCreated: (message) =>
      emit<MessageCreated>("message.created", { ...v, message }),
    messageUpdated: (messageId, patch) =>
      emit<MessageUpdated>("message.updated", {
        ...v,
        messageId,
        ...(patch.status !== undefined && { status: patch.status }),
        ...(patch.role !== undefined && { role: patch.role }),
        ...(patch.metadata !== undefined && { metadata: patch.metadata }),
      }),
    partAdded: (messageId, part) =>
      emit<PartAdded>("part.added", { ...v, messageId, part }),
    partUpdated: (messageId, partId, part) =>
      emit<PartUpdated>("part.updated", { ...v, messageId, partId, part }),
    textDelta: (messageId, partId, delta) =>
      emit<TextDelta>("text.delta", { ...v, messageId, partId, delta }),
    toolStarted: (tool) => emit<ToolStarted>("tool.started", { ...v, tool }),
    toolProgress: (toolId, progress) =>
      emit<ToolProgress>("tool.progress", { ...v, toolId, progress }),
    toolCompleted: (toolId, result) =>
      emit<ToolCompleted>("tool.completed", {
        ...v,
        toolId,
        ...(result !== undefined && { result }),
      }),
    toolFailed: (toolId, error) =>
      emit<ToolFailed>("tool.failed", { ...v, toolId, error }),
    approvalRequested: (approval) =>
      emit<ApprovalRequested>("approval.requested", { ...v, approval }),
    approvalResolved: (approvalId, resolution) =>
      emit<ApprovalResolved>("approval.resolved", { ...v, approvalId, resolution }),
    artifactCreated: (artifact) =>
      emit<ArtifactCreated>("artifact.created", { ...v, artifact }),
    artifactUpdated: (artifactId, patch) =>
      emit<ArtifactUpdated>("artifact.updated", {
        ...v,
        artifactId,
        ...(patch.title !== undefined && { title: patch.title }),
        ...(patch.content !== undefined && { content: patch.content }),
        ...(patch.uri !== undefined && { uri: patch.uri }),
        ...(patch.metadata !== undefined && { metadata: patch.metadata }),
      }),
    surfaceCreated: (surface) =>
      emit<SurfaceCreated>("surface.created", { ...v, surface }),
    surfaceUpdated: (surfaceId, root) =>
      emit<SurfaceUpdated>("surface.updated", { ...v, surfaceId, root }),
  };
}
