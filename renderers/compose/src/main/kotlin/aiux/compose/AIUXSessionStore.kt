package aiux.compose

import aiux.AiuxSession
import aiux.compose.model.AIUXDispatchReport
import aiux.compose.model.AIUXError
import aiux.compose.model.AIUXModelParser
import aiux.compose.model.AIUXSnapshot
import java.io.Closeable
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Snapshot-observing holder over the UniFFI Kotlin `AiuxSession` binding
 * (plan §9 "session driver"). Composables stay logic-free: they collect
 * [snapshot] and report intents upward through `(AIUXAction) -> Unit`.
 *
 * All FFI calls run on [ioDispatcher]; the session itself serializes access
 * with a lock in Rust, and [dispatchMutex] keeps ordering deterministic for
 * concurrent Kotlin callers (streaming deltas must not interleave with a
 * host-side event).
 */
class AIUXSessionStore private constructor(
    private val session: AiuxSession,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
) : Closeable {

    private val dispatchMutex = Mutex()

    private val _snapshotJson = MutableStateFlow(session.snapshot())

    /** Canonical render snapshot as raw JSON, kept verbatim from the FFI. */
    val snapshotJson: StateFlow<String> = _snapshotJson.asStateFlow()

    private val _snapshot = MutableStateFlow(
        AIUXModelParser.parseSnapshot(_snapshotJson.value),
    )
    val snapshot: StateFlow<AIUXSnapshot> = _snapshot.asStateFlow()

    private val _lastError = MutableStateFlow<AIUXError?>(null)
    val lastError: StateFlow<AIUXError?> = _lastError.asStateFlow()

    private val _lastReport = MutableStateFlow(AIUXDispatchReport())
    val lastReport: StateFlow<AIUXDispatchReport> = _lastReport.asStateFlow()

    /** Reduce one event; refreshes [snapshot]. */
    suspend fun dispatch(eventJson: String): Result<AIUXDispatchReport> =
        dispatchMutex.withLock { runFfi { session.dispatch(eventJson) } }

    /** Reduce an ordered JSON array of events in one FFI call (plan §22). */
    suspend fun dispatchBatch(eventsJson: String): Result<AIUXDispatchReport> =
        dispatchMutex.withLock { runFfi { session.dispatchBatch(eventsJson) } }

    /** Fire-and-forget variant for UI callers. */
    fun dispatchBatchAsync(eventsJson: String) {
        scope.launch { dispatchBatch(eventsJson) }
    }

    fun dispatchAsync(eventJson: String) {
        scope.launch { dispatch(eventJson) }
    }

    /** Current serialized session (persistence/replay). */
    suspend fun serialize(): Result<String> = withContext(ioDispatcher) {
        runCatching { session.serialize() }.mapError()
    }

    /** Canonical render snapshot as raw JSON (verbatim across the boundary). */
    suspend fun snapshotJson(): Result<String> = withContext(ioDispatcher) {
        runCatching { session.snapshot() }.mapError()
    }

    /**
     * Clear session state. Serialized behind any in-flight dispatch on
     * [dispatchMutex] so a pending batch can neither publish a pre-reset
     * snapshot nor apply after the reset.
     */
    fun reset() {
        scope.launch {
            dispatchMutex.withLock {
                withContext(ioDispatcher) { runCatching { session.reset() } }
                refresh()
            }
        }
    }

    fun refresh() {
        _snapshot.value = runCatching { readSnapshot() }.getOrElse { e ->
            _lastError.value = AIUXError(code = "internal", message = "snapshot failed: ${e.message}")
            _snapshot.value
        }
    }

    override fun close() {
        scope.cancel()
        session.close()
    }

    private fun readSnapshot(): AIUXSnapshot {
        val raw = session.snapshot()
        _snapshotJson.value = raw
        return AIUXModelParser.parseSnapshot(raw)
    }

    private suspend fun runFfi(call: () -> String): Result<AIUXDispatchReport> =
        withContext(ioDispatcher) {
            runCatching { AIUXModelParser.parseDispatchReport(call()) }
                .mapError()
                .onSuccess { _lastReport.value = it }
                // Refresh on failure too: a rejected batch may still have
                // applied earlier events in the core.
                .also { refresh() }
        }

    private fun <T> Result<T>.mapError(): Result<T> = onFailure { e ->
        _lastError.value = AIUXError(
            code = e::class.simpleName ?: "AiuxError",
            message = e.message ?: "unknown FFI error",
        )
    }

    companion object {
        /** Create a session from a JSON config payload. */
        fun create(
            configJson: String = """{"sessionId":"s1"}""",
            ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
        ): AIUXSessionStore =
            AIUXSessionStore(AiuxSession.create(configJson), ioDispatcher)

        /** Restore a session from a `serialize()` payload. */
        fun restore(
            serializedJson: String,
            ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
        ): AIUXSessionStore =
            AIUXSessionStore(AiuxSession.restore(serializedJson), ioDispatcher)
    }
}
