import Combine
import Foundation

// MARK: - Session driver
//
// `AIUXSessionStore` owns the session backend, ingests event batches, and
// publishes decoded snapshots to the views. All session behavior (state
// machine, ordering, idempotency) lives in the Rust core — views hold no
// business logic.
//
// The backend is a narrow JSON-string protocol matching the frozen
// `AiuxSession` facade (core/rust/session, plan §4). The UniFFI `AiuxSession`
// binding (bindings/swift) conforms through a one-line adapter in the host
// app; fixture playback can drive the store with any conforming backend.

/// The JSON-in/JSON-out session boundary every backend implements.
/// Mirrors `AiuxSession` (UniFFI): `dispatch`, `dispatchBatch`, `snapshot`,
/// `serialize`, `reset`.
public protocol AIUXSessionBackend: AnyObject {
    /// Reduce one event (JSON envelope).
    func dispatch(eventJson: String) throws -> String
    /// Reduce an ordered JSON array of events in one call.
    func dispatchBatch(eventsJson: String) throws -> String
    /// Canonical-JSON render snapshot for the current state.
    func snapshot() throws -> String
    /// Canonical-JSON serialized session state.
    func serialize() throws -> String
    /// Clear all session state.
    func reset() throws
}

/// A backend's `dispatch`/`dispatchBatch` report.
public struct AIUXDispatchReport: Equatable, Decodable, Sendable {
    /// Events applied to state.
    public var applied: Int = 0
    /// Replays of already-seen event ids, safely ignored.
    public var duplicatesIgnored: Int = 0
    /// Out-of-order events parked pending missing sequences.
    public var buffered: Int = 0

    private enum CodingKeys: String, CodingKey {
        case applied, duplicatesIgnored, buffered
    }

    /// Missing counters decode as zero.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        applied = try c.decodeIfPresent(Int.self, forKey: .applied) ?? 0
        duplicatesIgnored = try c.decodeIfPresent(Int.self, forKey: .duplicatesIgnored) ?? 0
        buffered = try c.decodeIfPresent(Int.self, forKey: .buffered) ?? 0
    }
}

/// Errors surfaced by the store around backend or decode failures.
public enum AIUXStoreError: Error, Equatable {
    /// The backend call failed (`ProtocolError` at the FFI boundary).
    case backend(String)
    /// `snapshot()` returned JSON the renderer could not decode.
    case corruptSnapshot(String)
    /// `dispatch*` returned an unparseable report.
    case corruptReport(String)
}

/// The snapshot-observing session object every AIUX view binds to.
@MainActor
public final class AIUXSessionStore: ObservableObject {
    /// The latest decoded snapshot — published to all views.
    @Published public private(set) var renderModel: AIUXRenderModel
    /// The last backend/decode failure, kept for display. Views surface it;
    /// they never attempt recovery themselves.
    @Published public private(set) var lastError: AIUXStoreError?

    /// The session backend (UniFFI `AiuxSession` via adapter, or a
    /// fixture/test backend).
    public let backend: AIUXSessionBackend

    private let decoder = JSONDecoder()

    public init(backend: AIUXSessionBackend) {
        self.backend = backend
        renderModel = AIUXRenderModel(snapshot: AIUXSnapshot())
        lastError = nil
        refresh()
    }

    /// The current snapshot.
    public var snapshot: AIUXSnapshot { renderModel.snapshot }

    /// Pull `backend.snapshot()` into the published render model.
    public func refresh() {
        do {
            let json = try backend.snapshot()
            let decoded = try decoder.decode(AIUXSnapshot.self, from: Data(json.utf8))
            renderModel = AIUXRenderModel(snapshot: decoded)
        } catch {
            lastError = .corruptSnapshot(String(describing: error))
        }
    }

    /// Reduce one event and republish. Returns the dispatch report.
    @discardableResult
    public func ingest(eventJson: String) throws -> AIUXDispatchReport {
        let reportJson: String
        do {
            reportJson = try backend.dispatch(eventJson: eventJson)
        } catch {
            lastError = .backend(String(describing: error))
            throw error
        }
        return try ingestReport(reportJson: reportJson)
    }

    /// Reduce a batch of events and republish once (plan §22 — streaming
    /// deltas batch here). Returns the dispatch report.
    @discardableResult
    public func ingest(eventsJson: String) throws -> AIUXDispatchReport {
        let reportJson: String
        do {
            reportJson = try backend.dispatchBatch(eventsJson: eventsJson)
        } catch {
            lastError = .backend(String(describing: error))
            throw error
        }
        return try ingestReport(reportJson: reportJson)
    }

    /// Replay a conformance fixture (its `events` array) through the backend.
    @discardableResult
    public func ingest(fixture: AIUXFixture) throws -> AIUXDispatchReport {
        try ingest(eventsJson: fixture.eventsJSON())
    }

    /// Serialized session state for persistence/replay.
    public func serializedSession() throws -> String {
        do {
            return try backend.serialize()
        } catch {
            lastError = .backend(String(describing: error))
            throw error
        }
    }

    /// Clear the session and republish an empty snapshot.
    public func resetSession() {
        do {
            try backend.reset()
            lastError = nil
        } catch {
            lastError = .backend(String(describing: error))
        }
        refresh()
    }

    private func ingestReport(reportJson: String) throws -> AIUXDispatchReport {
        do {
            let report = try decoder.decode(AIUXDispatchReport.self, from: Data(reportJson.utf8))
            lastError = nil
            refresh()
            return report
        } catch {
            lastError = .corruptReport(String(describing: error))
            refresh()
            throw error
        }
    }
}
