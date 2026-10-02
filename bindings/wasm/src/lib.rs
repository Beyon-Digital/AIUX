//! aiux-wasm — WASM/JS binding crate for the AIUX Rust core.
//!
//! `wasm-bindgen` exports land in the web phase (docs/PLAN.md §12). The crate
//! is a workspace member from Phase 0 so CI exercises the target early.

/// Placeholder proving the crate compiles for both native and wasm targets.
pub fn placeholder() -> &'static str {
    env!("CARGO_PKG_VERSION")
}
