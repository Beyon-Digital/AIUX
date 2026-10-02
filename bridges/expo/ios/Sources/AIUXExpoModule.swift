import ExpoModulesCore

/// The AIUX Expo module — one coarse boundary (plan §10, ADR 0002).
///
/// JS-facing surface: session lifecycle (`createSession`/`dispatchBatch`/
/// `serialize`/`restore`/`reset`/`snapshot`) plus the `AIConversation` native
/// view that hosts the SwiftUI renderer and its `AiuxSession` registry.
public class AIUXExpoModule: Module {

    public func definition() -> ModuleDefinition {
        Name("AIUX")

        Function("isNativeReady") { true }

        AsyncFunction("createSession") { (sessionId: String, _: String) in
            await AIUXSessionRegistry.shared.create(sessionId: sessionId)
        }

        AsyncFunction("dispatchBatch") { (sessionId: String, eventsJson: String) in
            let report = try await AIUXSessionRegistry.shared.dispatchBatch(
                sessionId: sessionId, eventsJson: eventsJson
            )
            return [
                "applied": report.applied,
                "duplicatesIgnored": report.duplicatesIgnored,
                "buffered": report.buffered,
            ]
        }

        AsyncFunction("serialize") { (sessionId: String) in
            try await AIUXSessionRegistry.shared.serialize(sessionId: sessionId)
        }

        AsyncFunction("restore") { (serializedJson: String) in
            try await AIUXSessionRegistry.shared.restore(serializedJson: serializedJson)
        }

        AsyncFunction("reset") { (sessionId: String) in
            await AIUXSessionRegistry.shared.reset(sessionId: sessionId)
        }

        AsyncFunction("snapshot") { (sessionId: String) in
            try await AIUXSessionRegistry.shared.snapshotJson(sessionId: sessionId)
        }

        View(AIConversationView.self) {
            Prop("sessionId") { (view: AIConversationView, sessionId: String) in
                view.setSessionId(sessionId)
            }
            Prop("theme") { (view: AIConversationView, theme: String) in
                view.setThemeJson(theme)
            }
            Prop("mode") { (view: AIConversationView, mode: String) in
                view.setMode(mode)
            }
            Prop("showComposer") { (view: AIConversationView, show: Bool) in
                view.setShowComposer(show)
            }
            Events("onAction", "onError", "onSnapshot")
        }
    }
}
