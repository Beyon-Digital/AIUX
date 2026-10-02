//! aiux-protocol — AIUX Protocol v1 types and errors.
//!
//! Serde models are the single source of truth for Protocol v1
//! (docs/PLAN.md §3, ADR 0003). The error/result vocabulary below is the
//! FROZEN contract shared by the session facade and every FFI boundary —
//! bindings are built against it in parallel.

use serde::{Deserialize, Serialize};

mod entities;
mod events;
mod schemas;

pub use entities::{
    Action, AiuxError, Approval, ApprovalDecision, ApprovalPart, ApprovalResolution,
    ApprovalStatus, Artifact, ArtifactPart, ArtifactPreview, ArtifactWorkspace, Attachment,
    AttachmentPart, Capability, Citation, CitationPart, CodePart, ContextEntity, ErrorPart,
    ImagePart, MarkdownPart, Message, MessageRole, MessageStatus, Part, Progress, ProgressPart,
    Run, RunStatus, Session, StatusLevel, StatusPart, Surface, SurfaceDescriptor, SurfaceNode,
    SurfacePart, TextPart, Tool, ToolPart, ToolStatus,
};
pub use events::{
    AiuxEvent, ApprovalRequested, ApprovalResolved, ArtifactCreated, ArtifactUpdated, EventType,
    MessageCreated, MessageUpdated, PartAdded, PartUpdated, RunCancelled, RunCompleted, RunFailed,
    RunStarted, SessionCreated, SurfaceCreated, SurfaceUpdated, TextDelta, ToolCompleted,
    ToolFailed, ToolProgress, ToolStarted,
};
pub use schemas::{canonical_json, generate_schemas, schema_dir_name, ConformanceFixture};

/// Protocol version emitted in every payload (`protocolVersion`).
pub const PROTOCOL_VERSION: &str = "0.1";

/// Validate a `protocolVersion` carried by an event payload or serialized
/// state. Exact-match policy for v1 (ADR 0003): anything else is unknown
/// required semantics → `ProtocolError::Unsupported`.
pub fn check_protocol_version(version: &str) -> Result<(), ProtocolError> {
    if version == PROTOCOL_VERSION {
        Ok(())
    } else {
        Err(ProtocolError::Unsupported {
            detail: format!(
                "protocolVersion {version} not supported (this build supports {PROTOCOL_VERSION})"
            ),
        })
    }
}

/// Recoverable, explicitly-typed failures crossing the session boundary.
///
/// Out-of-order and unknown-required-semantics cases map to these variants;
/// nothing may silently corrupt state (ADR 0001, plan §4/§21).
#[derive(Debug, Clone, Serialize, Deserialize, schemars::JsonSchema, PartialEq, Eq)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum ProtocolError {
    /// Event payload failed schema/type validation.
    InvalidEvent { detail: String },
    /// Sequence gap exceeded the reorder buffer — recoverable by resync.
    SequenceGap { expected: u64, received: u64 },
    /// Payload requires semantics this build doesn't support.
    Unsupported { detail: String },
    /// Serialized state failed to parse/validate on restore.
    CorruptState { detail: String },
}

impl std::fmt::Display for ProtocolError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidEvent { detail } => write!(f, "invalid event: {detail}"),
            Self::SequenceGap { expected, received } => {
                write!(f, "sequence gap: expected {expected}, received {received}")
            }
            Self::Unsupported { detail } => write!(f, "unsupported semantics: {detail}"),
            Self::CorruptState { detail } => write!(f, "corrupt state: {detail}"),
        }
    }
}

impl std::error::Error for ProtocolError {}

/// Per-dispatch accounting returned by `dispatch`/`dispatch_batch`.
#[derive(Debug, Clone, Default, Serialize, Deserialize, schemars::JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct DispatchReport {
    /// Events that mutated state.
    pub applied: u64,
    /// Duplicate `eventId`s safely ignored (idempotency).
    pub duplicates_ignored: u64,
    /// Events buffered pending missing earlier sequences.
    pub buffered: u64,
}
