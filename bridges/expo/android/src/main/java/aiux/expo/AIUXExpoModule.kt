package aiux.expo

import expo.modules.kotlin.functions.Coroutine
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

/**
 * The AIUX Expo module — one coarse boundary (plan §10, ADR 0002).
 *
 * JS-facing surface: session lifecycle (`createSession`/`dispatchBatch`/
 * `serialize`/`restore`/`reset`/`snapshot`) plus the `AIConversation` native
 * view that hosts the Compose renderer and its `AiuxSession` registry.
 */
class AIUXExpoModule : Module() {

    override fun definition() = ModuleDefinition {
        Name("AIUX")

        Function("isNativeReady") { true }

        AsyncFunction("createSession").Coroutine { sessionId: String, _: String ->
            AIUXSessionRegistry.create(sessionId)
        }

        AsyncFunction("dispatchBatch").Coroutine { sessionId: String, eventsJson: String ->
            val report = AIUXSessionRegistry.dispatchBatch(sessionId, eventsJson)
            mapOf(
                "applied" to report.applied,
                "duplicatesIgnored" to report.duplicatesIgnored,
                "buffered" to report.buffered,
            )
        }

        AsyncFunction("serialize").Coroutine { sessionId: String ->
            AIUXSessionRegistry.serialize(sessionId)
        }

        AsyncFunction("restore").Coroutine { serializedJson: String ->
            AIUXSessionRegistry.restore(serializedJson)
        }

        AsyncFunction("reset").Coroutine { sessionId: String ->
            AIUXSessionRegistry.reset(sessionId)
        }

        AsyncFunction("snapshot").Coroutine { sessionId: String ->
            AIUXSessionRegistry.snapshot(sessionId)
        }

        View(AIConversationView::class) {
            Prop("sessionId") { view: AIConversationView, sessionId: String ->
                view.applySessionId(sessionId)
            }
            Prop("theme") { view: AIConversationView, theme: String ->
                view.applyThemeJson(theme)
            }
            Prop("mode") { view: AIConversationView, mode: String ->
                view.applyMode(mode)
            }
            Prop("showComposer") { view: AIConversationView, show: Boolean ->
                view.applyShowComposer(show)
            }
            Prop("composerToolbar") { view: AIConversationView, toolbar: String ->
                view.applyComposerToolbarJson(toolbar)
            }
            Events("onAction", "onError", "onSnapshot")
        }
    }
}
