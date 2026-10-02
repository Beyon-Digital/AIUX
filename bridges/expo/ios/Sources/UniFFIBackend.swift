import Foundation

/// One-line adapter conforming the UniFFI `AiuxSession` to the renderer's
/// `AIUXSessionBackend` protocol (same shape as examples/ios-native — the
/// renderer deliberately never depends on the binding).
final class UniFFIBackend: AIUXSessionBackend {
    private let session: AiuxSession

    init(session: AiuxSession) {
        self.session = session
    }

    func dispatch(eventJson: String) throws -> String {
        try session.dispatch(eventJson: eventJson)
    }

    func dispatchBatch(eventsJson: String) throws -> String {
        try session.dispatchBatch(eventsJson: eventsJson)
    }

    func snapshot() throws -> String {
        try session.snapshot()
    }

    func serialize() throws -> String {
        try session.serialize()
    }

    func reset() throws {
        try session.reset()
    }
}
