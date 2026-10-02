//! aiux-surfaces — AIUX Surface Schema v1 (plan §6, ADR 0006).
//!
//! A constrained semantic UI schema: a closed set of primitives
//! (`surface` `card` `stack` `row` `grid` `heading` `text` `markdown` `code`
//! `icon` `image` `badge` `divider` `spacer` `keyValue` `list` `table`
//! `button` `menu` `progress` `status` `input` `textarea` `select` `checkbox`
//! `actions`) and semantic layout values only (`gap`, `padding`, `radius`,
//! `alignment`, `distribution`). Surfaces are data — validation rejects
//! anything outside the schema.

mod node;
mod validate;

pub use node::{
    Action, Alignment, ButtonVariant, Distribution, Gap, IconSize, InputType, KeyValueItem, Layout,
    MenuItem, Padding, Radius, SelectOption, StackDirection, SurfaceNode, SurfaceTree, TextVariant,
    Tone,
};
pub use validate::{validate, validate_raw, SurfaceError, MAX_DEPTH, MAX_NODES};
