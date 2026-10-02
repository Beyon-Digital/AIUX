package aiux

import org.json.JSONObject
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Phase 2 gate (plan §16): create session → dispatch fixture → snapshot →
 * serialize → restore, on desktop JVM via the Linux cdylib (jna.library.path).
 * Also runs in CI from the `kotlin-bindings` job.
 */
class AiuxSessionTest {

    private fun fixtureEventsJson(): String {
        val fixture = File("../../conformance/fixtures/basic-response.json")
        return JSONObject(fixture.readText()).getJSONArray("events").toString()
    }

    @Test
    fun createDispatchSnapshotSerializeRestore() {
        AiuxSession.create("""{"sessionId":"s1"}""").use { session ->
            val report = JSONObject(session.dispatchBatch(fixtureEventsJson()))
            assertEquals(7, report.getInt("applied"))

            val snapshot = session.snapshot()
            assertEquals("s1", JSONObject(snapshot).getString("sessionId"))
            assertEquals(1, JSONObject(snapshot).getJSONArray("messages")
                .let { msgs -> (0 until msgs.length()).count { i ->
                    msgs.getJSONObject(i).getJSONArray("parts").toString()
                        .contains("The answer is 42.")
                } })

            val serialized = session.serialize()
            AiuxSession.restore(serialized).use { restored ->
                // Restored session reduces to the exact same canonical snapshot.
                assertEquals(snapshot, restored.snapshot())
                assertEquals(serialized, restored.serialize())
            }

            session.reset()
            assertEquals(0, JSONObject(session.snapshot()).getJSONArray("messages").length())
        }
    }
}
