import AIUXCore
import AIUXSwiftUI

// MARK: - UniFFI backend adapter
//
// `AIUXCore.AiuxSession` is the frozen UniFFI facade (core/rust/session): the
// same JSON-string surface as `AIUXSessionBackend`. This adapter is the only
// place the renderer meets the Rust core — the renderer package itself never
// depends on bindings.

/// `AiuxSession` adapted to the renderer's backend boundary.
public final class UniFFIBackend: AIUXSessionBackend {
    private let session: AiuxSession

    public init(session: AiuxSession) {
        self.session = session
    }

    /// `AiuxSession.create(configJson:)` — e.g. `{"sessionId": "demo"}`.
    public static func create(configJson: String) throws -> UniFFIBackend {
        UniFFIBackend(session: try AiuxSession.create(configJson: configJson))
    }

    /// `AiuxSession.restore(serializedJson:)` — replay a serialized session.
    public static func restore(serializedJson: String) throws -> UniFFIBackend {
        UniFFIBackend(session: try AiuxSession.restore(serializedJson: serializedJson))
    }

    public func dispatch(eventJson: String) throws -> String {
        try session.dispatch(eventJson: eventJson)
    }

    public func dispatchBatch(eventsJson: String) throws -> String {
        try session.dispatchBatch(eventsJson: eventsJson)
    }

    public func snapshot() throws -> String {
        try session.snapshot()
    }

    public func serialize() throws -> String {
        try session.serialize()
    }

    public func reset() throws {
        session.reset()
    }
}
