//! aiux-session — placeholder crate for the AIUX Rust core workspace.
//!
//! Implementation lands in Phase 1 (see docs/PLAN.md). This stub exists so the
//! Cargo workspace compiles on CI from Phase 0 onward.

/// Returns the crate's placeholder version string.
pub fn placeholder() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

#[cfg(test)]
mod smoke {
    #[test]
    fn placeholder_is_set() {
        assert_eq!(super::placeholder(), env!("CARGO_PKG_VERSION"));
    }
}
