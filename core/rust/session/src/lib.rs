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

use aiux_protocol::{DispatchReport, ProtocolError};

/// Configuration for a new session (opaque JSON: protocolVersion, sessionId,
/// capabilities, theme/context metadata — schema lands with Protocol v1).
pub struct SessionConfig;

/// An AI interaction session: owned by the core, driven by the host.
#[derive(Debug, Default)]
pub struct AiuxSession {
    _private: (),
}

impl AiuxSession {
    /// Create a session from a JSON config payload.
    pub fn create(_config_json: &str) -> Result<Self, ProtocolError> {
        Ok(Self::default())
    }

    /// Restore a session from a `serialize()` payload.
    pub fn restore(_serialized_json: &str) -> Result<Self, ProtocolError> {
        Ok(Self::default())
    }

    /// Reduce one event (JSON) into session state. Duplicate `eventId`s are
    /// ignored; sequence gaps buffer or return `SequenceGap`.
    pub fn dispatch(&mut self, _event_json: &str) -> Result<DispatchReport, ProtocolError> {
        Ok(DispatchReport::default())
    }

    /// Reduce an ordered JSON array of events in one FFI call (plan §22:
    /// streaming deltas batch here, never one call per token).
    pub fn dispatch_batch(&mut self, _events_json: &str) -> Result<DispatchReport, ProtocolError> {
        Ok(DispatchReport::default())
    }

    /// Canonical-JSON render snapshot for the current state.
    pub fn snapshot(&self) -> Result<String, ProtocolError> {
        Ok("{}".to_string())
    }

    /// Canonical-JSON serialized session state (persistence/replay/
    /// conformance — byte-stable for a given event sequence).
    pub fn serialize(&self) -> Result<String, ProtocolError> {
        Ok("{}".to_string())
    }

    /// Clear all session state.
    pub fn reset(&mut self) {}
}

#[cfg(test)]
mod smoke {
    use super::*;

    #[test]
    fn facade_contract_compiles() {
        let mut s = AiuxSession::create("{}").unwrap();
        s.dispatch("{}").unwrap();
        s.dispatch_batch("[]").unwrap();
        let _ = s.snapshot().unwrap();
        let _ = s.serialize().unwrap();
        s.reset();
        let _ = AiuxSession::restore("{}").unwrap();
    }
}
