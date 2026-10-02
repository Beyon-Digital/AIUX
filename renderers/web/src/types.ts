/**
 * AIUX Protocol v1 — render-facing types for the web renderer.
 *
 * Mirrors `core/rust/protocol/src/entities.rs` + `core/rust/surfaces/src/node.rs`
 * (serde camelCase wire format). These are the typed projections of the
 * canonical `AiuxSession.snapshot()` payload — the renderer never sees the
 * ordering/idempotency bookkeeping that `serialize()` carries.
 *
 * Entities in the wire format may carry unknown optional fields for forward
 * compatibility (plan §21); they pass through untouched at runtime.
 */

/** A JSON-serializable object. */
export type JsonObject = Record<string, unknown>;

/** A semantic action emitted by interactive nodes — data only (§23). */
export interface AiuxAction {
  id: string;
  payload?: JsonObject;
}

/** Canonical action ids the renderer emits via `onAction`. The host resolves
 * them through its own policy; the renderer never executes them itself. */
export const AIUX_ACTIONS = {
  composerSubmit: "aiux.composer.submit",
  composerAttach: "aiux.composer.attach",
  approvalResolve: "aiux.approval.resolve",
  errorRetry: "aiux.error.retry",
  artifactOpen: "aiux.artifact.open",
  surfaceInput: "aiux.surface.input",
} as const;

/* ── Entities ─────────────────────────────────────────────────────────── */

export interface Capability {
  id: string;
  description?: string;
  enabled?: boolean;
}

export interface ContextEntity {
  id: string;
  kind: string;
  label: string;
  description?: string;
  uri?: string;
  data?: unknown;
}

export interface Session {
  id: string;
  title?: string;
  createdAt?: string;
  capabilities?: Capability[];
  context?: ContextEntity[];
  metadata?: unknown;
}

export type MessageRole = "user" | "assistant" | "system" | "tool";
export type MessageStatus = "streaming" | "complete" | "failed" | "cancelled";

export interface Message {
  id: string;
  role: MessageRole;
  status?: MessageStatus;
  parts?: AiuxPart[];
  createdAt?: string;
  metadata?: unknown;
}

export interface AiuxError {
  code: string;
  message: string;
  retryable?: boolean;
  detail?: unknown;
}

export interface Attachment {
  id?: string;
  name?: string;
  mimeType?: string;
  uri?: string;
  sizeBytes?: number;
}

export interface Citation {
  id?: string;
  title?: string;
  uri?: string;
  snippet?: string;
  source?: string;
}

export interface Progress {
  current?: number;
  total?: number;
  label?: string;
}

export type ToolStatus = "running" | "completed" | "failed";

export interface Tool {
  id: string;
  name: string;
  status: ToolStatus;
  input?: unknown;
  progress?: Progress;
  result?: unknown;
  error?: AiuxError;
  startedAt?: string;
  completedAt?: string;
}

export type ApprovalStatus =
  | "requested"
  | "approved"
  | "rejected"
  | "expired"
  | "executed";

export type ApprovalDecision = "approved" | "rejected" | "expired" | "executed";

export interface ApprovalResolution {
  decision: ApprovalDecision;
  resolvedBy?: string;
  note?: string;
  resolvedAt?: string;
}

export interface Approval {
  id: string;
  prompt: string;
  description?: string;
  toolId?: string;
  action?: AiuxAction;
  status: ApprovalStatus;
  expiresAt?: string;
  resolution?: ApprovalResolution;
}

export interface Artifact {
  id: string;
  kind: string;
  title?: string;
  revision?: number;
  content?: string;
  uri?: string;
  metadata?: unknown;
  /** Inline preview contract — what the artifact card shows (ADR 0007). */
  preview?: ArtifactPreview;
  /** Opened-workspace contract — how the artifact presents when opened. */
  workspace?: ArtifactWorkspace;
}

/** An inline surface descriptor carried inside an artifact (ADR 0007). */
export interface SurfaceDescriptor {
  id: string;
  root: SurfaceNode;
}

/** `artifact.preview` — summary and/or inline surface descriptor. */
export interface ArtifactPreview {
  summary?: string;
  surface?: SurfaceDescriptor;
}

export type WorkspaceMode = "fullscreen" | "detail" | "sheet";

/** `artifact.workspace` — presentation contract for an opened artifact. */
export interface ArtifactWorkspace {
  mode?: WorkspaceMode;
  surface?: SurfaceDescriptor;
  /** Lazy render hint — defer mounting until visible. */
  lazy?: boolean;
}

export type RunStatus = "running" | "completed" | "failed" | "cancelled";

export interface Run {
  id: string;
  status: RunStatus;
  retryOf?: string;
  inputMessageId?: string;
  result?: unknown;
  error?: AiuxError;
  startedAt?: string;
  completedAt?: string;
}

export type StatusLevel = "info" | "success" | "warning" | "error";

/* ── Parts (internally tagged: {"type": kind, ...}) ───────────────────── */

export interface TextPart {
  type: "text";
  id: string;
  text: string;
}
export interface MarkdownPart {
  type: "markdown";
  id: string;
  markdown: string;
}
export interface CodePart {
  type: "code";
  id: string;
  code: string;
  language?: string;
}
export interface ImagePart {
  type: "image";
  id: string;
  attachment: Attachment;
}
export interface AttachmentPart {
  type: "attachment";
  id: string;
  attachment: Attachment;
}
export interface CitationPart {
  type: "citation";
  id: string;
  citation: Citation;
}
export interface ToolPart {
  type: "tool";
  id: string;
  toolId: string;
}
export interface ApprovalPart {
  type: "approval";
  id: string;
  approvalId: string;
}
export interface ArtifactPart {
  type: "artifact";
  id: string;
  artifactId: string;
}
export interface StatusPart {
  type: "status";
  id: string;
  text: string;
  level?: StatusLevel;
}
export interface ProgressPart {
  type: "progress";
  id: string;
  progress: Progress;
}
export interface SurfacePart {
  type: "surface";
  id: string;
  surfaceId: string;
}
export interface ErrorPart {
  type: "error";
  id: string;
  error: AiuxError;
}

export type AiuxPart =
  | TextPart
  | MarkdownPart
  | CodePart
  | ImagePart
  | AttachmentPart
  | CitationPart
  | ToolPart
  | ApprovalPart
  | ArtifactPart
  | StatusPart
  | ProgressPart
  | SurfacePart
  | ErrorPart;

/* ── Surface Schema v1 (plan §6, ADR 0006) ────────────────────────────── */

export type Gap = "xs" | "sm" | "md" | "lg" | "xl";
export type Padding = "none" | "xs" | "sm" | "md" | "lg";
export type Radius = "sm" | "md" | "lg" | "full";
export type Alignment = "start" | "center" | "end" | "stretch";
export type Distribution =
  | "start"
  | "center"
  | "end"
  | "spaceBetween"
  | "spaceAround"
  | "spaceEvenly";
export type StackDirection = "vertical" | "horizontal";
export type TextVariant =
  | "body"
  | "caption"
  | "label"
  | "emphasis"
  | "strong"
  | "muted";
export type Tone =
  | "default"
  | "accent"
  | "muted"
  | "success"
  | "warning"
  | "destructive";
export type IconSize = "sm" | "md" | "lg";
export type ButtonVariant = "primary" | "secondary" | "ghost" | "destructive";
export type InputType = "text" | "email" | "number" | "password" | "url";

/** Semantic layout properties shared by every node — token values only. */
export interface Layout {
  gap?: Gap;
  padding?: Padding;
  radius?: Radius;
  alignment?: Alignment;
  distribution?: Distribution;
}

export interface KeyValueItem {
  key: string;
  value: string;
  tone?: Tone;
}
export interface SelectOption {
  value: string;
  label: string;
}
export interface MenuItem {
  label: string;
  action: AiuxAction;
  icon?: string;
  disabled?: boolean;
}

export type ColumnAlign = "start" | "center" | "end";

export interface TableColumn {
  key: string;
  title: string;
  align?: ColumnAlign;
}

/** A typed table cell (`{"type": ...}`) or a bare string (text). */
export type TableCell =
  | string
  | { type: "text"; text: string }
  | { type: "number"; value: number }
  | { type: "badge"; text: string; tone?: Tone }
  | { type: "action"; label: string; action: AiuxAction };

interface NodeBase extends Layout {
  children?: SurfaceNode[];
}

export type SurfaceNode = NodeBase & {
  type:
    | "surface"
    | "card"
    | "stack"
    | "row"
    | "grid"
    | "heading"
    | "text"
    | "markdown"
    | "code"
    | "icon"
    | "image"
    | "badge"
    | "divider"
    | "spacer"
    | "keyValue"
    | "list"
    | "listItem"
    | "table"
    | "button"
    | "menu"
    | "progress"
    | "status"
    | "input"
    | "textarea"
    | "select"
    | "checkbox"
    | "radio"
    | "field"
    | "form"
    | "actions"
    | "custom";
  // content fields (presence depends on type)
  title?: string;
  subtitle?: string;
  direction?: StackDirection;
  /** `grid`: column count; `table`: column descriptors. */
  columns?: number | TableColumn[];
  text?: string;
  level?: number;
  variant?: string;
  markdown?: string;
  code?: string;
  language?: string;
  name?: string;
  size?: IconSize | Gap;
  src?: string;
  alt?: string;
  tone?: Tone;
  icon?: string;
  items?: KeyValueItem[] | SelectOption[] | MenuItem[];
  ordered?: boolean;
  headers?: string[];
  /** `table`: cell matrix; `textarea`: row count. */
  rows?: TableCell[][] | number;
  caption?: string;
  label?: string;
  action?: AiuxAction;
  disabled?: boolean;
  value?: number | string;
  max?: number;
  placeholder?: string;
  inputType?: InputType;
  required?: boolean;
  checked?: boolean;
  options?: SelectOption[];
  errorText?: string;
  helperText?: string;
  /** `form`: submit action; collected `fields` merge into its payload. */
  submit?: AiuxAction;
  submitLabel?: string;
  /** `custom`: host-registered kind + data-only props. */
  kind?: string;
  props?: JsonObject;
};

export interface SurfaceTree {
  id: string;
  name?: string;
  revision?: number;
  root: SurfaceNode;
}

/* ── Snapshot — the render projection of session state ────────────────── */

export interface AiuxSnapshot {
  protocolVersion?: string;
  sessionId?: string;
  session?: Session;
  messages?: Message[];
  tools?: Tool[];
  approvals?: Approval[];
  artifacts?: Artifact[];
  surfaces?: SurfaceTree[];
  context?: ContextEntity[];
  runs?: Run[];
  activeRunId?: string;
}

/**
 * The slice of `AiuxSession` (`@beyondigital/aiux-core`) the renderer needs.
 * Kept `unknown`-typed at the boundary — `AiuxSession.snapshot()` returns the
 * opaque `JsonObject`, which callers narrow to `AiuxSnapshot` here.
 * `AiuxSession` satisfies this structurally, as do test doubles.
 */
export interface AiuxSessionLike {
  snapshot(): unknown;
  subscribe(listener: (snapshot: unknown) => void): () => void;
}
