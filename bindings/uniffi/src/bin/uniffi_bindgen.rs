//! `uniffi-bindgen` CLI pinned to this crate's UniFFI version.
//!
//! `cargo run -p aiux-uniffi --features cli --bin uniffi-bindgen -- <args>`
//! keeps codegen tooling on the exact version recorded in bindings/README.md —
//! never a floating `cargo install`.

fn main() {
    uniffi::uniffi_bindgen_main();
}
