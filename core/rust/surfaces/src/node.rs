//! AIUX Surface Schema v1 — semantic node model (plan §6, ADR 0006).
//!
//! A constrained semantic UI schema: a fixed primitive set and semantic layout
//! values only. No absolute positioning, pixel values, transforms, arbitrary
//! HTML, or executable payloads — surfaces are data, never code.

use std::collections::BTreeMap;

use schemars::JsonSchema;
use serde::{Deserialize, Serialize};
use serde_json::Value;

/// A semantic action emitted by interactive nodes (button, menu).
///
/// Payloads are data only (§23); the host resolves `id` through its own policy
/// before executing anything.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
pub struct Action {
    /// Semantic action identifier, e.g. `invoice.approve`.
    pub id: String,
    /// Arbitrary JSON payload carried to the host.
    #[serde(default, skip_serializing_if = "serde_json::Map::is_empty")]
    pub payload: serde_json::Map<String, Value>,
}

/// Semantic gap between children (`xs|sm|md|lg|xl`).
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum Gap {
    Xs,
    Sm,
    Md,
    Lg,
    Xl,
}

/// Semantic padding (`none|xs|sm|md|lg`).
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum Padding {
    None,
    Xs,
    Sm,
    Md,
    Lg,
}

/// Semantic corner radius (`sm|md|lg|full`).
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum Radius {
    Sm,
    Md,
    Lg,
    Full,
}

/// Cross-axis alignment within a container.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum Alignment {
    Start,
    Center,
    End,
    Stretch,
}

/// Main-axis distribution of children within a container.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum Distribution {
    Start,
    Center,
    End,
    SpaceBetween,
    SpaceAround,
    SpaceEvenly,
}

/// Semantic layout properties shared by every node. All values are semantic
/// tokens — never pixels, percentages, or absolute coordinates.
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(default)]
pub struct Layout {
    /// Gap between children.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gap: Option<Gap>,
    /// Inner padding.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub padding: Option<Padding>,
    /// Corner radius.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub radius: Option<Radius>,
    /// Cross-axis alignment.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub alignment: Option<Alignment>,
    /// Main-axis distribution.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub distribution: Option<Distribution>,
}

/// Stack direction.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum StackDirection {
    Vertical,
    Horizontal,
}

/// Semantic text variant.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum TextVariant {
    Body,
    Caption,
    Label,
    Emphasis,
    Strong,
    Muted,
}

/// Semantic tone for badges, statuses, and emphasis.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum Tone {
    Default,
    Accent,
    Muted,
    Success,
    Warning,
    Destructive,
}

/// Icon size (semantic, resolved by renderer theme).
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum IconSize {
    Sm,
    Md,
    Lg,
}

/// Button hierarchy variant.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum ButtonVariant {
    Primary,
    Secondary,
    Ghost,
    Destructive,
}

/// Input field type (semantic; renderers map to platform keyboards).
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum InputType {
    Text,
    Email,
    Number,
    Password,
    Url,
}

/// A key/value row for `keyValue` nodes.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
pub struct KeyValueItem {
    /// Item label.
    pub key: String,
    /// Item value (rendered as text).
    pub value: String,
}

/// A selectable option for `select` nodes.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
pub struct SelectOption {
    /// Option value submitted via action payloads.
    pub value: String,
    /// Option display label.
    pub label: String,
}

/// A `menu` entry.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
pub struct MenuItem {
    /// Item label.
    pub label: String,
    /// Action emitted when the item is chosen.
    pub action: Action,
    /// Optional leading icon.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
    /// Whether the item is disabled.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub disabled: bool,
}

/// AIUX Surface Schema v1 node. Serialized as `{"type": "<kind>", ...}`.
///
/// The primitive set is closed: `surface`, `card`, `stack`, `row`, `grid`,
/// `heading`, `text`, `markdown`, `code`, `icon`, `image`, `badge`, `divider`,
/// `spacer`, `keyValue`, `list`, `table`, `button`, `menu`, `progress`,
/// `status`, `input`, `textarea`, `select`, `checkbox`, `actions`.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum SurfaceNode {
    /// Root surface container. Only valid as the tree root.
    #[serde(rename = "surface")]
    Surface {
        /// Child nodes.
        #[serde(default)]
        children: Vec<SurfaceNode>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Grouped content container.
    #[serde(rename = "card")]
    Card {
        /// Child nodes.
        #[serde(default)]
        children: Vec<SurfaceNode>,
        /// Optional card title.
        #[serde(skip_serializing_if = "Option::is_none")]
        title: Option<String>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Vertical or horizontal stack.
    #[serde(rename = "stack")]
    Stack {
        /// Child nodes.
        #[serde(default)]
        children: Vec<SurfaceNode>,
        /// Stack direction (default vertical).
        #[serde(skip_serializing_if = "Option::is_none")]
        direction: Option<StackDirection>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Horizontal row (stack shorthand).
    #[serde(rename = "row")]
    Row {
        /// Child nodes.
        #[serde(default)]
        children: Vec<SurfaceNode>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Fixed-column grid.
    #[serde(rename = "grid")]
    Grid {
        /// Child nodes laid out into the grid.
        #[serde(default)]
        children: Vec<SurfaceNode>,
        /// Column count (≥ 1).
        columns: u32,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Section heading.
    #[serde(rename = "heading")]
    Heading {
        /// Heading text.
        text: String,
        /// Heading level 1–6 (default 1).
        #[serde(skip_serializing_if = "Option::is_none")]
        level: Option<u8>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Plain text.
    #[serde(rename = "text")]
    Text {
        /// Text content.
        text: String,
        /// Semantic variant.
        #[serde(skip_serializing_if = "Option::is_none")]
        variant: Option<TextVariant>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Markdown content.
    #[serde(rename = "markdown")]
    Markdown {
        /// Markdown source.
        markdown: String,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Code block.
    #[serde(rename = "code")]
    Code {
        /// Code source.
        code: String,
        /// Language hint for highlighting.
        #[serde(skip_serializing_if = "Option::is_none")]
        language: Option<String>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Named icon.
    #[serde(rename = "icon")]
    Icon {
        /// Semantic icon name (renderer-resolved).
        name: String,
        /// Semantic size.
        #[serde(skip_serializing_if = "Option::is_none")]
        size: Option<IconSize>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Image by URI.
    #[serde(rename = "image")]
    Image {
        /// Image URI (host-mediated resolution).
        src: String,
        /// Accessibility label.
        #[serde(skip_serializing_if = "Option::is_none")]
        alt: Option<String>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Small labelled indicator.
    #[serde(rename = "badge")]
    Badge {
        /// Badge text.
        text: String,
        /// Semantic tone.
        #[serde(skip_serializing_if = "Option::is_none")]
        tone: Option<Tone>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Visual separator.
    #[serde(rename = "divider")]
    Divider {
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Flexible whitespace.
    #[serde(rename = "spacer")]
    Spacer {
        /// Semantic size (default md).
        #[serde(skip_serializing_if = "Option::is_none")]
        size: Option<Gap>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Key/value pairs.
    #[serde(rename = "keyValue")]
    KeyValue {
        /// Rows.
        items: Vec<KeyValueItem>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Ordered or unordered list of nodes.
    #[serde(rename = "list")]
    List {
        /// List items.
        #[serde(default)]
        children: Vec<SurfaceNode>,
        /// Ordered (numbered) list when true.
        #[serde(default, skip_serializing_if = "std::ops::Not::not")]
        ordered: bool,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Semantic table.
    #[serde(rename = "table")]
    Table {
        /// Column headers.
        headers: Vec<String>,
        /// Rows; each row must match `headers` length.
        rows: Vec<Vec<String>>,
        /// Optional caption.
        #[serde(skip_serializing_if = "Option::is_none")]
        caption: Option<String>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Action button.
    #[serde(rename = "button")]
    Button {
        /// Button label.
        label: String,
        /// Action emitted on activation.
        action: Action,
        /// Hierarchy variant.
        #[serde(skip_serializing_if = "Option::is_none")]
        variant: Option<ButtonVariant>,
        /// Whether the button is disabled.
        #[serde(default, skip_serializing_if = "std::ops::Not::not")]
        disabled: bool,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Overflow/dropdown menu of actions.
    #[serde(rename = "menu")]
    Menu {
        /// Menu trigger label.
        #[serde(skip_serializing_if = "Option::is_none")]
        label: Option<String>,
        /// Menu entries.
        items: Vec<MenuItem>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Progress indicator.
    #[serde(rename = "progress")]
    Progress {
        /// Current value (omit for indeterminate).
        #[serde(skip_serializing_if = "Option::is_none")]
        value: Option<f64>,
        /// Maximum value (default 1.0 semantics are renderer-defined).
        #[serde(skip_serializing_if = "Option::is_none")]
        max: Option<f64>,
        /// Optional label.
        #[serde(skip_serializing_if = "Option::is_none")]
        label: Option<String>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Inline status line.
    #[serde(rename = "status")]
    Status {
        /// Status text.
        text: String,
        /// Semantic tone.
        #[serde(skip_serializing_if = "Option::is_none")]
        tone: Option<Tone>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Single-line input field.
    #[serde(rename = "input")]
    Input {
        /// Field name submitted in action payloads.
        name: String,
        /// Field label.
        #[serde(skip_serializing_if = "Option::is_none")]
        label: Option<String>,
        /// Placeholder text.
        #[serde(skip_serializing_if = "Option::is_none")]
        placeholder: Option<String>,
        /// Current value.
        #[serde(skip_serializing_if = "Option::is_none")]
        value: Option<String>,
        /// Semantic input type.
        #[serde(skip_serializing_if = "Option::is_none")]
        input_type: Option<InputType>,
        /// Whether input is required.
        #[serde(default, skip_serializing_if = "std::ops::Not::not")]
        required: bool,
        /// Whether input is disabled.
        #[serde(default, skip_serializing_if = "std::ops::Not::not")]
        disabled: bool,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Multi-line input field.
    #[serde(rename = "textarea")]
    Textarea {
        /// Field name submitted in action payloads.
        name: String,
        /// Field label.
        #[serde(skip_serializing_if = "Option::is_none")]
        label: Option<String>,
        /// Placeholder text.
        #[serde(skip_serializing_if = "Option::is_none")]
        placeholder: Option<String>,
        /// Current value.
        #[serde(skip_serializing_if = "Option::is_none")]
        value: Option<String>,
        /// Visible row hint.
        #[serde(skip_serializing_if = "Option::is_none")]
        rows: Option<u32>,
        /// Whether input is disabled.
        #[serde(default, skip_serializing_if = "std::ops::Not::not")]
        disabled: bool,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Single-choice dropdown.
    #[serde(rename = "select")]
    Select {
        /// Field name submitted in action payloads.
        name: String,
        /// Field label.
        #[serde(skip_serializing_if = "Option::is_none")]
        label: Option<String>,
        /// Options (must be non-empty).
        options: Vec<SelectOption>,
        /// Selected value.
        #[serde(skip_serializing_if = "Option::is_none")]
        value: Option<String>,
        /// Placeholder when no value is selected.
        #[serde(skip_serializing_if = "Option::is_none")]
        placeholder: Option<String>,
        /// Whether input is disabled.
        #[serde(default, skip_serializing_if = "std::ops::Not::not")]
        disabled: bool,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Boolean checkbox.
    #[serde(rename = "checkbox")]
    Checkbox {
        /// Field name submitted in action payloads.
        name: String,
        /// Checkbox label.
        label: String,
        /// Checked state.
        #[serde(default, skip_serializing_if = "std::ops::Not::not")]
        checked: bool,
        /// Whether input is disabled.
        #[serde(default, skip_serializing_if = "std::ops::Not::not")]
        disabled: bool,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
    /// Action row/container; children must be `button` or `menu` nodes.
    #[serde(rename = "actions")]
    Actions {
        /// Child nodes.
        #[serde(default)]
        children: Vec<SurfaceNode>,
        /// Layout properties.
        #[serde(flatten)]
        layout: Layout,
    },
}

impl SurfaceNode {
    /// Discriminant name as it appears on the wire.
    pub fn kind(&self) -> &'static str {
        match self {
            Self::Surface { .. } => "surface",
            Self::Card { .. } => "card",
            Self::Stack { .. } => "stack",
            Self::Row { .. } => "row",
            Self::Grid { .. } => "grid",
            Self::Heading { .. } => "heading",
            Self::Text { .. } => "text",
            Self::Markdown { .. } => "markdown",
            Self::Code { .. } => "code",
            Self::Icon { .. } => "icon",
            Self::Image { .. } => "image",
            Self::Badge { .. } => "badge",
            Self::Divider { .. } => "divider",
            Self::Spacer { .. } => "spacer",
            Self::KeyValue { .. } => "keyValue",
            Self::List { .. } => "list",
            Self::Table { .. } => "table",
            Self::Button { .. } => "button",
            Self::Menu { .. } => "menu",
            Self::Progress { .. } => "progress",
            Self::Status { .. } => "status",
            Self::Input { .. } => "input",
            Self::Textarea { .. } => "textarea",
            Self::Select { .. } => "select",
            Self::Checkbox { .. } => "checkbox",
            Self::Actions { .. } => "actions",
        }
    }

    /// Direct children of this node (empty for leaves).
    pub fn children(&self) -> &[SurfaceNode] {
        match self {
            Self::Surface { children, .. }
            | Self::Card { children, .. }
            | Self::Stack { children, .. }
            | Self::Row { children, .. }
            | Self::Grid { children, .. }
            | Self::List { children, .. }
            | Self::Actions { children, .. } => children,
            _ => &[],
        }
    }
}

/// A surface: a named, revisioned semantic node tree.
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema, PartialEq)]
pub struct SurfaceTree {
    /// Stable surface identifier.
    pub id: String,
    /// Optional human-facing name.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    /// Monotonic revision; bumps on every `surface.updated`.
    #[serde(default)]
    pub revision: u64,
    /// Root node — must be a `surface` node.
    pub root: SurfaceNode,
    /// Unknown fields preserved for forward compatibility.
    #[serde(flatten)]
    pub extra: BTreeMap<String, Value>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn node_round_trip() {
        let json = r#"{
            "type": "card",
            "padding": "md",
            "gap": "sm",
            "title": "Invoice",
            "children": [
                {"type": "heading", "text": "Invoice #293", "level": 2},
                {"type": "keyValue", "items": [{"key": "Total", "value": "$42"}]},
                {"type": "actions", "children": [
                    {"type": "button", "label": "Approve",
                     "action": {"id": "invoice.approve", "payload": {"invoiceId": "293"}}}
                ]}
            ]
        }"#;
        let node: SurfaceNode = serde_json::from_str(json).unwrap();
        assert_eq!(node.kind(), "card");
        assert_eq!(node.children().len(), 3);
        let out = serde_json::to_string(&node).unwrap();
        let reparsed: SurfaceNode = serde_json::from_str(&out).unwrap();
        assert_eq!(node, reparsed);
    }

    #[test]
    fn non_semantic_layout_rejected_by_types() {
        let json = r#"{"type": "stack", "gap": "13px", "children": []}"#;
        assert!(serde_json::from_str::<SurfaceNode>(json).is_err());
    }
}
