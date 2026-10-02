//! aiux-artifacts — artifact lifecycle (plan §3, §4).
//!
//! `created → updated*`. Every update bumps `revision`; an update for an
//! unknown artifact is `InvalidEvent`, as is a duplicate `artifact.created`.

use aiux_protocol::{Artifact, ArtifactUpdated, ProtocolError};

fn invalid(detail: impl Into<String>) -> ProtocolError {
    ProtocolError::InvalidEvent {
        detail: detail.into(),
    }
}

/// Minimal store abstraction; the reducer supplies its ordered store.
pub trait ArtifactStore {
    /// Whether an artifact id exists.
    fn contains(&self, id: &str) -> bool;
    /// Mutable access by id.
    fn get_mut(&mut self, id: &str) -> Option<&mut Artifact>;
    /// Insert an artifact.
    fn insert(&mut self, artifact: Artifact);
}

/// `artifact.created`: insert a new artifact at `revision` as supplied
/// (normal producers send `revision: 0` or `1`).
pub fn created(store: &mut dyn ArtifactStore, artifact: Artifact) -> Result<(), ProtocolError> {
    if artifact.id.is_empty() {
        return Err(invalid("artifact.created: artifact id must be non-empty"));
    }
    if store.contains(&artifact.id) {
        return Err(invalid(format!(
            "artifact.created: artifact \"{}\" already exists",
            artifact.id
        )));
    }
    store.insert(artifact);
    Ok(())
}

/// `artifact.updated`: apply non-empty fields and bump `revision`.
pub fn updated(
    store: &mut dyn ArtifactStore,
    patch: &ArtifactUpdated,
) -> Result<(), ProtocolError> {
    let artifact = store.get_mut(&patch.artifact_id).ok_or_else(|| {
        invalid(format!(
            "artifact.updated: unknown artifact \"{}\"",
            patch.artifact_id
        ))
    })?;
    if let Some(title) = &patch.title {
        artifact.title = Some(title.clone());
    }
    if let Some(content) = &patch.content {
        artifact.content = Some(content.clone());
    }
    if let Some(uri) = &patch.uri {
        artifact.uri = Some(uri.clone());
    }
    if let Some(metadata) = &patch.metadata {
        artifact.metadata = Some(metadata.clone());
    }
    artifact.revision += 1;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeMap;

    struct Map(BTreeMap<String, Artifact>);
    impl ArtifactStore for Map {
        fn contains(&self, id: &str) -> bool {
            self.0.contains_key(id)
        }
        fn get_mut(&mut self, id: &str) -> Option<&mut Artifact> {
            self.0.get_mut(id)
        }
        fn insert(&mut self, a: Artifact) {
            self.0.insert(a.id.clone(), a);
        }
    }

    fn artifact(id: &str) -> Artifact {
        Artifact {
            id: id.to_string(),
            kind: "document".to_string(),
            title: None,
            revision: 1,
            content: Some("v1".to_string()),
            uri: None,
            metadata: None,
            extra: Default::default(),
        }
    }

    #[test]
    fn update_bumps_revision() {
        let mut store = Map(BTreeMap::new());
        created(&mut store, artifact("a1")).unwrap();
        let patch = ArtifactUpdated {
            protocol_version: aiux_protocol::PROTOCOL_VERSION.to_string(),
            artifact_id: "a1".to_string(),
            title: Some("Doc".to_string()),
            content: Some("v2".to_string()),
            uri: None,
            metadata: None,
        };
        updated(&mut store, &patch).unwrap();
        assert_eq!(store.0["a1"].revision, 2);
        assert_eq!(store.0["a1"].content.as_deref(), Some("v2"));
    }

    #[test]
    fn unknown_update_rejected() {
        let mut store = Map(BTreeMap::new());
        let patch = ArtifactUpdated {
            protocol_version: aiux_protocol::PROTOCOL_VERSION.to_string(),
            artifact_id: "ghost".to_string(),
            title: None,
            content: None,
            uri: None,
            metadata: None,
        };
        assert!(updated(&mut store, &patch).is_err());
    }
}
