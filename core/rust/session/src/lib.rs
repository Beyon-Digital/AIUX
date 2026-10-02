//! aiux-session — session facade over the AIUX Rust core.
//!
//! This is the FROZEN public contract (plan §4, ADR 0001/0005): every binding
//! (UniFFI, WASM, C ABI) and every JS transport drives the core exclusively
//! through these signatures. Internal reducer/model types stay private.
//!
//! ```text
//! create_session(config) / restore_session(serialized)
//! dispatch(event) / dispatch_batch(events)
//! snapshot() / serialize() / reset()
//! ```
//!
//! Boundaries are JSON strings end-to-end so no internal type ever crosses
//! FFI. Phase 1 fills in the reducer; this stub keeps the signature surface
//! compiling so bindings work can start in parallel.

use std::collections::{BTreeMap, BTreeSet};

use aiux_persistence::PersistedSession;
use aiux_protocol::{check_protocol_version, AiuxEvent, DispatchReport, ProtocolError};
use aiux_reducer::SessionState;
use serde::Deserialize;

/// Upper bound on out-of-order events held pending missing sequences
/// (plan §4: bounded reorder buffer; overflow → `SequenceGap`).
pub const MAX_REORDER_BUFFER: usize = 1024;

/// Configuration for a new session (opaque JSON: protocolVersion, sessionId,
/// capabilities, theme/context metadata — schema lands with Protocol v1).
pub struct SessionConfig;

/// Wire shape of the config JSON accepted by [`AiuxSession::create`].
/// Unknown fields are tolerated (plan §21).
#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SessionConfigJson {
    #[serde(default)]
    protocol_version: String,
    #[serde(default)]
    session_id: String,
}

/// An AI interaction session: owned by the core, driven by the host.
#[derive(Debug, Default)]
pub struct AiuxSession {
    /// Bound session id ("" until the first applied event binds one, or the
    /// config supplies it).
    session_id: String,
    /// Reduced state.
    state: SessionState,
    /// Next `sequence` the stream owes us.
    next_expected_sequence: u64,
    /// Ids already accepted (applied or buffered) — the idempotency ledger.
    seen_event_ids: BTreeSet<String>,
    /// Out-of-order events parked by sequence until the gap closes.
    reorder_buffer: BTreeMap<u64, AiuxEvent>,
}

impl AiuxSession {
    /// Create a session from a JSON config payload.
    pub fn create(config_json: &str) -> Result<Self, ProtocolError> {
        let config: SessionConfigJson =
            serde_json::from_str(config_json).map_err(|e| ProtocolError::InvalidEvent {
                detail: format!("session config: {e}"),
            })?;
        if !config.protocol_version.is_empty() {
            check_protocol_version(&config.protocol_version)?;
        }
        Ok(Self {
            session_id: config.session_id,
            ..Self::default()
        })
    }

    /// Restore a session from a `serialize()` payload.
    pub fn restore(serialized_json: &str) -> Result<Self, ProtocolError> {
        let persisted = aiux_persistence::load(serialized_json)?;
        let mut reorder_buffer = BTreeMap::new();
        for event in persisted.buffered_events {
            let sequence = event.sequence;
            if reorder_buffer.insert(sequence, event).is_some() {
                return Err(ProtocolError::CorruptState {
                    detail: format!("bufferedEvents contains two events at sequence {sequence}"),
                });
            }
        }
        Ok(Self {
            session_id: persisted.session_id,
            state: persisted.state,
            next_expected_sequence: persisted.next_expected_sequence,
            seen_event_ids: persisted.seen_event_ids,
            reorder_buffer,
        })
    }

    /// Reduce one event (JSON) into session state. Duplicate `eventId`s are
    /// ignored; sequence gaps buffer or return `SequenceGap`.
    pub fn dispatch(&mut self, event_json: &str) -> Result<DispatchReport, ProtocolError> {
        let event: AiuxEvent =
            serde_json::from_str(event_json).map_err(|e| ProtocolError::InvalidEvent {
                detail: format!("event envelope: {e}"),
            })?;
        self.accept(event)
    }

    /// Reduce an ordered JSON array of events in one FFI call (plan §22:
    /// streaming deltas batch here, never one call per token).
    ///
    /// All elements are validated as envelopes first — a malformed element
    /// fails the whole batch before anything is applied. A hard error
    /// mid-batch (e.g. `SequenceGap` overflow, invalid payload) stops the
    /// batch; already-applied events remain applied.
    pub fn dispatch_batch(&mut self, events_json: &str) -> Result<DispatchReport, ProtocolError> {
        let events: Vec<AiuxEvent> =
            serde_json::from_str(events_json).map_err(|e| ProtocolError::InvalidEvent {
                detail: format!("event batch: {e}"),
            })?;
        let mut report = DispatchReport::default();
        for event in events {
            let r = self.accept(event)?;
            report.applied += r.applied;
            report.duplicates_ignored += r.duplicates_ignored;
            report.buffered += r.buffered;
        }
        Ok(report)
    }

    /// Canonical-JSON render snapshot for the current state.
    pub fn snapshot(&self) -> Result<String, ProtocolError> {
        aiux_persistence::snapshot_json(&self.persisted())
    }

    /// Canonical-JSON serialized session state (persistence/replay/
    /// conformance — byte-stable for a given event sequence).
    pub fn serialize(&self) -> Result<String, ProtocolError> {
        aiux_persistence::save(&self.persisted())
    }

    /// Clear all session state.
    pub fn reset(&mut self) {
        *self = Self::default();
    }

    fn persisted(&self) -> PersistedSession {
        PersistedSession {
            protocol_version: aiux_protocol::PROTOCOL_VERSION.to_string(),
            session_id: self.session_id.clone(),
            state: self.state.clone(),
            next_expected_sequence: self.next_expected_sequence,
            seen_event_ids: self.seen_event_ids.clone(),
            buffered_events: self.reorder_buffer.values().cloned().collect(),
        }
    }

    /// Validate envelope-level invariants and route the event to the reducer,
    /// honoring idempotency (`eventId` replay) and ordering (`sequence`
    /// reorder buffer).
    fn accept(&mut self, event: AiuxEvent) -> Result<DispatchReport, ProtocolError> {
        let mut report = DispatchReport::default();

        if event.event_id.is_empty() {
            return Err(ProtocolError::InvalidEvent {
                detail: "eventId must be non-empty".to_string(),
            });
        }
        if self.seen_event_ids.contains(&event.event_id) {
            report.duplicates_ignored = 1;
            return Ok(report);
        }
        if event.session_id.is_empty() {
            return Err(ProtocolError::InvalidEvent {
                detail: "sessionId must be non-empty".to_string(),
            });
        }
        // Only an event that actually applies may bind the session
        // identity — a rejected or merely buffered event must not pin it.
        if !self.session_id.is_empty() && event.session_id != self.session_id {
            return Err(ProtocolError::InvalidEvent {
                detail: format!(
                    "event sessionId \"{}\" does not match bound session \"{}\"",
                    event.session_id, self.session_id
                ),
            });
        }

        if event.sequence < self.next_expected_sequence {
            // The slot already passed; this unseen event can never apply
            // legally — surface it as a recoverable gap, never corrupt.
            return Err(ProtocolError::SequenceGap {
                expected: self.next_expected_sequence,
                received: event.sequence,
            });
        }
        if event.sequence > self.next_expected_sequence {
            if let Some(parked) = self.reorder_buffer.get(&event.sequence) {
                // A distinct event already claims this future sequence — a
                // collision, not a replay (same-id replays were absorbed by
                // the idempotency check above). Never silently drop one.
                return Err(ProtocolError::InvalidEvent {
                    detail: format!(
                        "sequence {} is already claimed by buffered event \"{}\"",
                        event.sequence, parked.event_id
                    ),
                });
            }
            if self.reorder_buffer.len() >= MAX_REORDER_BUFFER {
                return Err(ProtocolError::SequenceGap {
                    expected: self.next_expected_sequence,
                    received: event.sequence,
                });
            }
            self.seen_event_ids.insert(event.event_id.clone());
            self.reorder_buffer.insert(event.sequence, event);
            report.buffered = 1;
            return Ok(report);
        }

        // In-order event: apply, then drain any buffered successors.
        // `reduce` is atomic per event (checks precede mutation), so the id is
        // only recorded as seen once the event has genuinely applied — a
        // failed dispatch never poisons a later corrected replay.
        aiux_reducer::reduce(&mut self.state, &event)?;
        if self.session_id.is_empty() {
            self.session_id.clone_from(&event.session_id);
        }
        self.seen_event_ids.insert(event.event_id.clone());
        report.applied = 1;
        self.next_expected_sequence += 1;
        while let Some(next) = self.reorder_buffer.remove(&self.next_expected_sequence) {
            // Events buffered while the session was still unbound must
            // belong to the session the first applied event bound.
            if next.session_id != self.session_id {
                self.seen_event_ids.remove(&next.event_id);
                return Err(ProtocolError::InvalidEvent {
                    detail: format!(
                        "buffered event sessionId \"{}\" does not match bound session \"{}\"",
                        next.session_id, self.session_id
                    ),
                });
            }
            if let Err(e) = aiux_reducer::reduce(&mut self.state, &next) {
                // The drained event never applied: release its id so the slot
                // can be filled by a corrected resend, and surface the error.
                self.seen_event_ids.remove(&next.event_id);
                return Err(e);
            }
            report.applied += 1;
            self.next_expected_sequence += 1;
        }
        Ok(report)
    }
}

#[cfg(test)]
mod smoke {
    use super::*;

    fn event(seq: u64, kind: &str, payload: &str) -> String {
        format!(
            r#"{{"eventId":"e{seq}","sessionId":"s1","sequence":{seq},"timestamp":"2026-01-01T00:00:00Z","type":"{kind}","payload":{payload}}}"#
        )
    }

    #[test]
    fn facade_contract_compiles() {
        let mut s = AiuxSession::create(r#"{"sessionId":"s1"}"#).unwrap();
        s.dispatch(&event(
            0,
            "session.created",
            r#"{"protocolVersion":"0.1","session":{"id":"s1"}}"#,
        ))
        .unwrap();
        s.dispatch_batch("[]").unwrap();
        let _ = s.snapshot().unwrap();
        let _ = s.serialize().unwrap();
        s.reset();
        let _ = AiuxSession::restore(&s.serialize().unwrap()).unwrap();
    }
}
