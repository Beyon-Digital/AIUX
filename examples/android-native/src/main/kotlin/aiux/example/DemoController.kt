package aiux.example

import aiux.compose.AIUXSessionStore
import aiux.compose.model.AIUXAction
import aiux.compose.model.AIUXActions
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
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
    private var pendingApproval: CompletableDeferred<Boolean>? = null
    private var messageN = 0
    private val agent = MockAgent() // single sequence space for the whole session

    private val _fixture = MutableStateFlow<String?>(null)
    /** Non-null while a fixture is being browsed. */
    val fixture: StateFlow<String?> = _fixture

    init {
        scope.launch { store.dispatch(agent.sessionCreated("AIUX Compose demo")) }
    }

    fun onAction(action: AIUXAction) {
        when (action.id) {
            AIUXActions.COMPOSER_SEND -> {
                val text = action.payload["text"]?.jsonPrimitive?.content ?: return
                sendPrompt(text)
            }
            AIUXActions.APPROVAL_APPROVE -> pendingApproval?.complete(true)
            AIUXActions.APPROVAL_REJECT -> pendingApproval?.complete(false)
            else -> Unit // navigation actions (context.open, citation.open, …) no-op in the demo
        }
    }

    /** user prompt → stream → tool start → tool finish → approval → approve → render result */
    fun sendPrompt(text: String) {
        val messageId = "m${++messageN}"
        scope.launch {
            agent.userMessage("u$messageN", text).forEach { store.dispatch(it) }
            store.dispatch(agent.runStarted("r$messageN"))
            store.dispatch(agent.assistantMessage(messageId))

            val scripted = "Searching the AIUX spec for invoice matches, drafting the result card…"
            store.dispatch(agent.textPart(messageId, "p1"))
            for (word in scripted.split(" ")) {
                delay(60)
                store.dispatch(agent.textDelta(messageId, "p1", "$word "))
            }
            store.dispatch(agent.markdownPart(messageId, "p2", "**Found:** invoice `inv-9` for **$420.00** — publish requires approval."))

            store.dispatch(agent.toolStarted("t1", "search", buildJsonObject { put("q", "invoice inv-9") }))
            delay(400)
            store.dispatch(agent.toolProgress("t1", 1.0, 3.0, "querying"))
            delay(400)
            store.dispatch(agent.toolProgress("t1", 3.0, 3.0, "ranking"))
            delay(300)
            store.dispatch(agent.toolCompleted("t1", buildJsonObject {
                put("hits", 2); put("top", "inv-9")
            }))
            store.dispatch(agent.toolPart(messageId, "p3", "t1"))

            store.dispatch(agent.approvalRequested("a1", "Publish invoice INV-9?", "Charges $420.00 to Acme."))
            store.dispatch(agent.approvalPart(messageId, "p4", "a1"))

            val approved = CompletableDeferred<Boolean>().also { pendingApproval = it }.await()
            store.dispatch(agent.approvalResolved("a1", if (approved) "approved" else "rejected", "user"))
            if (approved) {
                delay(250)
                store.dispatch(agent.approvalResolved("a1", "executed", "host"))
                store.dispatch(agent.resultSurface("sf-1"))
                store.dispatch(agent.surfacePart(messageId, "p5", "sf-1"))
                store.dispatch(agent.textPart(messageId, "p6", "Done — INV-9 sent."))
            } else {
                store.dispatch(agent.textPart(messageId, "p5", "Cancelled — invoice was not published."))
            }
            store.dispatch(agent.messageComplete(messageId))
            store.dispatch(agent.runCompleted("r$messageN"))
        }
    }

    fun openFixture(name: String) { _fixture.value = name }
    fun closeFixture() { _fixture.value = null }

    fun close() { store.close() }
}
