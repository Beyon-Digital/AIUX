//! aiux-reducer — deterministic event reduction (plan §4, ADR 0001).
//!
//! Same initial state + same ordered events ⇒ identical resulting state.
//! The reducer contains no clocks, no randomness, and no `HashMap`
//! iteration-order leaks — every collection is insertion-ordered or
//! key-sorted (`OrderedMap`, `BTreeMap`).

mod store;

use std::collections::BTreeMap;

use aiux_protocol::*;
use serde::{Deserialize, Serialize};
use serde_json::Value;
pub use store::{HasId, OrderedMap};

/// The complete reduced session state. Pure function of the applied event
/// sequence — this is what `serialize()` persists and `snapshot()` projects.
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct SessionState {
    /// Session entity, once `session.created` lands.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub session: Option<Session>,
    /// Messages in arrival order.
    #[serde(default, skip_serializing_if = "OrderedMap::is_empty")]
    pub messages: OrderedMap<Message>,
    /// Tool invocations in start order.
    #[serde(default, skip_serializing_if = "OrderedMap::is_empty")]
    pub tools: OrderedMap<Tool>,
    /// Approval requests in request order.
    #[serde(default, skip_serializing_if = "OrderedMap::is_empty")]
    pub approvals: OrderedMap<Approval>,
    /// Artifacts in creation order.
    #[serde(default, skip_serializing_if = "OrderedMap::is_empty")]
    pub artifacts: OrderedMap<Artifact>,
    /// Surfaces in creation order.
    #[serde(default, skip_serializing_if = "OrderedMap::is_empty")]
    pub surfaces: OrderedMap<Surface>,
    /// Context entities in injection order.
    #[serde(default, skip_serializing_if = "OrderedMap::is_empty")]
    pub context: OrderedMap<ContextEntity>,
    /// Runs in start order.
    #[serde(default, skip_serializing_if = "OrderedMap::is_empty")]
    pub runs: OrderedMap<Run>,
    /// Currently-active run, if any.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub active_run_id: Option<String>,
}

fn invalid(detail: impl Into<String>) -> ProtocolError {
    ProtocolError::InvalidEvent {
        detail: detail.into(),
    }
}

fn payload<T: serde::de::DeserializeOwned>(event: &AiuxEvent<Value>) -> Result<T, ProtocolError> {
    let p: T = serde_json::from_value(event.payload.clone())
        .map_err(|e| invalid(format!("{} payload: {e}", event.kind)))?;
    Ok(p)
}

/// Reduce one event into `state`. Pure and deterministic: no timestamps are
/// generated, no randomness used. `event` must already have passed ordering
/// and idempotency checks (owned by `aiux-session`).
pub fn reduce(state: &mut SessionState, event: &AiuxEvent<Value>) -> Result<(), ProtocolError> {
    check_protocol_version(&event.protocol_version)?;
    let kind = event
        .event_type()
        .ok_or_else(|| ProtocolError::Unsupported {
            detail: format!("unknown event type \"{}\"", event.kind),
        })?;
    match kind {
        EventType::SessionCreated => {
            let p: SessionCreated = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            if p.session.id.is_empty() {
                return Err(invalid("session.created: session id must be non-empty"));
            }
            for entity in &p.session.context {
                state.context.insert(entity.clone());
            }
            state.session = Some(p.session);
        }
        EventType::RunStarted => {
            let p: RunStarted = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            if p.run.id.is_empty() {
                return Err(invalid("run.started: run id must be non-empty"));
            }
            if state.runs.contains(&p.run.id) {
                return Err(invalid(format!(
                    "run.started: run \"{}\" already exists",
                    p.run.id
                )));
            }
            for entity in p.context {
                state.context.insert(entity);
            }
            let mut run = p.run;
            run.status = RunStatus::Running;
            state.active_run_id = Some(run.id.clone());
            state.runs.insert(run);
        }
        EventType::RunCompleted => {
            let p: RunCompleted = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            let run = running_run(state, &p.run_id, "run.completed")?;
            run.status = RunStatus::Completed;
            run.result = p.result;
            if state.active_run_id.as_deref() == Some(p.run_id.as_str()) {
                state.active_run_id = None;
            }
        }
        EventType::RunFailed => {
            let p: RunFailed = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            let run = running_run(state, &p.run_id, "run.failed")?;
            run.status = RunStatus::Failed;
            run.error = Some(p.error);
            if state.active_run_id.as_deref() == Some(p.run_id.as_str()) {
                state.active_run_id = None;
            }
        }
        EventType::RunCancelled => {
            let p: RunCancelled = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            let run = running_run(state, &p.run_id, "run.cancelled")?;
            run.status = RunStatus::Cancelled;
            run.error = p.reason.map(|r| AiuxError {
                code: "cancelled".to_string(),
                message: r,
                retryable: None,
                detail: None,
                extra: BTreeMap::new(),
            });
            if state.active_run_id.as_deref() == Some(p.run_id.as_str()) {
                state.active_run_id = None;
            }
        }
        EventType::MessageCreated => {
            let p: MessageCreated = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            if p.message.id.is_empty() {
                return Err(invalid("message.created: message id must be non-empty"));
            }
            if state.messages.contains(&p.message.id) {
                return Err(invalid(format!(
                    "message.created: message \"{}\" already exists",
                    p.message.id
                )));
            }
            for part in &p.message.parts {
                if part.id().is_empty() {
                    return Err(invalid("message.created: part id must be non-empty"));
                }
            }
            state.messages.insert(p.message);
        }
        EventType::MessageUpdated => {
            let p: MessageUpdated = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            let message = state.messages.get_mut(&p.message_id).ok_or_else(|| {
                invalid(format!(
                    "message.updated: unknown message \"{}\"",
                    p.message_id
                ))
            })?;
            if let Some(status) = p.status {
                message.status = Some(status);
            }
            if let Some(role) = p.role {
                message.role = role;
            }
            if let Some(metadata) = p.metadata {
                message.metadata = Some(metadata);
            }
        }
        EventType::PartAdded => {
            let p: PartAdded = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            let message = state.messages.get_mut(&p.message_id).ok_or_else(|| {
                invalid(format!("part.added: unknown message \"{}\"", p.message_id))
            })?;
            if p.part.id().is_empty() {
                return Err(invalid("part.added: part id must be non-empty"));
            }
            if message.parts.iter().any(|q| q.id() == p.part.id()) {
                return Err(invalid(format!(
                    "part.added: part \"{}\" already exists in message \"{}\"",
                    p.part.id(),
                    p.message_id
                )));
            }
            message.parts.push(p.part);
        }
        EventType::PartUpdated => {
            let p: PartUpdated = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            let message = state.messages.get_mut(&p.message_id).ok_or_else(|| {
                invalid(format!(
                    "part.updated: unknown message \"{}\"",
                    p.message_id
                ))
            })?;
            let idx = message
                .parts
                .iter()
                .position(|q| q.id() == p.part_id)
                .ok_or_else(|| {
                    invalid(format!(
                        "part.updated: unknown part \"{}\" in message \"{}\"",
                        p.part_id, p.message_id
                    ))
                })?;
            message.parts[idx] = p.part;
        }
        EventType::TextDelta => {
            let p: TextDelta = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            let message = state.messages.get_mut(&p.message_id).ok_or_else(|| {
                invalid(format!("text.delta: unknown message \"{}\"", p.message_id))
            })?;
            let part = message
                .parts
                .iter_mut()
                .find(|q| q.id() == p.part_id)
                .ok_or_else(|| {
                    invalid(format!(
                        "text.delta: unknown part \"{}\" in message \"{}\"",
                        p.part_id, p.message_id
                    ))
                })?;
            match part {
                Part::Text(t) => t.text.push_str(&p.delta),
                Part::Markdown(m) => m.markdown.push_str(&p.delta),
                other => {
                    return Err(invalid(format!(
                        "text.delta: part \"{}\" is \"{}\", not text/markdown",
                        p.part_id,
                        other.kind()
                    )))
                }
            }
        }
        EventType::ToolStarted => {
            let p: ToolStarted = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            aiux_tools::started(&mut state.tools, p.tool)?;
        }
        EventType::ToolProgress => {
            let p: ToolProgress = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            aiux_tools::progress(&mut state.tools, &p.tool_id, p.progress)?;
        }
        EventType::ToolCompleted => {
            let p: ToolCompleted = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            aiux_tools::completed(&mut state.tools, &p.tool_id, p.result, None)?;
        }
        EventType::ToolFailed => {
            let p: ToolFailed = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            aiux_tools::failed(&mut state.tools, &p.tool_id, p.error, None)?;
        }
        EventType::ApprovalRequested => {
            let p: ApprovalRequested = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            aiux_approvals::requested(&mut state.approvals, p.approval)?;
        }
        EventType::ApprovalResolved => {
            let p: ApprovalResolved = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            aiux_approvals::resolved(&mut state.approvals, &p.approval_id, p.resolution)?;
        }
        EventType::ArtifactCreated => {
            // Raw-key validation runs on embedded surface descriptor roots
            // first so nothing outside the schema is silently dropped (§23).
            let artifact_val = event
                .payload
                .get("artifact")
                .ok_or_else(|| invalid("artifact.created: missing \"artifact\""))?;
            validate_descriptor_roots_raw(artifact_val)?;
            let p: ArtifactCreated = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            validate_artifact_descriptors(&p.artifact)?;
            aiux_artifacts::created(&mut state.artifacts, p.artifact)?;
        }
        EventType::ArtifactUpdated => {
            validate_descriptor_roots_raw(&event.payload)?;
            let p: ArtifactUpdated = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            for descriptor in [
                p.preview.as_ref().and_then(|v| v.surface.as_ref()),
                p.workspace.as_ref().and_then(|v| v.surface.as_ref()),
            ]
            .into_iter()
            .flatten()
            {
                aiux_surfaces::validate_descriptor(descriptor).map_err(|e| invalid(e.detail))?;
            }
            aiux_artifacts::updated(&mut state.artifacts, &p)?;
        }
        EventType::SurfaceCreated => {
            // Raw-key validation runs on the untyped JSON first so nothing
            // outside the schema is silently dropped (§6/§23).
            let surface_val = event
                .payload
                .get("surface")
                .ok_or_else(|| invalid("surface.created: missing \"surface\""))?;
            if let Some(root) = surface_val.get("root") {
                aiux_surfaces::validate_raw(root).map_err(|e| invalid(e.detail))?;
            }
            let p: SurfaceCreated = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            aiux_surfaces::validate(&p.surface).map_err(|e| invalid(e.detail))?;
            if state.surfaces.contains(&p.surface.id) {
                return Err(invalid(format!(
                    "surface.created: surface \"{}\" already exists",
                    p.surface.id
                )));
            }
            state.surfaces.insert(p.surface);
        }
        EventType::SurfaceUpdated => {
            let p: SurfaceUpdated = payload(event)?;
            check_protocol_version(&p.protocol_version)?;
            if let Some(root_val) = event.payload.get("root") {
                aiux_surfaces::validate_raw(root_val).map_err(|e| invalid(e.detail))?;
            }
            let existing = state.surfaces.get(&p.surface_id).ok_or_else(|| {
                invalid(format!(
                    "surface.updated: unknown surface \"{}\"",
                    p.surface_id
                ))
            })?;
            let candidate = Surface {
                id: existing.id.clone(),
                name: existing.name.clone(),
                revision: existing.revision + 1,
                root: p.root,
                extra: existing.extra.clone(),
            };
            aiux_surfaces::validate(&candidate).map_err(|e| invalid(e.detail))?;
            state.surfaces.insert(candidate);
        }
    }
    Ok(())
}

/// Raw-validate embedded surface descriptor roots under `container`
/// (`preview.surface.root`, `workspace.surface.root`) before typed parsing
/// (ADR 0007).
fn validate_descriptor_roots_raw(container: &Value) -> Result<(), ProtocolError> {
    for key in ["preview", "workspace"] {
        if let Some(root) = container
            .get(key)
            .and_then(|v| v.get("surface"))
            .and_then(|v| v.get("root"))
        {
            aiux_surfaces::validate_raw(root).map_err(|e| invalid(e.detail))?;
        }
    }
    Ok(())
}

/// Typed validation of an artifact's embedded surface descriptors.
fn validate_artifact_descriptors(artifact: &Artifact) -> Result<(), ProtocolError> {
    for descriptor in [
        artifact.preview.as_ref().and_then(|v| v.surface.as_ref()),
        artifact.workspace.as_ref().and_then(|v| v.surface.as_ref()),
    ]
    .into_iter()
    .flatten()
    {
        aiux_surfaces::validate_descriptor(descriptor).map_err(|e| invalid(e.detail))?;
    }
    Ok(())
}

fn running_run<'a>(
    state: &'a mut SessionState,
    run_id: &str,
    event: &str,
) -> Result<&'a mut Run, ProtocolError> {
    let run = state
        .runs
        .get_mut(run_id)
        .ok_or_else(|| invalid(format!("{event}: unknown run \"{run_id}\"")))?;
    match run.status {
        RunStatus::Running => Ok(run),
        other => Err(invalid(format!(
            "{event}: run \"{run_id}\" already {other:?}"
        ))),
    }
}

// Store implementations bridging the lifecycle crates onto OrderedMap.
impl aiux_tools::ToolStore for OrderedMap<Tool> {
    fn contains(&self, id: &str) -> bool {
        OrderedMap::contains(self, id)
    }
    fn get_mut(&mut self, id: &str) -> Option<&mut Tool> {
        OrderedMap::get_mut(self, id)
    }
    fn insert(&mut self, tool: Tool) {
        OrderedMap::insert(self, tool)
    }
}

impl aiux_approvals::ApprovalStore for OrderedMap<Approval> {
    fn contains(&self, id: &str) -> bool {
        OrderedMap::contains(self, id)
    }
    fn get_mut(&mut self, id: &str) -> Option<&mut Approval> {
        OrderedMap::get_mut(self, id)
    }
    fn insert(&mut self, approval: Approval) {
        OrderedMap::insert(self, approval)
    }
}

impl aiux_artifacts::ArtifactStore for OrderedMap<Artifact> {
    fn contains(&self, id: &str) -> bool {
        OrderedMap::contains(self, id)
    }
    fn get_mut(&mut self, id: &str) -> Option<&mut Artifact> {
        OrderedMap::get_mut(self, id)
    }
    fn insert(&mut self, artifact: Artifact) {
        OrderedMap::insert(self, artifact)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ev(seq: u64, kind: EventType, payload: &impl Serialize) -> AiuxEvent {
        AiuxEvent::new(
            format!("e{seq}"),
            "s1",
            seq,
            "2026-01-01T00:00:00Z",
            kind,
            payload,
        )
        .unwrap()
    }

    fn base_state() -> SessionState {
        let mut state = SessionState::default();
        reduce(
            &mut state,
            &ev(
                0,
                EventType::SessionCreated,
                &SessionCreated {
                    protocol_version: PROTOCOL_VERSION.to_string(),
                    session: Session {
                        id: "s1".to_string(),
                        title: Some("t".to_string()),
                        created_at: None,
                        capabilities: vec![],
                        context: vec![],
                        metadata: None,
                        extra: BTreeMap::new(),
                    },
                },
            ),
        )
        .unwrap();
        state
    }

    #[test]
    fn text_delta_appends() {
        let mut state = base_state();
        reduce(
            &mut state,
            &ev(
                1,
                EventType::MessageCreated,
                &MessageCreated {
                    protocol_version: PROTOCOL_VERSION.to_string(),
                    message: Message {
                        id: "m1".to_string(),
                        role: MessageRole::Assistant,
                        status: Some(MessageStatus::Streaming),
                        parts: vec![Part::Text(TextPart {
                            id: "p1".to_string(),
                            text: "Hel".to_string(),
                            extra: BTreeMap::new(),
                        })],
                        created_at: None,
                        metadata: None,
                        extra: BTreeMap::new(),
                    },
                },
            ),
        )
        .unwrap();
        reduce(
            &mut state,
            &ev(
                2,
                EventType::TextDelta,
                &TextDelta {
                    protocol_version: PROTOCOL_VERSION.to_string(),
                    message_id: "m1".to_string(),
                    part_id: "p1".to_string(),
                    delta: "lo".to_string(),
                },
            ),
        )
        .unwrap();
        let msg = state.messages.get("m1").unwrap();
        assert_eq!(
            match &msg.parts[0] {
                Part::Text(t) => t.text.as_str(),
                _ => unreachable!(),
            },
            "Hello"
        );
    }

    #[test]
    fn unknown_event_type_is_unsupported() {
        let mut state = base_state();
        let mut e = ev(1, EventType::MessageCreated, &serde_json::json!({}));
        e.kind = "message.deleted".to_string();
        let err = reduce(&mut state, &e).unwrap_err();
        assert!(matches!(err, ProtocolError::Unsupported { .. }));
    }

    #[test]
    fn invalid_payload_rejected() {
        let mut state = base_state();
        let e = ev(
            1,
            EventType::MessageCreated,
            &serde_json::json!({"wrong": true}),
        );
        assert!(matches!(
            reduce(&mut state, &e),
            Err(ProtocolError::InvalidEvent { .. })
        ));
    }
}
