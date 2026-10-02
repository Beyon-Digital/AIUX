//! Property tests (plan §18): determinism under arbitrary delivery order,
//! duplicate replay, chunked batching, and persistence round-trips.

mod common;

use aiux_session::AiuxSession;
use common::base_events;
use proptest::prelude::*;

/// Deterministic Fisher–Yates shuffle driven by a generated seed (an LCG is
/// enough — the seed itself is the proptest input).
fn shuffled(mut events: Vec<String>, seed: u64) -> Vec<String> {
    let mut state = seed | 1;
    for i in (1..events.len()).rev() {
        state = state
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        let j = (state >> 33) as usize % (i + 1);
        events.swap(i, j);
    }
    events
}

fn serialize_after(events: &[String]) -> String {
    let mut s = AiuxSession::create("{}").unwrap();
    for e in events {
        s.dispatch(e).unwrap();
    }
    s.serialize().unwrap()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(64))]

    /// Any delivery order of the same event set converges to byte-identical
    /// serialized state: the bounded reorder buffer normalizes arrival order.
    #[test]
    fn arbitrary_delivery_order_converges(seed in any::<u64>()) {
        let order = shuffled(base_events(), seed);
        let baseline = serialize_after(&base_events());
        prop_assert_eq!(serialize_after(&order), baseline);
    }

    /// Interleaving arbitrary duplicates of a subset never changes the
    /// outcome: replayed `eventId`s are absorbed by the idempotency ledger.
    #[test]
    fn duplicate_replay_is_inert(
        dup_mask in prop::collection::vec(any::<bool>(), 20),
        order_seed in any::<u64>(),
    ) {
        let mut events = Vec::new();
        for (i, e) in base_events().iter().enumerate() {
            events.push(e.clone());
            if dup_mask[i] {
                events.push(e.clone());
            }
        }
        let events = shuffled(events, order_seed);
        prop_assert_eq!(serialize_after(&events), serialize_after(&base_events()));
    }

    /// Splitting the stream into contiguous chunks dispatched via
    /// `dispatch_batch` is equivalent to dispatching events one by one.
    #[test]
    fn chunked_batching_is_equivalent(
        cuts in prop::collection::vec(0usize..=20, 1..=6),
    ) {
        let events = base_events();
        let mut seq_session = AiuxSession::create("{}").unwrap();
        for e in &events {
            seq_session.dispatch(e).unwrap();
        }

        let mut batch_session = AiuxSession::create("{}").unwrap();
        let mut idx = 0;
        let mut boundaries: Vec<usize> = cuts;
        boundaries.sort_unstable();
        boundaries.push(events.len());
        for &b in &boundaries {
            let b = b.min(events.len()).max(idx);
            if b > idx {
                let chunk = format!("[{}]", events[idx..b].join(","));
                batch_session.dispatch_batch(&chunk).unwrap();
                idx = b;
            }
        }
        prop_assert_eq!(
            batch_session.serialize().unwrap(),
            seq_session.serialize().unwrap()
        );
    }

    /// serialize → restore → serialize is the identity at any stream prefix.
    #[test]
    fn restore_roundtrips_at_any_prefix(prefix in 0usize..=20) {
        let events = base_events();
        let mut s = AiuxSession::create("{}").unwrap();
        for e in &events[..prefix] {
            s.dispatch(e).unwrap();
        }
        let saved = s.serialize().unwrap();
        let restored = AiuxSession::restore(&saved).unwrap();
        prop_assert_eq!(restored.serialize().unwrap(), saved);
    }
}
