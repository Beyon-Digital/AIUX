package aiux.expo

import aiux.compose.AIUXSessionStore
import aiux.compose.model.AIUXDispatchReport
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
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

    /**
     * Bumped by `restore` so mounted views re-resolve the store for an id —
     * otherwise `remember(id)` keeps the pre-restore store forever and
     * mounted conversations never show the restored session's events.
     */
    private val generations = ConcurrentHashMap<String, MutableStateFlow<Long>>()

    fun generationFlow(sessionId: String): StateFlow<Long> =
        generations.getOrPut(sessionId) { MutableStateFlow(0L) }

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
        // Close the displaced store — it owns a coroutine scope + session
        // that would leak once rebound views drop their reference.
        // Ordering is the concurrency contract: the new store lands in the
        // map BEFORE the generation bump notifies collectors, so a rebinding
        // view always resolves the newest store. `.update` (not `.value += 1`)
        // keeps overlapping restores from coalescing a lost increment.
        stores.put(sessionId, store)?.close()
        generations.getOrPut(sessionId) { MutableStateFlow(0L) }.update { it + 1 }
        return sessionId
    }

    fun reset(sessionId: String) {
        getOrCreate(sessionId).reset()
    }

    suspend fun snapshot(sessionId: String): String =
        getOrCreate(sessionId).snapshotJson().getOrThrow()
}
