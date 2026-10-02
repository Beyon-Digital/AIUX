//! aiux-surfaces — AIUX Surface Schema v1 (plan §6, ADR 0006, ADR 0007).
//!
//! A constrained semantic UI schema: a closed set of primitives
//! (`surface` `card` `stack` `row` `grid` `heading` `text` `markdown` `code`
//! `icon` `image` `badge` `divider` `spacer` `keyValue` `list` `listItem`
//! `table` `button` `menu` `progress` `status` `input` `textarea` `select`
//! `checkbox` `radio` `field` `form` `actions` `custom`) and semantic layout
//! values only (`gap`, `padding`, `radius`, `alignment`, `distribution`).
//! Surfaces are data — validation rejects anything outside the schema.

mod node;
mod validate;

pub use node::{
    Action, Alignment, ArtifactPreview, ArtifactWorkspace, ButtonVariant, ColumnAlign, Distribution,
    Gap, IconSize, InputType, KeyValueItem, Layout, MenuItem, Padding, Radius, SelectOption,
    StackDirection, SurfaceDescriptor, SurfaceNode, SurfaceTree, TableCell, TableColumn,
    TextVariant, Tone, TypedTableCell, WorkspaceMode,
};
pub use validate::{
    validate, validate_descriptor, validate_raw, SurfaceError, MAX_DEPTH, MAX_NODES,
};
