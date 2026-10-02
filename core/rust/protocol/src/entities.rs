//! AIUX Protocol v1 — core entities (plan §3).
//!
//! Serde models are the single source of truth. Wire format is camelCase;
//! entities carry `extra` catch-alls so unknown optional fields are tolerated
//! and round-trip forward-compatibly (plan §21, ADR 0003).

use std::collections::BTreeMap;

use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use serde_json::Value;

pub use aiux_surfaces::{
    Action, ArtifactPreview, ArtifactWorkspace, SurfaceDescriptor, SurfaceNode,
};

/// A semantic surface tree (re-exported from `aiux-surfaces`, the schema owner).
pub type Surface = aiux_surfaces::SurfaceTree;

fn default_true() -> bool {
    true
}

/// A declared session capability (e.g. `tools.execute`, `files.upload`).
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Capability {
    /// Capability identifier.
    pub id: String,
    /// Human-readable description.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Whether the capability is enabled (default true).
    #[serde(default = "default_true")]
    pub enabled: bool,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// A contextual entity injected into the session (file, record, URL, ...).
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ContextEntity {
    /// Stable identifier.
    pub id: String,
    /// Semantic kind, e.g. `file`, `issue`, `customer`.
    pub kind: String,
    /// Display label.
    pub label: String,
    /// Longer description.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Link target for the renderer.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub uri: Option<String>,
    /// Free-form structured data for the host/renderer.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// An AI interaction session.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Session {
    /// Session identifier — matches the event envelope `sessionId`.
    pub id: String,
    /// Display title.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    /// Creation timestamp (ISO-8601, supplied by the host).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
    /// Declared capabilities.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub capabilities: Vec<Capability>,
    /// Context entities bound to the session.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub context: Vec<ContextEntity>,
    /// Free-form host metadata.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<Value>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// Message author role.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum MessageRole {
    User,
    Assistant,
    System,
    Tool,
}

/// Message lifecycle status.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum MessageStatus {
    Streaming,
    Complete,
    Failed,
    Cancelled,
}

/// A session message composed of typed parts.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Message {
    /// Stable identifier.
    pub id: String,
    /// Author role.
    pub role: MessageRole,
    /// Lifecycle status.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status: Option<MessageStatus>,
    /// Ordered parts.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub parts: Vec<Part>,
    /// Creation timestamp (ISO-8601, host-supplied).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<String>,
    /// Free-form host metadata.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<Value>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// Structured error payload (entity name `error` on the wire).
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct AiuxError {
    /// Stable machine-readable code.
    pub code: String,
    /// Human-readable message.
    pub message: String,
    /// Whether the operation may be retried.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub retryable: Option<bool>,
    /// Additional detail for debugging.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub detail: Option<Value>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// A file/media reference carried by parts or messages.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Attachment {
    /// Stable identifier.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    /// File name.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    /// MIME type.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mime_type: Option<String>,
    /// Resource URI (host-mediated).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub uri: Option<String>,
    /// Size in bytes.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub size_bytes: Option<u64>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// A source citation.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Citation {
    /// Stable identifier.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    /// Source title.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    /// Source URI.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub uri: Option<String>,
    /// Quoted snippet.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub snippet: Option<String>,
    /// Origin identifier (index, tool, document store, ...).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub source: Option<String>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// Normalized progress value.
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Progress {
    /// Units complete.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub current: Option<f64>,
    /// Total units.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub total: Option<f64>,
    /// Progress label.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub label: Option<String>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// Tool lifecycle status.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum ToolStatus {
    Running,
    Completed,
    Failed,
}

/// A tool invocation tracked by the session.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Tool {
    /// Stable identifier.
    pub id: String,
    /// Tool name.
    pub name: String,
    /// Lifecycle status.
    pub status: ToolStatus,
    /// Invocation input.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub input: Option<Value>,
    /// Latest progress.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub progress: Option<Progress>,
    /// Result on success.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    /// Error on failure.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<AiuxError>,
    /// Start timestamp (ISO-8601, host-supplied).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_at: Option<String>,
    /// Completion timestamp (ISO-8601, host-supplied).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completed_at: Option<String>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// Approval lifecycle status (plan §23). `approved` → `executed` is the only
/// permitted terminal-to-terminal transition; resolutions on an already
/// resolved approval are absorbed as no-ops so replays never re-execute.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum ApprovalStatus {
    Requested,
    Approved,
    Rejected,
    Expired,
    Executed,
}

/// The decision carried by `approval.resolved`.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum ApprovalDecision {
    Approved,
    Rejected,
    Expired,
    Executed,
}

/// Recorded resolution of an approval.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ApprovalResolution {
    /// Resolution outcome.
    pub decision: ApprovalDecision,
    /// Who/what resolved it (`user`, `host`, `timeout`, ...).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub resolved_by: Option<String>,
    /// Optional note attached to the resolution.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub note: Option<String>,
    /// Resolution timestamp (ISO-8601, host-supplied).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub resolved_at: Option<String>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// An approval request tracked by the session.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Approval {
    /// Stable identifier.
    pub id: String,
    /// What is being approved.
    pub prompt: String,
    /// Longer description.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    /// Tool invocation this approval gates, if any.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool_id: Option<String>,
    /// Semantic action executed on approval (data only — §23).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub action: Option<Action>,
    /// Lifecycle status.
    pub status: ApprovalStatus,
    /// Expiry timestamp (ISO-8601, host-supplied).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub expires_at: Option<String>,
    /// Recorded resolution, once resolved.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub resolution: Option<ApprovalResolution>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// A versioned artifact produced during the session.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Artifact {
    /// Stable identifier.
    pub id: String,
    /// Semantic kind, e.g. `code`, `document`, `dashboard`.
    pub kind: String,
    /// Display title.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    /// Monotonic revision; bumps on every `artifact.updated`.
    #[serde(default)]
    pub revision: u64,
    /// Inline content (text/code/JSON).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub content: Option<String>,
    /// External content URI (host-mediated).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub uri: Option<String>,
    /// Free-form host metadata.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<Value>,
    /// Inline preview contract — what an artifact card shows (ADR 0007).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub preview: Option<ArtifactPreview>,
    /// Opened-workspace contract — how the artifact presents when opened
    /// (ADR 0007).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub workspace: Option<ArtifactWorkspace>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// Run lifecycle status.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum RunStatus {
    Running,
    Completed,
    Failed,
    Cancelled,
}

/// A run: one agent execution span within a session.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Run {
    /// Stable identifier.
    pub id: String,
    /// Lifecycle status.
    pub status: RunStatus,
    /// Previous run this run retries, if any.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub retry_of: Option<String>,
    /// Message the run responds to, if any.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub input_message_id: Option<String>,
    /// Result on success.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    /// Error on failure.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<AiuxError>,
    /// Start timestamp (ISO-8601, host-supplied).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_at: Option<String>,
    /// End timestamp (ISO-8601, host-supplied).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completed_at: Option<String>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// Severity for `status` parts.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum StatusLevel {
    Info,
    Success,
    Warning,
    Error,
}

/// `text` part.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TextPart {
    /// Stable part identifier within its message.
    pub id: String,
    /// Text content; `text.delta` events append here.
    pub text: String,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// `markdown` part.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct MarkdownPart {
    /// Stable part identifier within its message.
    pub id: String,
    /// Markdown source; `text.delta` events append here.
    pub markdown: String,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// `code` part.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CodePart {
    /// Stable part identifier within its message.
    pub id: String,
    /// Code source.
    pub code: String,
    /// Language hint.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub language: Option<String>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// `image` part.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ImagePart {
    /// Stable part identifier within its message.
    pub id: String,
    /// Image attachment.
    pub attachment: Attachment,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// `attachment` part.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct AttachmentPart {
    /// Stable part identifier within its message.
    pub id: String,
    /// Attachment reference.
    pub attachment: Attachment,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// `citation` part.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CitationPart {
    /// Stable part identifier within its message.
    pub id: String,
    /// Citation.
    pub citation: Citation,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// `tool` part — references a session-level `Tool` record.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ToolPart {
    /// Stable part identifier within its message.
    pub id: String,
    /// Referenced tool id.
    pub tool_id: String,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// `approval` part — references a session-level `Approval` record.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ApprovalPart {
    /// Stable part identifier within its message.
    pub id: String,
    /// Referenced approval id.
    pub approval_id: String,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// `artifact` part — references a session-level `Artifact`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ArtifactPart {
    /// Stable part identifier within its message.
    pub id: String,
    /// Referenced artifact id.
    pub artifact_id: String,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// `status` part — an inline status line.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct StatusPart {
    /// Stable part identifier within its message.
    pub id: String,
    /// Status text.
    pub text: String,
    /// Severity level.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub level: Option<StatusLevel>,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// `progress` part — an inline progress indicator.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ProgressPart {
    /// Stable part identifier within its message.
    pub id: String,
    /// Progress value.
    pub progress: Progress,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// `surface` part — references a session-level `Surface`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct SurfacePart {
    /// Stable part identifier within its message.
    pub id: String,
    /// Referenced surface id.
    pub surface_id: String,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// `error` part.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ErrorPart {
    /// Stable part identifier within its message.
    pub id: String,
    /// The error.
    pub error: AiuxError,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

/// A typed part within a message (all 13 protocol part kinds; plan §3).
/// Serialized internally tagged: `{"type": "text", "text": "..."}`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum Part {
    /// Plain text (supports `text.delta` append).
    #[serde(rename = "text")]
    Text(TextPart),
    /// Markdown (supports `text.delta` append).
    #[serde(rename = "markdown")]
    Markdown(MarkdownPart),
    /// Code block.
    #[serde(rename = "code")]
    Code(CodePart),
    /// Image attachment.
    #[serde(rename = "image")]
    Image(ImagePart),
    /// Generic attachment.
    #[serde(rename = "attachment")]
    Attachment(AttachmentPart),
    /// Source citation.
    #[serde(rename = "citation")]
    Citation(CitationPart),
    /// Reference to a session-level tool record.
    #[serde(rename = "tool")]
    Tool(ToolPart),
    /// Reference to a session-level approval record.
    #[serde(rename = "approval")]
    Approval(ApprovalPart),
    /// Reference to a session-level artifact.
    #[serde(rename = "artifact")]
    Artifact(ArtifactPart),
    /// Inline status line.
    #[serde(rename = "status")]
    Status(StatusPart),
    /// Inline progress indicator.
    #[serde(rename = "progress")]
    Progress(ProgressPart),
    /// Reference to a session-level surface.
    #[serde(rename = "surface")]
    Surface(SurfacePart),
    /// Error content.
    #[serde(rename = "error")]
    Error(ErrorPart),
}

impl Part {
    /// The part's stable identifier.
    pub fn id(&self) -> &str {
        match self {
            Self::Text(p) => &p.id,
            Self::Markdown(p) => &p.id,
            Self::Code(p) => &p.id,
            Self::Image(p) => &p.id,
            Self::Attachment(p) => &p.id,
            Self::Citation(p) => &p.id,
            Self::Tool(p) => &p.id,
            Self::Approval(p) => &p.id,
            Self::Artifact(p) => &p.id,
            Self::Status(p) => &p.id,
            Self::Progress(p) => &p.id,
            Self::Surface(p) => &p.id,
            Self::Error(p) => &p.id,
        }
    }

    /// Discriminant name as it appears on the wire.
    pub fn kind(&self) -> &'static str {
        match self {
            Self::Text(_) => "text",
            Self::Markdown(_) => "markdown",
            Self::Code(_) => "code",
            Self::Image(_) => "image",
            Self::Attachment(_) => "attachment",
            Self::Citation(_) => "citation",
            Self::Tool(_) => "tool",
            Self::Approval(_) => "approval",
            Self::Artifact(_) => "artifact",
            Self::Status(_) => "status",
            Self::Progress(_) => "progress",
            Self::Surface(_) => "surface",
            Self::Error(_) => "error",
        }
    }
}
