//! aiux-uniffi — UniFFI boundary over the frozen `AiuxSession` facade.
//!
//! ADR 0005 / plan §5: exactly one object crosses the boundary with a coarse
//! JSON-in/JSON-out surface. No internal reducer or model type is exposed.
//!
//! UniFFI object methods take `&self`, so the facade lives behind a `Mutex`.

use std::sync::{Arc, Mutex, MutexGuard};

use aiux_protocol::ProtocolError;

uniffi::setup_scaffolding!("aiux");

/// Recoverable, explicitly-typed failures surfaced to Swift/Kotlin callers.
/// Mirrors `aiux_protocol::ProtocolError`; `Internal` covers non-protocol
/// failures (lock poisoning, report serialization).
#[derive(Debug, uniffi::Error)]
pub enum AiuxError {
    InvalidEvent { detail: String },
    SequenceGap { expected: u64, received: u64 },
    Unsupported { detail: String },
    CorruptState { detail: String },
    Internal { detail: String },
}

impl std::fmt::Display for AiuxError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::InvalidEvent { detail } => write!(f, "invalid event: {detail}"),
            Self::SequenceGap { expected, received } => {
                write!(f, "sequence gap: expected {expected}, received {received}")
            }
            Self::Unsupported { detail } => write!(f, "unsupported semantics: {detail}"),
            Self::CorruptState { detail } => write!(f, "corrupt state: {detail}"),
            Self::Internal { detail } => write!(f, "internal error: {detail}"),
        }
    }
}

impl std::error::Error for AiuxError {}

impl From<ProtocolError> for AiuxError {
    fn from(e: ProtocolError) -> Self {
        match e {
            ProtocolError::InvalidEvent { detail } => Self::InvalidEvent { detail },
            ProtocolError::SequenceGap { expected, received } => {
                Self::SequenceGap { expected, received }
            }
            ProtocolError::Unsupported { detail } => Self::Unsupported { detail },
            ProtocolError::CorruptState { detail } => Self::CorruptState { detail },
        }
    }
}

/// An AI interaction session: owned by the core, driven by the host.
/// All inputs and outputs are JSON strings (plan §4 contract).
#[derive(uniffi::Object)]
pub struct AiuxSession {
    inner: Mutex<aiux_session::AiuxSession>,
}

impl AiuxSession {
    fn lock(&self) -> Result<MutexGuard<'_, aiux_session::AiuxSession>, AiuxError> {
        self.inner.lock().map_err(|_| AiuxError::Internal {
            detail: "session lock poisoned".to_string(),
        })
    }

    fn report_json(report: aiux_protocol::DispatchReport) -> Result<String, AiuxError> {
        serde_json::to_string(&report).map_err(|e| AiuxError::Internal {
            detail: format!("dispatch report serialization: {e}"),
        })
    }
}

#[uniffi::export]
impl AiuxSession {
    /// Create a session from a JSON config payload.
    /// The facade is only constructible through JSON.
    #[uniffi::constructor]
    pub fn create(config_json: String) -> Result<Arc<Self>, AiuxError> {
        Ok(Arc::new(Self {
            inner: Mutex::new(aiux_session::AiuxSession::create(&config_json)?),
        }))
    }

    /// Restore a session from a `serialize()` payload.
    #[uniffi::constructor]
    pub fn restore(serialized_json: String) -> Result<Arc<Self>, AiuxError> {
        Ok(Arc::new(Self {
            inner: Mutex::new(aiux_session::AiuxSession::restore(&serialized_json)?),
        }))
    }

    /// Reduce one event (JSON) into session state. Returns the dispatch
    /// report (`{applied,duplicatesIgnored,buffered}`) as JSON.
    pub fn dispatch(&self, event_json: String) -> Result<String, AiuxError> {
        let report = self.lock()?.dispatch(&event_json)?;
        Self::report_json(report)
    }

    /// Reduce an ordered JSON array of events in one FFI call (plan §22:
    /// streaming deltas batch here, never one call per token).
    pub fn dispatch_batch(&self, events_json: String) -> Result<String, AiuxError> {
        let report = self.lock()?.dispatch_batch(&events_json)?;
        Self::report_json(report)
    }

    /// Canonical-JSON render snapshot for the current state.
    pub fn snapshot(&self) -> Result<String, AiuxError> {
        self.lock()?.snapshot().map_err(AiuxError::from)
    }

    /// Canonical-JSON serialized session state (persistence/replay).
    pub fn serialize(&self) -> Result<String, AiuxError> {
        self.lock()?.serialize().map_err(AiuxError::from)
    }

    /// Clear all session state.
    pub fn reset(&self) {
        if let Ok(mut guard) = self.inner.lock() {
            guard.reset();
        }
    }
}

#[cfg(test)]
mod smoke {
    use super::*;

    const EVENT: &str = r#"{"eventId":"e0","sessionId":"s1","sequence":0,"timestamp":"2026-01-01T00:00:00Z","type":"session.created","payload":{"protocolVersion":"0.1","session":{"id":"s1"}}}"#;

    #[test]
    fn ffi_surface_roundtrip() {
        let s = AiuxSession::create(String::from(r#"{"sessionId":"s1"}"#)).unwrap();
        let report = s.dispatch(String::from(EVENT)).unwrap();
        assert_eq!(
            report,
            r#"{"applied":1,"duplicatesIgnored":0,"buffered":0}"#
        );
        assert!(s.snapshot().unwrap().contains("s1"));
        let restored = AiuxSession::restore(s.serialize().unwrap()).unwrap();
        assert_eq!(s.snapshot().unwrap(), restored.snapshot().unwrap());
        s.reset();
        assert!(s.snapshot().unwrap().contains("\"messages\": []"));

        let err = AiuxSession::restore("not json".to_string()).err().unwrap();
        assert!(matches!(err, AiuxError::CorruptState { .. }));
    }
}
