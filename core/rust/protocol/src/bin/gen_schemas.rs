//! Generate Protocol v1 JSON schemas into `protocol/schemas/v1/` and the
//! manifest into `protocol/versions/v1.json`. Run from anywhere — paths are
//! resolved from `CARGO_MANIFEST_DIR`. Reproducibility is asserted by the
//! `committed_schemas_are_current` test.

use std::path::PathBuf;

fn main() {
    let manifest = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let root = manifest.join("../../..");
    let schema_dir = root
        .join("protocol/schemas")
        .join(aiux_protocol::schema_dir_name());
    let versions_dir = root.join("protocol/versions");
    match aiux_protocol::generate_schemas(&schema_dir, &versions_dir) {
        Ok(written) => {
            println!("wrote {} files:", written.len());
            for p in &written {
                println!("  {}", p.display());
            }
        }
        Err(e) => {
            eprintln!("schema generation failed: {e}");
            std::process::exit(1);
        }
    }
}
