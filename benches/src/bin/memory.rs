//! Memory probe for long conversations (plan §22 — "memory after long
//! conversations"). Criterion measures time, not RSS; this binary reports
//! peak RSS (`VmHWM` from /proc) and serialized-size growth at increasing
//! conversation lengths so regressions are visible as one number.
//!
//!   cargo run -p aiux-benches --release --bin memory -- [turns...]
//!
//! `turns` = user+assistant exchanges (2 messages each). Default: 250 500 1250.

use aiux_benches::{batch_json, conversation_events};
use aiux_session::AiuxSession;

fn peak_rss_kib() -> Option<u64> {
    let status = std::fs::read_to_string("/proc/self/status").ok()?;
    status
        .lines()
        .find(|l| l.starts_with("VmHWM"))?
        .split_whitespace()
        .nth(1)?
        .parse()
        .ok()
}

fn main() {
    let turns: Vec<usize> = std::env::args()
        .skip(1)
        .map(|a| a.parse().expect("turn count"))
        .collect::<Vec<_>>();
    let turns = if turns.is_empty() {
        vec![250, 500, 1250]
    } else {
        turns
    };

    let baseline = peak_rss_kib().unwrap_or(0);
    println!(
        "{:>8} {:>10} {:>12} {:>14} {:>12}",
        "turns", "messages", "events", "serialized KiB", "peak Δ MiB"
    );

    for &t in &turns {
        let events = conversation_events(t);
        let batch = batch_json(&events);
        let mut session = AiuxSession::create("{}").unwrap();
        session.dispatch_batch(&batch).unwrap();
        let serialized = session.serialize().unwrap();
        let peak = peak_rss_kib().unwrap_or(0).saturating_sub(baseline);
        println!(
            "{:>8} {:>10} {:>12} {:>14} {:>12.1}",
            t,
            2 * t,
            events.len(),
            serialized.len() / 1024,
            peak as f64 / 1024.0,
        );
        // Keep sessions alive across iterations so growth is cumulative —
        // that's what a host holding N sessions actually pays.
        std::mem::forget(session);
    }
}
