//! aiux-tools — tool invocation lifecycle (plan §3, §4).
//!
//! `running → completed | failed`, with `progress` updates while running.
//! Transitions outside the lifecycle are `ProtocolError::InvalidEvent` —
//! the core never silently accepts a corrupt tool sequence.

use aiux_protocol::{AiuxError, Progress, ProtocolError, Tool, ToolStatus};
use serde_json::Value;

fn invalid(detail: impl Into<String>) -> ProtocolError {
    ProtocolError::InvalidEvent {
        detail: detail.into(),
    }
}

/// `tool.started`: insert a new running tool. The tool id must be unknown.
pub fn started(tools: &mut dyn ToolStore, tool: Tool) -> Result<(), ProtocolError> {
    if tool.id.is_empty() {
        return Err(invalid("tool.started: tool id must be non-empty"));
    }
    if tools.contains(&tool.id) {
        return Err(invalid(format!(
            "tool.started: tool \"{}\" already exists",
            tool.id
        )));
    }
    let mut tool = tool;
    tool.status = ToolStatus::Running;
    tools.insert(tool);
    Ok(())
}

/// `tool.progress`: update progress on a running tool.
pub fn progress(
    tools: &mut dyn ToolStore,
    tool_id: &str,
    progress: Progress,
) -> Result<(), ProtocolError> {
    let tool = running(tools, tool_id, "tool.progress")?;
    tool.progress = Some(progress);
    Ok(())
}

/// `tool.completed`: finish a running tool successfully.
pub fn completed(
    tools: &mut dyn ToolStore,
    tool_id: &str,
    result: Option<Value>,
    completed_at: Option<String>,
) -> Result<(), ProtocolError> {
    let tool = running(tools, tool_id, "tool.completed")?;
    tool.status = ToolStatus::Completed;
    tool.result = result;
    if completed_at.is_some() {
        tool.completed_at = completed_at;
    }
    Ok(())
}

/// `tool.failed`: finish a running tool with an error.
pub fn failed(
    tools: &mut dyn ToolStore,
    tool_id: &str,
    error: AiuxError,
    completed_at: Option<String>,
) -> Result<(), ProtocolError> {
    let tool = running(tools, tool_id, "tool.failed")?;
    tool.status = ToolStatus::Failed;
    tool.error = Some(error);
    if completed_at.is_some() {
        tool.completed_at = completed_at;
    }
    Ok(())
}

fn running<'a>(
    tools: &'a mut dyn ToolStore,
    tool_id: &str,
    event: &str,
) -> Result<&'a mut Tool, ProtocolError> {
    let tool = tools
        .get_mut(tool_id)
        .ok_or_else(|| invalid(format!("{event}: unknown tool \"{tool_id}\"")))?;
    match tool.status {
        ToolStatus::Running => Ok(tool),
        other => Err(invalid(format!(
            "{event}: tool \"{tool_id}\" already {other:?}"
        ))),
    }
}

/// Minimal store abstraction so lifecycle functions stay crate-local and the
/// reducer supplies its own ordered store.
pub trait ToolStore {
    /// Whether a tool id exists.
    fn contains(&self, id: &str) -> bool;
    /// Mutable access by id.
    fn get_mut(&mut self, id: &str) -> Option<&mut Tool>;
    /// Insert a tool.
    fn insert(&mut self, tool: Tool);
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeMap;

    struct Map(BTreeMap<String, Tool>);
    impl ToolStore for Map {
        fn contains(&self, id: &str) -> bool {
            self.0.contains_key(id)
        }
        fn get_mut(&mut self, id: &str) -> Option<&mut Tool> {
            self.0.get_mut(id)
        }
        fn insert(&mut self, tool: Tool) {
            self.0.insert(tool.id.clone(), tool);
        }
    }

    fn tool(id: &str) -> Tool {
        Tool {
            id: id.to_string(),
            name: "search".to_string(),
            status: ToolStatus::Running,
            input: None,
            progress: None,
            result: None,
            error: None,
            started_at: None,
            completed_at: None,
            extra: Default::default(),
        }
    }

    #[test]
    fn happy_path() {
        let mut store = Map(BTreeMap::new());
        started(&mut store, tool("t1")).unwrap();
        progress(&mut store, "t1", Progress::default()).unwrap();
        completed(&mut store, "t1", None, None).unwrap();
        assert!(matches!(store.0["t1"].status, ToolStatus::Completed));
        assert!(progress(&mut store, "t1", Progress::default()).is_err());
    }

    #[test]
    fn rejects_unknown_and_duplicates() {
        let mut store = Map(BTreeMap::new());
        assert!(progress(&mut store, "ghost", Progress::default()).is_err());
        started(&mut store, tool("t1")).unwrap();
        assert!(started(&mut store, tool("t1")).is_err());
    }
}
