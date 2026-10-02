//! Surface Schema v1 validation (plan §6, §23).
//!
//! Two stages:
//! 1. `validate_raw` — walks the raw JSON before typed deserialization and
//!    rejects any key outside the closed schema (no absolute positioning,
//!    pixel values, transforms, or smuggled properties).
//! 2. `validate` — semantic rules on the typed tree (root must be `surface`,
//!    `actions` children are `button`/`menu`, field constraints, depth/size
//!    bounds).

use serde_json::Value;

use crate::node::{Action, MenuItem, SurfaceNode, SurfaceTree};

/// Maximum nesting depth of a surface tree.
pub const MAX_DEPTH: usize = 64;
/// Maximum total nodes in a surface tree.
pub const MAX_NODES: usize = 4096;

/// A surface validation failure. `detail` is human-readable and safe to
/// surface in logs/UI.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SurfaceError {
    /// Validation failure detail.
    pub detail: String,
}

impl SurfaceError {
    fn new(detail: impl Into<String>) -> Self {
        Self {
            detail: detail.into(),
        }
    }
}

impl std::fmt::Display for SurfaceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "invalid surface: {}", self.detail)
    }
}

impl std::error::Error for SurfaceError {}

/// Keys allowed on every node object regardless of `type`.
const COMMON_KEYS: &[&str] = &[
    "type",
    "gap",
    "padding",
    "radius",
    "alignment",
    "distribution",
];

/// Allowed keys per node `type` (in addition to COMMON_KEYS).
fn allowed_keys(kind: &str) -> Option<&'static [&'static str]> {
    Some(match kind {
        "surface" | "row" | "actions" => &["children"],
        "card" => &["children", "title"],
        "stack" => &["children", "direction"],
        "grid" => &["children", "columns"],
        "heading" => &["text", "level"],
        "text" => &["text", "variant"],
        "markdown" => &["markdown"],
        "code" => &["code", "language"],
        "icon" => &["name", "size"],
        "image" => &["src", "alt"],
        "badge" => &["text", "tone"],
        "divider" => &[],
        "spacer" => &["size"],
        "keyValue" => &["items"],
        "list" => &["children", "ordered"],
        "table" => &["headers", "rows", "caption"],
        "button" => &["label", "action", "variant", "disabled"],
        "menu" => &["label", "items"],
        "progress" => &["value", "max", "label"],
        "status" => &["text", "tone"],
        "input" => &[
            "name",
            "label",
            "placeholder",
            "value",
            "inputType",
            "required",
            "disabled",
        ],
        "textarea" => &["name", "label", "placeholder", "value", "rows", "disabled"],
        "select" => &[
            "name",
            "label",
            "options",
            "value",
            "placeholder",
            "disabled",
        ],
        "checkbox" => &["name", "label", "checked", "disabled"],
        _ => return None,
    })
}

/// Validate a raw surface-node JSON value before typed deserialization.
/// Rejects unknown node types and unknown keys (anything outside the schema).
pub fn validate_raw(value: &Value) -> Result<(), SurfaceError> {
    let mut count = 0usize;
    validate_raw_node(value, 0, &mut count)
}

fn validate_raw_node(value: &Value, depth: usize, count: &mut usize) -> Result<(), SurfaceError> {
    if depth > MAX_DEPTH {
        return Err(SurfaceError::new(format!("nesting exceeds {MAX_DEPTH}")));
    }
    *count += 1;
    if *count > MAX_NODES {
        return Err(SurfaceError::new(format!("more than {MAX_NODES} nodes")));
    }
    let obj = value
        .as_object()
        .ok_or_else(|| SurfaceError::new("node must be an object"))?;
    let kind = obj
        .get("type")
        .and_then(Value::as_str)
        .ok_or_else(|| SurfaceError::new("node missing \"type\""))?;
    let keys = allowed_keys(kind)
        .ok_or_else(|| SurfaceError::new(format!("unknown node type \"{kind}\"")))?;
    for key in obj.keys() {
        if COMMON_KEYS.contains(&key.as_str()) || keys.contains(&key.as_str()) {
            continue;
        }
        return Err(SurfaceError::new(format!(
            "key \"{key}\" not allowed on \"{kind}\" node"
        )));
    }
    if let Some(children) = obj.get("children") {
        let arr = children
            .as_array()
            .ok_or_else(|| SurfaceError::new("\"children\" must be an array"))?;
        for child in arr {
            validate_raw_node(child, depth + 1, count)?;
        }
    }
    // Nested action/object payloads are free-form data by design (§23).
    Ok(())
}

/// Validate a typed surface tree.
pub fn validate(tree: &SurfaceTree) -> Result<(), SurfaceError> {
    if tree.id.is_empty() {
        return Err(SurfaceError::new("surface id must be non-empty"));
    }
    if !matches!(tree.root, SurfaceNode::Surface { .. }) {
        return Err(SurfaceError::new("root node must be \"surface\""));
    }
    let mut count = 0usize;
    validate_node(&tree.root, 0, false, &mut count)
}

fn validate_node(
    node: &SurfaceNode,
    depth: usize,
    inside_actions: bool,
    count: &mut usize,
) -> Result<(), SurfaceError> {
    if depth > MAX_DEPTH {
        return Err(SurfaceError::new(format!("nesting exceeds {MAX_DEPTH}")));
    }
    *count += 1;
    if *count > MAX_NODES {
        return Err(SurfaceError::new(format!("more than {MAX_NODES} nodes")));
    }
    match node {
        SurfaceNode::Surface { .. } if depth > 0 => {
            return Err(SurfaceError::new("\"surface\" may only appear at the root"));
        }
        SurfaceNode::Grid { columns, .. } if *columns == 0 => {
            return Err(SurfaceError::new("grid columns must be >= 1"));
        }
        SurfaceNode::Heading { level, .. } if level.is_some_and(|l| !(1..=6).contains(&l)) => {
            return Err(SurfaceError::new("heading level must be 1..=6"));
        }
        SurfaceNode::Icon { name, .. } if name.is_empty() => {
            return Err(SurfaceError::new("icon name must be non-empty"));
        }
        SurfaceNode::Image { src, .. } if src.is_empty() => {
            return Err(SurfaceError::new("image src must be non-empty"));
        }
        SurfaceNode::KeyValue { items, .. } => {
            for item in items {
                if item.key.is_empty() {
                    return Err(SurfaceError::new("keyValue keys must be non-empty"));
                }
            }
        }
        SurfaceNode::Table { headers, rows, .. } => {
            for (i, row) in rows.iter().enumerate() {
                if row.len() != headers.len() {
                    return Err(SurfaceError::new(format!(
                        "table row {i} has {} cells for {} headers",
                        row.len(),
                        headers.len()
                    )));
                }
            }
        }
        SurfaceNode::Button { label, action, .. } => {
            if label.is_empty() {
                return Err(SurfaceError::new("button label must be non-empty"));
            }
            validate_action(action)?;
        }
        SurfaceNode::Menu { items, .. } => {
            if items.is_empty() {
                return Err(SurfaceError::new("menu items must be non-empty"));
            }
            for MenuItem { label, action, .. } in items {
                if label.is_empty() {
                    return Err(SurfaceError::new("menu item label must be non-empty"));
                }
                validate_action(action)?;
            }
        }
        SurfaceNode::Progress { value, max, .. } => {
            if let (Some(v), Some(m)) = (value, max) {
                if *m <= 0.0 {
                    return Err(SurfaceError::new("progress max must be > 0"));
                }
                if *v < 0.0 || *v > *m {
                    return Err(SurfaceError::new("progress value outside 0..=max"));
                }
            }
        }
        SurfaceNode::Input { name, .. }
        | SurfaceNode::Textarea { name, .. }
        | SurfaceNode::Select { name, .. }
        | SurfaceNode::Checkbox { name, .. }
            if name.is_empty() =>
        {
            return Err(SurfaceError::new(format!(
                "{} requires a non-empty name",
                node.kind()
            )));
        }
        SurfaceNode::Select { options, .. } => {
            if options.is_empty() {
                return Err(SurfaceError::new("select requires options"));
            }
            let mut seen = std::collections::BTreeSet::new();
            for opt in options {
                if !seen.insert(&opt.value) {
                    return Err(SurfaceError::new(format!(
                        "duplicate select option \"{}\"",
                        opt.value
                    )));
                }
            }
        }
        _ => {}
    }
    if inside_actions && !matches!(node, SurfaceNode::Button { .. } | SurfaceNode::Menu { .. }) {
        return Err(SurfaceError::new(
            "\"actions\" may only contain button/menu nodes",
        ));
    }
    let in_actions = matches!(node, SurfaceNode::Actions { .. }) || inside_actions;
    for child in node.children() {
        validate_node(child, depth + 1, in_actions, count)?;
    }
    Ok(())
}

fn validate_action(action: &Action) -> Result<(), SurfaceError> {
    if action.id.is_empty() {
        return Err(SurfaceError::new("action id must be non-empty"));
    }
    if action.id.contains(char::is_whitespace) {
        return Err(SurfaceError::new(format!(
            "action id \"{}\" must not contain whitespace",
            action.id
        )));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::node::SurfaceTree;

    fn parse(json: &str) -> SurfaceTree {
        serde_json::from_str(json).unwrap()
    }

    #[test]
    fn valid_surface_passes() {
        let tree = parse(
            r#"{"id":"s1","root":{"type":"surface","children":[
               {"type":"text","text":"hi"}]}}"#,
        );
        validate(&tree).unwrap();
    }

    #[test]
    fn non_surface_root_rejected() {
        let tree = parse(r#"{"id":"s1","root":{"type":"text","text":"hi"}}"#);
        assert!(validate(&tree).is_err());
    }

    #[test]
    fn raw_rejects_unknown_keys() {
        let json = serde_json::json!({
            "type": "card", "position": "absolute", "children": []
        });
        assert!(validate_raw(&json).is_err());
    }

    #[test]
    fn raw_rejects_unknown_node_type() {
        let json = serde_json::json!({"type": "webview", "src": "https://x"});
        assert!(validate_raw(&json).is_err());
    }

    #[test]
    fn actions_children_constrained() {
        let tree = parse(
            r#"{"id":"s1","root":{"type":"surface","children":[
               {"type":"actions","children":[{"type":"text","text":"x"}]}]}}"#,
        );
        assert!(validate(&tree).is_err());
    }

    #[test]
    fn table_row_width_enforced() {
        let tree = parse(
            r#"{"id":"s1","root":{"type":"surface","children":[
               {"type":"table","headers":["a","b"],"rows":[["1"]]}]}}"#,
        );
        assert!(validate(&tree).is_err());
    }

    #[test]
    fn whitespace_action_id_rejected() {
        let tree = parse(
            r#"{"id":"s1","root":{"type":"surface","children":[
               {"type":"button","label":"Go","action":{"id":"has space"}}]}}"#,
        );
        assert!(validate(&tree).is_err());
    }
}
