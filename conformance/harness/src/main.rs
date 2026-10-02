//! aiux-conformance — conformance harness for the AIUX Rust core (plan §17).
//!
//! Usage:
//!   aiux-conformance verify <fixtures_dir> <expected_dir>
//!   aiux-conformance bless  <fixtures_dir> <expected_dir>
//!
//! `verify` replays every `*.json` fixture's `events` array through
//! [`AiuxSession`] in order and byte-compares `serialize()` output against
//! `expected/<name>.json`. It exits non-zero if any fixture fails to parse,
//! dispatch errors, or the serialized bytes differ — this is the Phase 1
//! gate wired into CI. `bless` (re)writes the expected files instead of
//! comparing; it is for authoring/regeneration, never for CI.

use std::fs;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use aiux_protocol::ConformanceFixture;
use aiux_session::AiuxSession;

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let [command, fixtures_dir, expected_dir] = args.as_slice() else {
        eprintln!("usage: aiux-conformance verify|bless <fixtures_dir> <expected_dir>");
        return ExitCode::from(2);
    };
    let mode = match command.as_str() {
        "verify" => Mode::Verify,
        "bless" => Mode::Bless,
        _ => {
            eprintln!("unknown command \"{command}\" (expected verify|bless)");
            return ExitCode::from(2);
        }
    };

    let mut fixture_files: Vec<PathBuf> = match fs::read_dir(fixtures_dir) {
        Ok(rd) => rd
            .filter_map(|e| e.ok().map(|e| e.path()))
            .filter(|p| p.extension().is_some_and(|ext| ext == "json"))
            .collect(),
        Err(e) => {
            eprintln!("cannot read fixtures dir \"{fixtures_dir}\": {e}");
            return ExitCode::from(2);
        }
    };
    fixture_files.sort();
    if fixture_files.is_empty() {
        eprintln!("no fixtures found in \"{fixtures_dir}\"");
        return ExitCode::from(2);
    }

    let mut failures = 0usize;
    for path in &fixture_files {
        match run_fixture(path, Path::new(expected_dir), mode) {
            Ok(report) => println!("{report}"),
            Err(e) => {
                failures += 1;
                println!("FAIL {} — {e}", path.display());
            }
        }
    }

    let total = fixture_files.len();
    match (mode, failures) {
        (Mode::Verify, 0) => {
            println!("conformance: {total}/{total} fixtures verified");
            ExitCode::SUCCESS
        }
        (Mode::Verify, n) => {
            println!("conformance: {n}/{total} fixtures FAILED");
            ExitCode::FAILURE
        }
        (Mode::Bless, n) => {
            println!("conformance: blessed {} fixtures ({n} failed)", total - n);
            if n == 0 {
                ExitCode::SUCCESS
            } else {
                ExitCode::FAILURE
            }
        }
    }
}

#[derive(Clone, Copy)]
enum Mode {
    Verify,
    Bless,
}

fn run_fixture(fixture_path: &Path, expected_dir: &Path, mode: Mode) -> Result<String, String> {
    let name = fixture_path
        .file_stem()
        .and_then(|s| s.to_str())
        .ok_or_else(|| format!("bad fixture name {}", fixture_path.display()))?;
    let source = fs::read_to_string(fixture_path).map_err(|e| format!("read fixture: {e}"))?;
    let fixture: ConformanceFixture =
        serde_json::from_str(&source).map_err(|e| format!("parse fixture: {e}"))?;
    if fixture.name != name {
        return Err(format!(
            "fixture name \"{}\" does not match file name \"{name}\"",
            fixture.name
        ));
    }
    aiux_protocol::check_protocol_version(&fixture.protocol_version).map_err(|e| format!("{e}"))?;

    let mut session = AiuxSession::create("{}").map_err(|e| format!("create: {e}"))?;
    for (i, event) in fixture.events.iter().enumerate() {
        let event_json =
            serde_json::to_string(event).map_err(|e| format!("event {i}: reserialize: {e}"))?;
        session
            .dispatch(&event_json)
            .map_err(|e| format!("event {i} ({}): {e}", event.event_id))?;
    }
    let serialized = session.serialize().map_err(|e| format!("serialize: {e}"))?;

    let expected_path = expected_dir.join(format!("{name}.json"));
    match mode {
        Mode::Bless => {
            fs::write(&expected_path, &serialized)
                .map_err(|e| format!("write {}: {e}", expected_path.display()))?;
            Ok(format!("BLESSED {name}"))
        }
        Mode::Verify => {
            let expected = fs::read_to_string(&expected_path)
                .map_err(|e| format!("read expected {}: {e}", expected_path.display()))?;
            if expected == serialized {
                Ok(format!("PASS {name}"))
            } else {
                Err(format!(
                    "serialized output differs from {}\n{}",
                    expected_path.display(),
                    first_diff(&expected, &serialized)
                ))
            }
        }
    }
}

/// Locate the first differing line between expected and actual output.
fn first_diff(expected: &str, actual: &str) -> String {
    for (i, (e, a)) in expected.lines().zip(actual.lines()).enumerate() {
        if e != a {
            return format!("line {}: expected `{e}` got `{a}`", i + 1);
        }
    }
    if expected.lines().count() != actual.lines().count() {
        return format!(
            "line count: expected {} got {}",
            expected.lines().count(),
            actual.lines().count()
        );
    }
    "outputs differ (no line-level diff found)".to_string()
}
