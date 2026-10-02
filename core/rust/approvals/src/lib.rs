//! aiux-approvals — approval lifecycle (plan §3, §23).
//!
//! `requested → approved | rejected | expired`, then `approved → executed`.
//! A resolution on an already-resolved approval is absorbed as a no-op so a
//! replayed `approval.resolved` never re-executes (§23). An `executed`
//! decision on a non-approved request is `InvalidEvent`.

use aiux_protocol::{
    Approval, ApprovalDecision, ApprovalResolution, ApprovalStatus, ProtocolError,
};

fn invalid(detail: impl Into<String>) -> ProtocolError {
    ProtocolError::InvalidEvent {
        detail: detail.into(),
    }
}

/// Minimal store abstraction; the reducer supplies its ordered store.
pub trait ApprovalStore {
    /// Whether an approval id exists.
    fn contains(&self, id: &str) -> bool;
    /// Mutable access by id.
    fn get_mut(&mut self, id: &str) -> Option<&mut Approval>;
    /// Insert an approval.
    fn insert(&mut self, approval: Approval);
}

/// `approval.requested`: insert a new requested approval.
pub fn requested(store: &mut dyn ApprovalStore, approval: Approval) -> Result<(), ProtocolError> {
    if approval.id.is_empty() {
        return Err(invalid("approval.requested: approval id must be non-empty"));
    }
    if store.contains(&approval.id) {
        return Err(invalid(format!(
            "approval.requested: approval \"{}\" already exists",
            approval.id
        )));
    }
    let mut approval = approval;
    approval.status = ApprovalStatus::Requested;
    approval.resolution = None;
    store.insert(approval);
    Ok(())
}

/// `approval.resolved`.
///
/// - `Requested` → `Approved` / `Rejected` / `Expired`.
/// - `Approved` + decision `Executed` → `Executed` (the one legal
///   terminal-to-terminal transition, recorded once by the host after it
///   actually runs the gated action).
/// - Every other resolution on a non-`Requested` approval is a **no-op**:
///   the id is recorded but state does not change, so replayed or conflicting
///   resolutions can never flip a decision or re-execute an action.
pub fn resolved(
    store: &mut dyn ApprovalStore,
    approval_id: &str,
    resolution: ApprovalResolution,
) -> Result<(), ProtocolError> {
    let approval = store.get_mut(approval_id).ok_or_else(|| {
        invalid(format!(
            "approval.resolved: unknown approval \"{approval_id}\""
        ))
    })?;
    match (approval.status, resolution.decision) {
        (ApprovalStatus::Requested, ApprovalDecision::Approved) => {
            approval.status = ApprovalStatus::Approved;
            approval.resolution = Some(resolution);
        }
        (ApprovalStatus::Requested, ApprovalDecision::Rejected) => {
            approval.status = ApprovalStatus::Rejected;
            approval.resolution = Some(resolution);
        }
        (ApprovalStatus::Requested, ApprovalDecision::Expired) => {
            approval.status = ApprovalStatus::Expired;
            approval.resolution = Some(resolution);
        }
        (ApprovalStatus::Requested, ApprovalDecision::Executed) => {
            return Err(invalid(format!(
                "approval.resolved: \"{approval_id}\" was never approved; cannot mark executed"
            )));
        }
        (ApprovalStatus::Approved, ApprovalDecision::Executed) => {
            approval.status = ApprovalStatus::Executed;
            approval.resolution = Some(resolution);
        }
        // Resolved-but-superseded: absorbed silently by design (§23).
        _ => {}
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeMap;

    struct Map(BTreeMap<String, Approval>);
    impl ApprovalStore for Map {
        fn contains(&self, id: &str) -> bool {
            self.0.contains_key(id)
        }
        fn get_mut(&mut self, id: &str) -> Option<&mut Approval> {
            self.0.get_mut(id)
        }
        fn insert(&mut self, a: Approval) {
            self.0.insert(a.id.clone(), a);
        }
    }

    fn approval(id: &str) -> Approval {
        Approval {
            id: id.to_string(),
            prompt: "Approve?".to_string(),
            description: None,
            tool_id: None,
            action: None,
            status: ApprovalStatus::Requested,
            expires_at: None,
            resolution: None,
            extra: Default::default(),
        }
    }

    fn res(decision: ApprovalDecision) -> ApprovalResolution {
        ApprovalResolution {
            decision,
            resolved_by: Some("user".to_string()),
            note: None,
            resolved_at: None,
            extra: Default::default(),
        }
    }

    #[test]
    fn request_approve_execute() {
        let mut store = Map(BTreeMap::new());
        requested(&mut store, approval("a1")).unwrap();
        resolved(&mut store, "a1", res(ApprovalDecision::Approved)).unwrap();
        assert_eq!(store.0["a1"].status, ApprovalStatus::Approved);
        resolved(&mut store, "a1", res(ApprovalDecision::Executed)).unwrap();
        assert_eq!(store.0["a1"].status, ApprovalStatus::Executed);
    }

    #[test]
    fn replayed_resolution_never_flips_or_reexecutes() {
        let mut store = Map(BTreeMap::new());
        requested(&mut store, approval("a1")).unwrap();
        resolved(&mut store, "a1", res(ApprovalDecision::Rejected)).unwrap();
        // A conflicting later resolution must not flip the decision.
        resolved(&mut store, "a1", res(ApprovalDecision::Approved)).unwrap();
        assert_eq!(store.0["a1"].status, ApprovalStatus::Rejected);
        // Nor mark executed.
        resolved(&mut store, "a1", res(ApprovalDecision::Executed)).unwrap();
        assert_eq!(store.0["a1"].status, ApprovalStatus::Rejected);
    }

    #[test]
    fn executed_requires_approved() {
        let mut store = Map(BTreeMap::new());
        requested(&mut store, approval("a1")).unwrap();
        assert!(resolved(&mut store, "a1", res(ApprovalDecision::Executed)).is_err());
    }
}
