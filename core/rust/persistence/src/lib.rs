//! aiux-persistence — canonical serialization and restore (plan §4).
//!
//! `serialize()` output is canonical JSON: object keys recursively sorted,
//! collections in deterministic order — byte-identical for identical event
//! input, which is what conformance byte-compares.
//!
//! [`PersistedSession`] is the full reloadable state (including ordering
//! bookkeeping); [`Snapshot`] is the render-facing projection without it.

use std::collections::BTreeSet;

use aiux_protocol::{
    canonical_json, check_protocol_version, Approval, Artifact, ContextEntity, Message,
    ProtocolError, Run, Session, Surface, Tool, PROTOCOL_VERSION,
};
use aiux_reducer::SessionState;
use serde::{Deserialize, Serialize};

/// Canonical JSON for `value` — recursively key-sorted, 2-space indent,
/// trailing newline. Byte-stable for identical input.
pub fn to_canonical_json<T: Serialize>(value: &T) -> Result<String, ProtocolError> {
    canonical_json(value)
}

/// The full persisted session envelope — content + ordering bookkeeping so a
/// restored session keeps correct idempotency and sequencing.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct PersistedSession {
    /// Protocol version the state was written under.
    pub protocol_version: String,
    /// Bound session id (empty until the first event binds one).
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub session_id: String,
    /// Reduced session state.
    #[serde(default)]
    pub state: SessionState,
    /// Next expected `sequence` — resume point for ordering checks.
    #[serde(default)]
    pub next_expected_sequence: u64,
    /// Applied (or buffered) event ids — the idempotency ledger.
    #[serde(default)]
    pub seen_event_ids: BTreeSet<String>,
    /// Out-of-order events buffered pending missing sequences, persisted
    /// verbatim in sequence order.
    #[serde(default)]
    pub buffered_events: Vec<aiux_protocol::AiuxEvent>,
}

/// Serialize a persisted session to canonical JSON.
pub fn save(persisted: &PersistedSession) -> Result<String, ProtocolError> {
    canonical_json(persisted)
}

/// Restore a persisted session from canonical JSON. Version mismatches and
/// malformed state surface as explicit errors — never silent corruption.
pub fn load(json: &str) -> Result<PersistedSession, ProtocolError> {
    let persisted: PersistedSession =
        serde_json::from_str(json).map_err(|e| ProtocolError::CorruptState {
            detail: format!("parse: {e}"),
        })?;
    check_protocol_version(&persisted.protocol_version)?;
    Ok(persisted)
}

/// Render-facing projection of session state — everything a renderer needs
/// and nothing it doesn't (no ordering/idempotency bookkeeping).
#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Snapshot<'a> {
    /// Protocol version.
    pub protocol_version: &'a str,
    /// Bound session id.
    pub session_id: &'a str,
    /// Session entity, once created.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub session: Option<&'a Session>,
    /// Messages in arrival order (parts carry typed references into the
    /// entity lists below).
    pub messages: Vec<&'a Message>,
    /// Tool invocations in start order.
    pub tools: Vec<&'a Tool>,
    /// Approvals in request order.
    pub approvals: Vec<&'a Approval>,
    /// Artifacts in creation order.
    pub artifacts: Vec<&'a Artifact>,
    /// Surfaces in creation order.
    pub surfaces: Vec<&'a Surface>,
    /// Context entities in injection order.
    pub context: Vec<&'a ContextEntity>,
    /// Runs in start order.
    pub runs: Vec<&'a Run>,
    /// Currently-active run.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub active_run_id: Option<&'a str>,
}

/// Project the render snapshot for the current state.
pub fn snapshot<'a>(persisted: &'a PersistedSession) -> Snapshot<'a> {
    let s = &persisted.state;
    Snapshot {
        protocol_version: PROTOCOL_VERSION,
        session_id: &persisted.session_id,
        session: s.session.as_ref(),
        messages: s.messages.iter().collect(),
        tools: s.tools.iter().collect(),
        approvals: s.approvals.iter().collect(),
        artifacts: s.artifacts.iter().collect(),
        surfaces: s.surfaces.iter().collect(),
        context: s.context.iter().collect(),
        runs: s.runs.iter().collect(),
        active_run_id: s.active_run_id.as_deref(),
    }
}

/// Render the snapshot to canonical JSON.
pub fn snapshot_json(persisted: &PersistedSession) -> Result<String, ProtocolError> {
    canonical_json(&snapshot(persisted))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_output_is_sorted_and_stable() {
        #[derive(Serialize)]
        struct T {
            z: u32,
            a: u32,
        }
        let json = to_canonical_json(&T { z: 1, a: 2 }).unwrap();
        assert!(json.find("\"a\"").unwrap() < json.find("\"z\"").unwrap());
        assert!(json.ends_with('\n'));
    }

    #[test]
    fn load_rejects_version_mismatch() {
        let persisted = PersistedSession {
            protocol_version: "9.9".to_string(),
            session_id: String::new(),
            state: SessionState::default(),
            next_expected_sequence: 0,
            seen_event_ids: BTreeSet::new(),
            buffered_events: vec![],
        };
        let json = save(&persisted).unwrap();
        let err = load(&json).unwrap_err();
        assert!(matches!(err, ProtocolError::Unsupported { .. }));
    }
}
