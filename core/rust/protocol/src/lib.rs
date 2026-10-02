//! aiux-protocol — AIUX Protocol v1 types and errors.
//!
//! Canonical wire types land in Phase 1 (docs/PLAN.md §3). This module freezes
//! the error/result vocabulary shared by the session facade and every FFI
//! boundary so bindings can be built against it in parallel.

use serde::{Deserialize, Serialize};

/// Protocol version emitted in every payload (`protocolVersion`).
pub const PROTOCOL_VERSION: &str = "0.1";

/// Recoverable, explicitly-typed failures crossing the session boundary.
///
/// Out-of-order and unknown-required-semantics cases map to these variants;
/// nothing may silently corrupt state (ADR 0001, plan §4/§21).
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
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
#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct DispatchReport {
    /// Events that mutated state.
    pub applied: u64,
    /// Duplicate `eventId`s safely ignored (idempotency).
    pub duplicates_ignored: u64,
    /// Events buffered pending missing earlier sequences.
    pub buffered: u64,
}
