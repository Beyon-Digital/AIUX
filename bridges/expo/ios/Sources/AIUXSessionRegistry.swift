import Foundation

/// sessionId → `AIUXSessionStore` registry shared by the module's session
/// functions and every `AIConversationView`. The store owns the UniFFI
/// `AiuxSession` via `UniFFIBackend`; the boundary stays JSON throughout.
@MainActor
final class AIUXSessionRegistry {

    static let shared = AIUXSessionRegistry()

    private var stores: [String: AIUXSessionStore] = [:]

    /// Existing store, or one created bound to `sessionId`.
    func store(for sessionId: String) -> AIUXSessionStore {
        if let store = stores[sessionId] {
            return store
        }
        let config = """
            {"protocolVersion":"0.1","sessionId":"\(sessionId)"}
            """
        let session = try! AiuxSession.create(configJson: config)
        let store = AIUXSessionStore(backend: UniFFIBackend(session: session))
        stores[sessionId] = store
        return store
    }

    func create(sessionId: String) {
        _ = store(for: sessionId)
    }

    @discardableResult
    func dispatchBatch(sessionId: String, eventsJson: String) throws -> AIUXDispatchReport {
        try store(for: sessionId).ingest(eventsJson: eventsJson)
    }

    func serialize(sessionId: String) throws -> String {
        try store(for: sessionId).serializedSession()
    }

    @discardableResult
    func restore(serializedJson: String) throws -> String {
        let session = try AiuxSession.restore(serializedJson: serializedJson)
        let store = AIUXSessionStore(backend: UniFFIBackend(session: session))
        let sessionId = store.snapshot.sessionId
        stores[sessionId] = store
        return sessionId
    }

    func reset(sessionId: String) {
        store(for: sessionId).resetSession()
    }

    func snapshotJson(sessionId: String) throws -> String {
        try store(for: sessionId).backend.snapshot()
    }
}
