//! AIUX Protocol v1 — event envelope and lifecycle payloads (plan §3).
//!
//! Envelope: `eventId`, `sessionId`, `sequence`, `timestamp`, `type`,
//! `protocolVersion`, `payload`. The 19 lifecycle event types form the closed
//! v1 set; an unrecognized `type` resolves to `None` from
//! [`AiuxEvent::event_type`] so dispatch can fail with
//! `ProtocolError::Unsupported` rather than a parse error (plan §21).

use std::collections::BTreeMap;

use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::entities::{
    AiuxError, Approval, ApprovalResolution, Artifact, ArtifactPreview, ArtifactWorkspace,
    ContextEntity, Message, MessageRole, MessageStatus, Part, Progress, Run, Session, Surface,
    Tool,
};
use crate::PROTOCOL_VERSION;

/// Default `protocolVersion` applied when a payload omits it (tolerance).
pub(crate) fn default_protocol_version() -> String {
    PROTOCOL_VERSION.to_string()
}

/// The 19 lifecycle event types of Protocol v1 (plan §3).
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
pub enum EventType {
    /// `session.created`
    #[serde(rename = "session.created")]
    SessionCreated,
    /// `run.started`
    #[serde(rename = "run.started")]
    RunStarted,
    /// `run.cancelled`
    #[serde(rename = "run.cancelled")]
    RunCancelled,
    /// `run.completed`
    #[serde(rename = "run.completed")]
    RunCompleted,
    /// `run.failed`
    #[serde(rename = "run.failed")]
    RunFailed,
    /// `message.created`
    #[serde(rename = "message.created")]
    MessageCreated,
    /// `message.updated`
    #[serde(rename = "message.updated")]
    MessageUpdated,
    /// `part.added`
    #[serde(rename = "part.added")]
    PartAdded,
    /// `part.updated`
    #[serde(rename = "part.updated")]
    PartUpdated,
    /// `text.delta`
    #[serde(rename = "text.delta")]
    TextDelta,
    /// `tool.started`
    #[serde(rename = "tool.started")]
    ToolStarted,
    /// `tool.progress`
    #[serde(rename = "tool.progress")]
    ToolProgress,
    /// `tool.completed`
    #[serde(rename = "tool.completed")]
    ToolCompleted,
    /// `tool.failed`
    #[serde(rename = "tool.failed")]
    ToolFailed,
    /// `approval.requested`
    #[serde(rename = "approval.requested")]
    ApprovalRequested,
    /// `approval.resolved`
    #[serde(rename = "approval.resolved")]
    ApprovalResolved,
    /// `artifact.created`
    #[serde(rename = "artifact.created")]
    ArtifactCreated,
    /// `artifact.updated`
    #[serde(rename = "artifact.updated")]
    ArtifactUpdated,
    /// `surface.created`
    #[serde(rename = "surface.created")]
    SurfaceCreated,
    /// `surface.updated`
    #[serde(rename = "surface.updated")]
    SurfaceUpdated,
}

impl EventType {
    /// Wire name, e.g. `session.created`.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::SessionCreated => "session.created",
            Self::RunStarted => "run.started",
            Self::RunCancelled => "run.cancelled",
            Self::RunCompleted => "run.completed",
            Self::RunFailed => "run.failed",
            Self::MessageCreated => "message.created",
            Self::MessageUpdated => "message.updated",
            Self::PartAdded => "part.added",
            Self::PartUpdated => "part.updated",
            Self::TextDelta => "text.delta",
            Self::ToolStarted => "tool.started",
            Self::ToolProgress => "tool.progress",
            Self::ToolCompleted => "tool.completed",
            Self::ToolFailed => "tool.failed",
            Self::ApprovalRequested => "approval.requested",
            Self::ApprovalResolved => "approval.resolved",
            Self::ArtifactCreated => "artifact.created",
            Self::ArtifactUpdated => "artifact.updated",
            Self::SurfaceCreated => "surface.created",
            Self::SurfaceUpdated => "surface.updated",
        }
    }

    /// Parse a wire `type` string. `None` for anything outside Protocol v1.
    pub fn from_name(s: &str) -> Option<Self> {
        Some(match s {
            "session.created" => Self::SessionCreated,
            "run.started" => Self::RunStarted,
            "run.cancelled" => Self::RunCancelled,
            "run.completed" => Self::RunCompleted,
            "run.failed" => Self::RunFailed,
            "message.created" => Self::MessageCreated,
            "message.updated" => Self::MessageUpdated,
            "part.added" => Self::PartAdded,
            "part.updated" => Self::PartUpdated,
            "text.delta" => Self::TextDelta,
            "tool.started" => Self::ToolStarted,
            "tool.progress" => Self::ToolProgress,
            "tool.completed" => Self::ToolCompleted,
            "tool.failed" => Self::ToolFailed,
            "approval.requested" => Self::ApprovalRequested,
            "approval.resolved" => Self::ApprovalResolved,
            "artifact.created" => Self::ArtifactCreated,
            "artifact.updated" => Self::ArtifactUpdated,
            "surface.created" => Self::SurfaceCreated,
            "surface.updated" => Self::SurfaceUpdated,
            _ => return None,
        })
    }

    /// All v1 event types, in protocol order.
    pub const ALL: [EventType; 20] = [
        Self::SessionCreated,
        Self::RunStarted,
        Self::RunCancelled,
        Self::RunCompleted,
        Self::RunFailed,
        Self::MessageCreated,
        Self::MessageUpdated,
        Self::PartAdded,
        Self::PartUpdated,
        Self::TextDelta,
        Self::ToolStarted,
        Self::ToolProgress,
        Self::ToolCompleted,
        Self::ToolFailed,
        Self::ApprovalRequested,
        Self::ApprovalResolved,
        Self::ArtifactCreated,
        Self::ArtifactUpdated,
        Self::SurfaceCreated,
        Self::SurfaceUpdated,
    ];
}

/// The canonical event envelope. `P` defaults to a raw JSON payload for
/// dispatch-time parsing; typed instantiations (`AiuxEvent<SessionCreated>`)
/// are used for schema generation and typed producers.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct AiuxEvent<P = Value> {
    /// Unique event identifier — replays of a known id are ignored.
    pub event_id: String,
    /// Owning session.
    pub session_id: String,
    /// Monotonic sequence within the session (0-based).
    pub sequence: u64,
    /// Event timestamp (ISO-8601, host-supplied — never core-generated).
    pub timestamp: String,
    /// Event type, e.g. `session.created`. Unknown values deserialize fine
    /// and fail later with `ProtocolError::Unsupported`.
    #[serde(rename = "type")]
    pub kind: String,
    /// Protocol version of this event.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Type-specific payload.
    pub payload: P,
    /// Unknown optional fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

impl AiuxEvent<Value> {
    /// Build an event from a typed payload struct.
    pub fn new<T: Serialize>(
        event_id: impl Into<String>,
        session_id: impl Into<String>,
        sequence: u64,
        timestamp: impl Into<String>,
        kind: EventType,
        payload: &T,
    ) -> serde_json::Result<Self> {
        Ok(Self {
            event_id: event_id.into(),
            session_id: session_id.into(),
            sequence,
            timestamp: timestamp.into(),
            kind: kind.as_str().to_string(),
            protocol_version: PROTOCOL_VERSION.to_string(),
            payload: serde_json::to_value(payload)?,
            extra: BTreeMap::new(),
        })
    }

    /// The typed event kind, or `None` for an unrecognized `type`.
    pub fn event_type(&self) -> Option<EventType> {
        EventType::from_name(&self.kind)
    }
}

/// `session.created` — establishes session metadata.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct SessionCreated {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// The session entity.
    pub session: Session,
}

/// `run.started` — begins an agent execution span.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct RunStarted {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// The run.
    pub run: Run,
    /// Context entities injected with this run.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub context: Vec<ContextEntity>,
}

/// `run.completed`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct RunCompleted {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Run id.
    pub run_id: String,
    /// Optional run result.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
}

/// `run.failed`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct RunFailed {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Run id.
    pub run_id: String,
    /// Failure error.
    pub error: AiuxError,
}

/// `run.cancelled`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct RunCancelled {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Run id.
    pub run_id: String,
    /// Cancellation reason.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
}

/// `message.created`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct MessageCreated {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// The message.
    pub message: Message,
}

/// `message.updated` — partial update; absent fields are untouched and parts
/// are never modified here (they accumulate via `part.added`/`part.updated`).
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct MessageUpdated {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Message id.
    pub message_id: String,
    /// New status, if changing.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status: Option<MessageStatus>,
    /// New role, if changing.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub role: Option<MessageRole>,
    /// New metadata, if changing.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<Value>,
}

/// `part.added` — append a part to a message.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct PartAdded {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Target message id.
    pub message_id: String,
    /// The part to append.
    pub part: Part,
}

/// `part.updated` — replace a part in place (same id, position preserved).
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct PartUpdated {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Target message id.
    pub message_id: String,
    /// Id of the part being replaced.
    pub part_id: String,
    /// Replacement part.
    pub part: Part,
}

/// `text.delta` — append a streaming delta to a `text` or `markdown` part.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TextDelta {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Target message id.
    pub message_id: String,
    /// Target part id.
    pub part_id: String,
    /// Text to append.
    pub delta: String,
}

/// `tool.started`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ToolStarted {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// The tool invocation.
    pub tool: Tool,
}

/// `tool.progress`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ToolProgress {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Tool id.
    pub tool_id: String,
    /// Latest progress.
    pub progress: Progress,
}

/// `tool.completed`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ToolCompleted {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Tool id.
    pub tool_id: String,
    /// Tool result.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
}

/// `tool.failed`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ToolFailed {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Tool id.
    pub tool_id: String,
    /// Failure error.
    pub error: AiuxError,
}

/// `approval.requested`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ApprovalRequested {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// The approval request.
    pub approval: Approval,
}

/// `approval.resolved` — resolves a requested approval, or marks an approved
/// one executed. Resolutions on an already-resolved approval are absorbed
/// without effect so replays never re-execute (plan §23).
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ApprovalResolved {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Approval id.
    pub approval_id: String,
    /// The resolution.
    pub resolution: ApprovalResolution,
}

/// `artifact.created`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ArtifactCreated {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// The artifact.
    pub artifact: Artifact,
}

/// `artifact.updated` — partial update; `revision` bumps automatically.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ArtifactUpdated {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Artifact id.
    pub artifact_id: String,
    /// New title, if changing.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    /// New inline content, if changing.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub content: Option<String>,
    /// New external URI, if changing.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub uri: Option<String>,
    /// New metadata, if changing.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<Value>,
    /// New preview contract, if changing (ADR 0007).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub preview: Option<ArtifactPreview>,
    /// New workspace contract, if changing (ADR 0007).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub workspace: Option<ArtifactWorkspace>,
}

/// `surface.created`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct SurfaceCreated {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// The surface (root node must be `surface`; validated per §6).
    pub surface: Surface,
}

/// `surface.updated` — replace the root node; `revision` bumps automatically.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct SurfaceUpdated {
    /// Protocol version carried by the payload.
    #[serde(default = "default_protocol_version")]
    pub protocol_version: String,
    /// Surface id.
    pub surface_id: String,
    /// New root node.
    pub root: crate::entities::SurfaceNode,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn event_type_round_trip() {
        for t in EventType::ALL {
            assert_eq!(EventType::from_name(t.as_str()), Some(t));
        }
        assert_eq!(EventType::from_name("message.deleted"), None);
    }

    #[test]
    fn envelope_parse_tolerates_unknown_fields_and_type() {
        let json = r#"{
            "eventId": "e1", "sessionId": "s1", "sequence": 0,
            "timestamp": "2026-01-01T00:00:00Z",
            "type": "message.reacted", "payload": {"emoji": "+"},
            "futureField": true
        }"#;
        let ev: AiuxEvent = serde_json::from_str(json).unwrap();
        assert_eq!(ev.event_type(), None);
        assert_eq!(ev.extra["futureField"], true);
    }
}
