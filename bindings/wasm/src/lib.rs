//! aiux-wasm — wasm-bindgen shim over the AIUX Rust core.
//!
//! Exports the frozen session facade (plan §4, ADR 0005) to JS as free
//! functions with JSON strings in/out — the same contract every other binding
//! drives. The shim is deliberately thin: no logic, no re-validation, no
//! semantics beyond the boundary format (ADR 0001 — the core owns semantics).
//!
//! Errors cross the boundary as `JsError` whose message is the canonical JSON
//! serialization of `ProtocolError` (`{"kind": "..."}`), so JS can recover the
//! typed error vocabulary without a second wire format.

use aiux_protocol::ProtocolError;
use aiux_session::AiuxSession;
use wasm_bindgen::prelude::*;

/// Opaque session handle owned by the core; JS holds it between calls and
/// releases it with `free()` (or GC finalization) when done.
#[wasm_bindgen]
pub struct WasmSession {
    inner: AiuxSession,
}

fn protocol_error_json(err: &ProtocolError) -> String {
    serde_json::to_string(err).unwrap_or_else(|_| err.to_string())
}

fn protocol_error(err: ProtocolError) -> JsError {
    JsError::new(&protocol_error_json(&err))
}

fn report_json(report: aiux_protocol::DispatchReport) -> Result<String, JsError> {
    serde_json::to_string(&report).map_err(|e| JsError::new(&e.to_string()))
}

/// Create a session from a JSON config payload.
#[wasm_bindgen(js_name = createSession)]
pub fn create_session(config_json: &str) -> Result<WasmSession, JsError> {
    AiuxSession::create(config_json)
        .map(|inner| WasmSession { inner })
        .map_err(protocol_error)
}

/// Restore a session from a `serialize()` payload.
#[wasm_bindgen(js_name = restoreSession)]
pub fn restore_session(serialized_json: &str) -> Result<WasmSession, JsError> {
    AiuxSession::restore(serialized_json)
        .map(|inner| WasmSession { inner })
        .map_err(protocol_error)
}

/// Reduce one event (JSON) into session state. Returns the `DispatchReport`
/// as a JSON string.
#[wasm_bindgen]
pub fn dispatch(session: &mut WasmSession, event_json: &str) -> Result<String, JsError> {
    session
        .inner
        .dispatch(event_json)
        .map_err(protocol_error)
        .and_then(report_json)
}

/// Reduce an ordered JSON array of events in one FFI call (plan §22: streaming
/// deltas batch here, never one call per token).
#[wasm_bindgen(js_name = dispatchBatch)]
pub fn dispatch_batch(session: &mut WasmSession, events_json: &str) -> Result<String, JsError> {
    session
        .inner
        .dispatch_batch(events_json)
        .map_err(protocol_error)
        .and_then(report_json)
}

/// Canonical-JSON render snapshot for the current state.
#[wasm_bindgen]
pub fn snapshot(session: &WasmSession) -> Result<String, JsError> {
    session.inner.snapshot().map_err(protocol_error)
}

/// Canonical-JSON serialized session state (persistence/replay/conformance).
#[wasm_bindgen]
pub fn serialize(session: &WasmSession) -> Result<String, JsError> {
    session.inner.serialize().map_err(protocol_error)
}

/// Clear all session state.
#[wasm_bindgen]
pub fn reset(session: &mut WasmSession) {
    session.inner.reset();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn facade_round_trip() {
        let mut s = create_session("{}").unwrap();
        let report = dispatch(&mut s, "{}").unwrap();
        assert!(report.contains("applied"));
        let report = dispatch_batch(&mut s, "[]").unwrap();
        assert!(report.contains("applied"));
        let _ = snapshot(&s).unwrap();
        let serialized = serialize(&s).unwrap();
        reset(&mut s);
        let _ = restore_session(&serialized).unwrap();
    }

    #[test]
    fn errors_cross_as_json() {
        // The stub facade never fails today; once the Phase 1 reducer lands,
        // ProtocolError must serialize through JsError as {"kind": ...}.
        let json = protocol_error_json(&ProtocolError::SequenceGap {
            expected: 3,
            received: 9,
        });
        assert_eq!(json, r#"{"kind":"sequenceGap","expected":3,"received":9}"#);
    }
}
