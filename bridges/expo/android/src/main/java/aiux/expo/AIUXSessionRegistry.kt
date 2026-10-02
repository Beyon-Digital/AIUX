package aiux.expo

import aiux.compose.AIUXSessionStore
import aiux.compose.model.AIUXDispatchReport
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.util.concurrent.ConcurrentHashMap

/**
 * SessionId → `AIUXSessionStore` registry shared by the module's session
 * functions and every `AIConversationView` instance. The store owns the
 * UniFFI `AiuxSession`; the boundary stays JSON throughout.
 */
internal object AIUXSessionRegistry {

    private val json = Json { ignoreUnknownKeys = true }
    private val stores = ConcurrentHashMap<String, AIUXSessionStore>()

    /** Returns the existing store or creates one bound to [sessionId]. */
    fun getOrCreate(sessionId: String): AIUXSessionStore =
        stores.getOrPut(sessionId) {
            AIUXSessionStore.create(
                """{"protocolVersion":"0.1","sessionId":"$sessionId"}""",
            )
        }

    fun create(sessionId: String) {
        getOrCreate(sessionId)
    }

    suspend fun dispatchBatch(
        sessionId: String,
        eventsJson: String,
    ): AIUXDispatchReport =
        getOrCreate(sessionId).dispatchBatch(eventsJson).getOrThrow()

    suspend fun serialize(sessionId: String): String =
        getOrCreate(sessionId).serialize().getOrThrow()

    suspend fun restore(serializedJson: String): String {
        val store = AIUXSessionStore.restore(serializedJson)
        val sessionId = json
            .parseToJsonElement(serializedJson)
            .jsonObject["sessionId"]
            ?.jsonPrimitive
            ?.content
            ?: error("serialized session is missing sessionId")
        stores[sessionId] = store
        return sessionId
    }

    fun reset(sessionId: String) {
        getOrCreate(sessionId).reset()
    }

    suspend fun snapshot(sessionId: String): String =
        getOrCreate(sessionId).snapshotJson().getOrThrow()
}
