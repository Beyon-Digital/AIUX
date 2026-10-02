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

use crate::node::{
    Action, MenuItem, SelectOption, SurfaceDescriptor, SurfaceNode, SurfaceTree, TableCell,
    TypedTableCell,
};

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
        "badge" => &["text", "tone", "icon"],
        "divider" => &[],
        "spacer" => &["size"],
        "keyValue" => &["items"],
        "list" => &["children", "ordered"],
        "listItem" => &["title", "subtitle", "icon", "action", "children"],
        "table" => &["headers", "columns", "rows", "caption"],
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
            "errorText",
        ],
        "textarea" => &[
            "name",
            "label",
            "placeholder",
            "value",
            "rows",
            "required",
            "disabled",
            "errorText",
        ],
        "select" => &[
            "name",
            "label",
            "options",
            "value",
            "placeholder",
            "required",
            "disabled",
            "errorText",
        ],
        "checkbox" => &[
            "name",
            "label",
            "checked",
            "required",
            "disabled",
            "errorText",
        ],
        "radio" => &[
            "name",
            "label",
            "options",
            "value",
            "required",
            "disabled",
            "errorText",
        ],
        "field" => &[
            "children",
            "label",
            "helperText",
            "required",
            "disabled",
            "errorText",
        ],
        "form" => &["children", "submit", "submitLabel", "disabled"],
        "custom" => &["kind", "props", "children"],
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
    // Free-form values (custom `props`, action payloads, table rows, …) are
    // data by design (§23) but still count against the surface budget —
    // otherwise a single `custom` node could carry an unbounded tree.
    for (key, val) in obj {
        if key == "children" || key == "type" {
            continue;
        }
        budget_json(val, depth, count)?;
    }
    if let Some(children) = obj.get("children") {
        let arr = children
            .as_array()
            .ok_or_else(|| SurfaceError::new("\"children\" must be an array"))?;
        for child in arr {
            validate_raw_node(child, depth + 1, count)?;
        }
    }
    Ok(())
}

/// Count an arbitrary JSON value against the same depth/size budget as
/// nodes, so free-form payloads can't smuggle unbounded data past
/// [`validate_raw`].
fn budget_json(value: &Value, depth: usize, count: &mut usize) -> Result<(), SurfaceError> {
    if depth > MAX_DEPTH {
        return Err(SurfaceError::new(format!("nesting exceeds {MAX_DEPTH}")));
    }
    *count += 1;
    if *count > MAX_NODES {
        return Err(SurfaceError::new(format!("more than {MAX_NODES} nodes")));
    }
    match value {
        Value::Array(items) => {
            for item in items {
                budget_json(item, depth + 1, count)?;
            }
        }
        Value::Object(map) => {
            for item in map.values() {
                budget_json(item, depth + 1, count)?;
            }
        }
        _ => {}
    }
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
    validate_node(&tree.root, 0, Ctx::ROOT, &mut count)
}

/// Validate an inline surface descriptor (`artifact.preview`/`.workspace`).
/// The descriptor's `root` must be a `surface` node and is held to the same
/// rules as a session surface's root (ADR 0007).
pub fn validate_descriptor(descriptor: &SurfaceDescriptor) -> Result<(), SurfaceError> {
    if descriptor.id.is_empty() {
        return Err(SurfaceError::new("surface descriptor id must be non-empty"));
    }
    if !matches!(descriptor.root, SurfaceNode::Surface { .. }) {
        return Err(SurfaceError::new(
            "surface descriptor root node must be \"surface\"",
        ));
    }
    let mut count = 0usize;
    validate_node(&descriptor.root, 0, Ctx::ROOT, &mut count)
}

/// Per-node validation context carried down the tree.
#[derive(Debug, Clone, Copy)]
struct Ctx {
    /// Inside an `actions` container (children constrained to button/menu).
    inside_actions: bool,
    /// Inside a `form` (forms may not nest).
    inside_form: bool,
    /// Direct child of a `list` (the only position a `listItem` may occupy).
    parent_is_list: bool,
}

impl Ctx {
    const ROOT: Self = Self {
        inside_actions: false,
        inside_form: false,
        parent_is_list: false,
    };
}

fn validate_node(
    node: &SurfaceNode,
    depth: usize,
    ctx: Ctx,
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
        SurfaceNode::Table {
            headers,
            columns,
            rows,
            ..
        } => {
            let effective = if !headers.is_empty() {
                headers.len()
            } else {
                columns.len()
            };
            if effective == 0 {
                return Err(SurfaceError::new("table requires headers or columns"));
            }
            if !headers.is_empty() && !columns.is_empty() && headers.len() != columns.len() {
                return Err(SurfaceError::new(
                    "table headers and columns must agree in length",
                ));
            }
            let mut keys = std::collections::BTreeSet::new();
            for col in columns {
                if col.key.is_empty() {
                    return Err(SurfaceError::new("table column keys must be non-empty"));
                }
                if !keys.insert(&col.key) {
                    return Err(SurfaceError::new(format!(
                        "duplicate table column key \"{}\"",
                        col.key
                    )));
                }
            }
            for (i, row) in rows.iter().enumerate() {
                if row.len() != effective {
                    return Err(SurfaceError::new(format!(
                        "table row {i} has {} cells for {} columns",
                        row.len(),
                        effective
                    )));
                }
                for cell in row {
                    if let TableCell::Typed(TypedTableCell::Action { label, action }) = cell {
                        if label.is_empty() {
                            return Err(SurfaceError::new(
                                "table action cell label must be non-empty",
                            ));
                        }
                        validate_action(action)?;
                    }
                }
            }
        }
        SurfaceNode::Field { children, .. } if children.is_empty() => {
            return Err(SurfaceError::new("field requires children"));
        }
        SurfaceNode::Form { submit, .. } => {
            if ctx.inside_form {
                return Err(SurfaceError::new("form may not nest inside form"));
            }
            validate_action(submit)?;
        }
        SurfaceNode::Radio {
            name,
            options,
            value,
            ..
        } => {
            if name.is_empty() {
                return Err(SurfaceError::new("radio requires a non-empty name"));
            }
            validate_options(options, "radio")?;
            if let Some(v) = value {
                if !options.iter().any(|o| &o.value == v) {
                    return Err(SurfaceError::new(format!(
                        "radio value \"{v}\" is not one of its options"
                    )));
                }
            }
        }
        SurfaceNode::ListItem { title, action, .. } => {
            if !ctx.parent_is_list {
                return Err(SurfaceError::new(
                    "listItem may only appear as a direct child of list",
                ));
            }
            if title.is_empty() {
                return Err(SurfaceError::new("listItem title must be non-empty"));
            }
            if let Some(action) = action {
                validate_action(action)?;
            }
        }
        SurfaceNode::Custom { kind, props, .. } => {
            if kind.is_empty() {
                return Err(SurfaceError::new("custom node kind must be non-empty"));
            }
            if kind.contains(char::is_whitespace) {
                return Err(SurfaceError::new(format!(
                    "custom node kind \"{kind}\" must not contain whitespace"
                )));
            }
            if kind.starts_with("aiux.") {
                return Err(SurfaceError::new(format!(
                    "custom node kind \"{kind}\" uses the reserved aiux.* prefix"
                )));
            }
            // `props` is free-form data but not free of the surface budget.
            *count += 1;
            if *count > MAX_NODES {
                return Err(SurfaceError::new(format!("more than {MAX_NODES} nodes")));
            }
            for value in props.values() {
                budget_json(value, depth + 1, count)?;
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
        SurfaceNode::Select { options, .. } => validate_options(options, "select")?,
        _ => {}
    }
    if ctx.inside_actions && !matches!(node, SurfaceNode::Button { .. } | SurfaceNode::Menu { .. })
    {
        return Err(SurfaceError::new(
            "\"actions\" may only contain button/menu nodes",
        ));
    }
    let child_ctx = Ctx {
        inside_actions: matches!(node, SurfaceNode::Actions { .. }) || ctx.inside_actions,
        inside_form: matches!(node, SurfaceNode::Form { .. }) || ctx.inside_form,
        parent_is_list: matches!(node, SurfaceNode::List { .. }),
    };
    for child in node.children() {
        validate_node(child, depth + 1, child_ctx, count)?;
    }
    Ok(())
}

fn validate_options(options: &[SelectOption], kind: &str) -> Result<(), SurfaceError> {
    if options.is_empty() {
        return Err(SurfaceError::new(format!("{kind} requires options")));
    }
    let mut seen = std::collections::BTreeSet::new();
    for opt in options {
        if !seen.insert(&opt.value) {
            return Err(SurfaceError::new(format!(
                "duplicate {kind} option \"{}\"",
                opt.value
            )));
        }
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

    #[test]
    fn raw_rejects_deep_custom_props() {
        // props nesting deeper than MAX_DEPTH inside a single custom node.
        let mut props = serde_json::json!("leaf");
        for _ in 0..=MAX_DEPTH {
            props = serde_json::json!({"k": props});
        }
        let json = serde_json::json!({
            "type": "custom", "kind": "acme.widget", "props": props
        });
        assert!(validate_raw(&json).is_err());
    }

    #[test]
    fn raw_rejects_oversized_custom_props() {
        let props: serde_json::Map<String, Value> = (0..MAX_NODES)
            .map(|i| (format!("k{i}"), serde_json::json!(i)))
            .collect();
        let json = serde_json::json!({
            "type": "custom", "kind": "acme.widget", "props": props
        });
        assert!(validate_raw(&json).is_err());
    }

    #[test]
    fn raw_rejects_deep_action_payload() {
        let mut payload = serde_json::json!("leaf");
        for _ in 0..=MAX_DEPTH {
            payload = serde_json::json!({"k": payload});
        }
        let json = serde_json::json!({
            "type": "button", "label": "Go",
            "action": {"id": "a1", "payload": payload}
        });
        assert!(validate_raw(&json).is_err());
    }

    #[test]
    fn typed_validate_rejects_deep_custom_props() {
        let mut inner = serde_json::json!("leaf");
        for _ in 0..=MAX_DEPTH {
            inner = serde_json::json!({"k": inner});
        }
        let tree = parse(
            &serde_json::json!({
                "id": "s1",
                "root": {"type": "surface", "children": [
                    {"type": "custom", "kind": "acme.widget", "props": {"k": inner}}
                ]}
            })
            .to_string(),
        );
        assert!(validate(&tree).is_err());
    }

    #[test]
    fn reasonable_custom_props_pass() {
        let tree = parse(
            r#"{"id":"s1","root":{"type":"surface","children":[
               {"type":"custom","kind":"acme.sparkline",
                "props":{"values":[1,2,3],"color":"blue"}}]}}"#,
        );
        validate(&tree).unwrap();
    }
}
