//! Protocol v1 JSON Schema generation (plan §3, §21).
//!
//! `generate_schemas` renders every core entity and event-payload schema via
//! `schemars` into `protocol/schemas/v1/`, plus the `protocol/versions/v1.json`
//! manifest. Output is canonical (recursively sorted keys, 2-space indent) so
//! generation is byte-reproducible — `cargo test -p aiux-protocol` asserts the
//! committed files are current.

use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use schemars::{schema_for, JsonSchema};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::entities::{
    Action, AiuxError, Approval, Artifact, Attachment, Capability, Citation, ContextEntity,
    Message, Part, Session, Surface, Tool,
};
use crate::events::{
    AiuxEvent, ApprovalRequested, ApprovalResolved, ArtifactCreated, ArtifactUpdated, EventType,
    MessageCreated, MessageUpdated, PartAdded, PartUpdated, RunCancelled, RunCompleted, RunFailed,
    RunStarted, SessionCreated, SurfaceCreated, SurfaceUpdated, TextDelta, ToolCompleted,
    ToolFailed, ToolProgress, ToolStarted,
};
use crate::{DispatchReport, ProtocolError, PROTOCOL_VERSION};

/// Directory name (under `protocol/schemas/`) this build generates.
pub const fn schema_dir_name() -> &'static str {
    "v1"
}

/// Canonical conformance fixture format: `{name, protocolVersion, events}`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ConformanceFixture {
    /// Fixture name.
    pub name: String,
    /// Protocol version the fixture targets.
    pub protocol_version: String,
    /// Ordered event list replayed through `AiuxSession`.
    pub events: Vec<AiuxEvent>,
}

/// Serialize to canonical JSON: recursively key-sorted, 2-space indent,
/// trailing newline. Byte-identical for identical inputs.
pub fn canonical_json<T: Serialize>(value: &T) -> Result<String, crate::ProtocolError> {
    let v = serde_json::to_value(value).map_err(|e| crate::ProtocolError::InvalidEvent {
        detail: format!("canonicalize: {e}"),
    })?;
    let mut s =
        serde_json::to_string_pretty(&v).map_err(|e| crate::ProtocolError::InvalidEvent {
            detail: format!("canonicalize: {e}"),
        })?;
    s.push('\n');
    Ok(s)
}

fn write(dir: &Path, name: &str, value: &Value) -> io::Result<PathBuf> {
    let pretty = serde_json::to_string_pretty(value)?;
    let path = dir.join(name);
    fs::write(&path, format!("{pretty}\n"))?;
    Ok(path)
}

fn emit<T: JsonSchema>(dir: &Path, name: &str) -> io::Result<PathBuf> {
    let schema = serde_json::to_value(schema_for!(T))?;
    write(dir, name, &schema)
}

/// Render all Protocol v1 schemas + the versions manifest under `out_dir`
/// (typically `protocol/schemas/v1/`; the manifest lands in
/// `protocol/versions/v1.json` — pass that dir separately).
pub fn generate_schemas(out_dir: &Path, versions_dir: &Path) -> io::Result<Vec<PathBuf>> {
    fs::create_dir_all(out_dir)?;
    fs::create_dir_all(versions_dir)?;
    let events_dir = out_dir.join("events");
    fs::create_dir_all(&events_dir)?;

    let mut written = Vec::new();

    macro_rules! entity {
        ($ty:ty, $file:literal) => {
            written.push(emit::<$ty>(out_dir, $file)?)
        };
    }
    entity!(Session, "session.json");
    entity!(Message, "message.json");
    entity!(Part, "part.json");
    entity!(Attachment, "attachment.json");
    entity!(Citation, "citation.json");
    entity!(ContextEntity, "contextEntity.json");
    entity!(Capability, "capability.json");
    entity!(Tool, "tool.json");
    entity!(Approval, "approval.json");
    entity!(Artifact, "artifact.json");
    entity!(Surface, "surface.json");
    entity!(Action, "action.json");
    entity!(AiuxError, "error.json");
    entity!(AiuxEvent, "event.json");
    entity!(ConformanceFixture, "fixture.json");
    entity!(DispatchReport, "dispatchReport.json");
    entity!(ProtocolError, "protocolError.json");

    macro_rules! event {
        ($payload:ty, $file:literal) => {
            written.push(emit::<AiuxEvent<$payload>>(&events_dir, $file)?)
        };
    }
    event!(SessionCreated, "session.created.json");
    event!(RunStarted, "run.started.json");
    event!(RunCancelled, "run.cancelled.json");
    event!(RunCompleted, "run.completed.json");
    event!(RunFailed, "run.failed.json");
    event!(MessageCreated, "message.created.json");
    event!(MessageUpdated, "message.updated.json");
    event!(PartAdded, "part.added.json");
    event!(PartUpdated, "part.updated.json");
    event!(TextDelta, "text.delta.json");
    event!(ToolStarted, "tool.started.json");
    event!(ToolProgress, "tool.progress.json");
    event!(ToolCompleted, "tool.completed.json");
    event!(ToolFailed, "tool.failed.json");
    event!(ApprovalRequested, "approval.requested.json");
    event!(ApprovalResolved, "approval.resolved.json");
    event!(ArtifactCreated, "artifact.created.json");
    event!(ArtifactUpdated, "artifact.updated.json");
    event!(SurfaceCreated, "surface.created.json");
    event!(SurfaceUpdated, "surface.updated.json");

    let manifest = serde_json::json!({
        "protocolVersion": PROTOCOL_VERSION,
        "schemaDir": format!("schemas/{}", schema_dir_name()),
        "schemaDraft": "http://json-schema.org/draft-07/schema#",
        "entities": [
            "session", "message", "part", "attachment", "citation",
            "contextEntity", "capability", "tool", "approval", "artifact",
            "surface", "action", "error", "event", "fixture",
            "dispatchReport", "protocolError",
        ],
        "eventTypes": EventType::ALL.iter().map(|t| t.as_str()).collect::<Vec<_>>(),
    });
    written.push(write(versions_dir, "v1.json", &manifest)?);

    Ok(written)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn repo_schema_dirs() -> (PathBuf, PathBuf) {
        let manifest = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let root = manifest.join("../../..");
        (
            root.join("protocol/schemas").join(schema_dir_name()),
            root.join("protocol/versions"),
        )
    }

    fn tree(dir: &Path) -> Vec<(String, String)> {
        let mut files = Vec::new();
        for entry in fs::read_dir(dir).unwrap() {
            let path = entry.unwrap().path();
            if path.is_dir() {
                for sub in fs::read_dir(&path).unwrap() {
                    let p = sub.unwrap().path();
                    files.push((
                        p.strip_prefix(dir).unwrap().to_string_lossy().into_owned(),
                        fs::read_to_string(&p).unwrap(),
                    ));
                }
            } else {
                files.push((
                    path.strip_prefix(dir)
                        .unwrap()
                        .to_string_lossy()
                        .into_owned(),
                    fs::read_to_string(&path).unwrap(),
                ));
            }
        }
        files.sort();
        files
    }

    /// Committed schemas must be byte-identical to a fresh generation — this
    /// is what makes schema generation reproducible in CI (plan §3/§19).
    #[test]
    fn committed_schemas_are_current() {
        let (schema_dir, versions_dir) = repo_schema_dirs();
        let tmp = std::env::temp_dir().join(format!("aiux-schemas-{}", std::process::id()));
        let _ = fs::remove_dir_all(&tmp);
        let tmp_schemas = tmp.join("schemas").join(schema_dir_name());
        let tmp_versions = tmp.join("versions");
        generate_schemas(&tmp_schemas, &tmp_versions).unwrap();

        let expected = tree(&tmp_schemas);
        let actual = tree(&schema_dir);
        assert_eq!(
            actual,
            expected,
            "protocol/schemas/{} is stale — run `cargo run -p aiux-protocol --bin gen-schemas`",
            schema_dir_name()
        );
        assert_eq!(
            fs::read_to_string(versions_dir.join("v1.json")).unwrap(),
            fs::read_to_string(tmp_versions.join("v1.json")).unwrap(),
            "protocol/versions/v1.json is stale"
        );
        let _ = fs::remove_dir_all(&tmp);
    }
}
