package aiux.compose

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject

/**
 * A conformance fixture (`conformance/fixtures/<name>.json`): `{name,
 * protocolVersion, events[]}` — the same catalog every renderer consumes
 * (plan §17).
 */
data class AIUXFixture(
    val name: String,
    val protocolVersion: String,
    /** Raw event JSON strings, in fixture order, ready for dispatchBatch. */
    val events: List<String>,
) {
    /** All events as a single JSON array for `dispatchBatch`. */
    val eventsJsonArray: String get() = events.joinToString(prefix = "[", postfix = "]")

    companion object {
        private val json = Json { ignoreUnknownKeys = true }

        fun parse(fixtureJson: String): AIUXFixture {
            val obj = json.parseToJsonElement(fixtureJson).jsonObject
            return AIUXFixture(
                name = (obj["name"] as? JsonPrimitive)?.content ?: "",
                protocolVersion = (obj["protocolVersion"] as? JsonPrimitive)?.content ?: "",
                events = obj["events"]?.jsonArray?.map { it.toString() } ?: emptyList(),
            )
        }
    }
}
