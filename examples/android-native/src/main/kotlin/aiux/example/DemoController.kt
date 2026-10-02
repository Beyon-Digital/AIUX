package aiux.example

import aiux.compose.AIUXSessionStore
import aiux.compose.model.AIUXAction
import aiux.compose.model.AIUXActions
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

/**
 * Host-side driver for the mocked agent interaction (Phase 3 gate).
 * Receives AIUXAction from the UI, executes them, feeds protocol events
 * back into the session store — actions only flow upward (plan §23).
 */
class DemoController {
    val store = AIUXSessionStore.create("""{"sessionId":"s1"}""")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    // Keyed by approvalId so concurrent prompts resolve their own request —
    // a second prompt never strands the first one's approval card.
    private val pendingApprovals = mutableMapOf<String, CompletableDeferred<Boolean>>()
    private var activeRun: RunHandle? = null
    private var runJob: Job? = null
    private var messageN = 0
    private val agent = MockAgent() // single sequence space for the whole session

    private data class RunHandle(
        val runId: String,
        val messageId: String,
        val approvalId: String,
    )

    private val _fixture = MutableStateFlow<String?>(null)
    /** Non-null while a fixture is being browsed. */
    val fixture: StateFlow<String?> = _fixture

    init {
        scope.launch { store.dispatch(agent.sessionCreated("AIUX Compose demo")) }
    }

    private suspend fun send(eventJson: String) {
        store.dispatch(eventJson).onFailure {
            android.util.Log.e("AIUXDemo", "dispatch failed", it)
        }
    }

    fun onAction(action: AIUXAction) {
        when (action.id) {
            AIUXActions.COMPOSER_SEND -> {
                val text = action.payload["text"]?.jsonPrimitive?.content ?: return
                sendPrompt(text)
            }
            AIUXActions.COMPOSER_CANCEL -> {
                val run = activeRun ?: return
                pendingApprovals.remove(run.approvalId)?.cancel()
                runJob?.cancel()
                scope.launch {
                    send(agent.messageCancelled(run.messageId))
                    send(agent.runCancelled(run.runId))
                }
            }
            AIUXActions.APPROVAL_APPROVE, AIUXActions.APPROVAL_REJECT -> {
                val approvalId = action.payload["approvalId"]?.jsonPrimitive?.content ?: return
                pendingApprovals.remove(approvalId)
                    ?.complete(action.id == AIUXActions.APPROVAL_APPROVE)
            }
            else -> Unit // navigation actions (context.open, citation.open, …) no-op in the demo
        }
    }

    /** user prompt → stream → tool start → tool finish → approval → approve → render result */
    fun sendPrompt(text: String) {
        val messageId = "m${++messageN}"
        val runId = "r$messageN"
        val toolId = "t$messageN"
        val approvalId = "a$messageN"
        val surfaceId = "sf$messageN"
        val run = RunHandle(runId, messageId, approvalId)
        activeRun = run
        runJob = scope.launch {
            try {
                agent.userMessage("u$messageN", text).forEach { send(it) }
                send(agent.runStarted(runId))
                send(agent.assistantMessage(messageId))

                val scripted = "Searching the AIUX spec for invoice matches, drafting the result card…"
                send(agent.textPart(messageId, "p1"))
                for (word in scripted.split(" ")) {
                    delay(60)
                    send(agent.textDelta(messageId, "p1", "$word "))
                }
                send(agent.markdownPart(messageId, "p2", "**Found:** invoice `inv-9` for **$420.00** — publish requires approval."))

                send(agent.toolStarted(toolId, "search", buildJsonObject { put("q", "invoice inv-9") }))
                delay(400)
                send(agent.toolProgress(toolId, 1.0, 3.0, "querying"))
                delay(400)
                send(agent.toolProgress(toolId, 3.0, 3.0, "ranking"))
                delay(300)
                send(agent.toolCompleted(toolId, buildJsonObject {
                    put("hits", 2); put("top", "inv-9")
                }))
                send(agent.toolPart(messageId, "p3", toolId))

                send(agent.approvalRequested(approvalId, "Publish invoice INV-9?", "Charges $420.00 to Acme."))
                send(agent.approvalPart(messageId, "p4", approvalId))

                val approved = CompletableDeferred<Boolean>()
                    .also { pendingApprovals[approvalId] = it }
                    .await()
                send(agent.approvalResolved(approvalId, if (approved) "approved" else "rejected", "user"))
                if (approved) {
                    delay(250)
                    send(agent.approvalResolved(approvalId, "executed", "host"))
                    send(agent.resultSurface(surfaceId))
                    send(agent.surfacePart(messageId, "p5", surfaceId))
                    send(agent.textPart(messageId, "p6", "Done — INV-9 sent."))
                } else {
                    send(agent.textPart(messageId, "p5", "Cancelled — invoice was not published."))
                }
                send(agent.messageComplete(messageId))
                send(agent.runCompleted(runId))
            } finally {
                pendingApprovals.remove(approvalId)
                if (activeRun === run) activeRun = null
            }
        }
    }

    fun openFixture(name: String) { _fixture.value = name }
    fun closeFixture() { _fixture.value = null }

    fun close() { store.close() }
}
