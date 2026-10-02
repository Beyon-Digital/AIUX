package aiux.compose

import aiux.compose.model.AIUXActions
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonPrimitive

/** Store → snapshot flow over the real UniFFI session (JVM, JNA host lib). */
class SessionStoreTest {

    @Test
    fun dispatchBatchUpdatesSnapshot() = runTest {
        AIUXSessionStore.create().use { store ->
            assertNull(store.lastError.value)
            val fixture = FixtureHarness.load("basic-response")
            val report = store.dispatchBatch(fixture.eventsJsonArray)
            assertTrue(report.isSuccess)
            assertEquals(fixture.events.size, report.getOrThrow().applied)
            val snapshot = store.snapshot.value
            assertEquals("s1", snapshot.sessionId)
            assertEquals(2, snapshot.messages.size)
            assertTrue(snapshot.messages[1].parts.isNotEmpty())
        }
    }

    @Test
    fun serializeRestoreRoundTrip() = runTest {
        AIUXSessionStore.create().use { store ->
            store.dispatchBatch(FixtureHarness.load("streaming-response").eventsJsonArray)
            val serialized = store.serialize().getOrThrow()
            AIUXSessionStore.restore(serialized).use { restored ->
                assertEquals(store.snapshot.value, restored.snapshot.value)
            }
        }
    }

    @Test
    fun invalidEventSurfacesErrorNotCrash() = runTest {
        AIUXSessionStore.create().use { store ->
            val report = store.dispatchBatch("""[{"eventId":"","sessionId":"s1","sequence":0,"type":"x","payload":{}}]""")
            assertTrue(report.isFailure)
            assertNotNull(store.lastError.value)
        }
    }

    @Test
    fun actionIdsAreStableContract() {
        // The (AIUXAction)->Unit contract the host implements (plan §23).
        assertEquals("aiux.composer.send", AIUXActions.COMPOSER_SEND)
        assertEquals("aiux.approval.approve", AIUXActions.APPROVAL_APPROVE)
        assertEquals("aiux.approval.reject", AIUXActions.APPROVAL_REJECT)
        val payload = kotlinx.serialization.json.buildJsonObject { put("text", JsonPrimitive("hi")) }
        assertEquals("hi", payload["text"]?.jsonPrimitive?.content)
    }
}
