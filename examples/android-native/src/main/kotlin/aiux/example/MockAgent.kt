package aiux.example

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject

/**
 * Scripted agent emitting protocol-v1 events for the Phase 3 gate:
 * user prompt → stream → tool start/finish → approval → approve → render result.
 * Sequence numbers are contiguous per session, matching conformance fixtures.
 */
class MockAgent(private val sessionId: String = "s1") {
    private var sequence = 0
    private var eventN = 0

    private fun event(type: String, payload: JsonObject): String = buildJsonObject {
        put("eventId", "e${++eventN}")
        put("sessionId", sessionId)
        put("sequence", sequence++)
        put("timestamp", "2026-01-01T00:00:${"%02d".format(sequence)}Z")
        put("type", type)
        put("payload", payload)
    }.toString()

    fun sessionCreated(title: String): String = event("session.created", buildJsonObject {
        put("protocolVersion", "0.1")
        putJsonObject("session") {
            put("id", sessionId); put("title", title); put("createdAt", "2026-01-01T00:00:00Z")
        }
    })

    fun userMessage(id: String, text: String): List<String> = listOf(
        event("message.created", buildJsonObject {
            put("protocolVersion", "0.1")
            putJsonObject("message") { put("id", id); put("role", "user"); put("status", "complete") }
        }),
        event("part.added", buildJsonObject {
            put("protocolVersion", "0.1"); put("messageId", id)
            putJsonObject("part") { put("id", "$id-p1"); put("type", "text"); put("text", text) }
        }),
    )

    fun runStarted(runId: String): String = event("run.started", buildJsonObject {
        put("protocolVersion", "0.1")
        putJsonObject("run") { put("id", runId); put("status", "running"); put("startedAt", "2026-01-01T00:00:01Z") }
    })

    fun assistantMessage(id: String): String = event("message.created", buildJsonObject {
        put("protocolVersion", "0.1")
        putJsonObject("message") { put("id", id); put("role", "assistant"); put("status", "streaming") }
    })

    fun textPart(messageId: String, partId: String, text: String = ""): String =
        partAdded(messageId, buildJsonObject { put("id", partId); put("type", "text"); put("text", text) })

    fun textDelta(messageId: String, partId: String, delta: String): String =
        event("text.delta", buildJsonObject {
            put("protocolVersion", "0.1"); put("messageId", messageId); put("partId", partId); put("delta", delta)
        })

    fun markdownPart(messageId: String, partId: String, markdown: String): String =
        partAdded(messageId, buildJsonObject { put("id", partId); put("type", "markdown"); put("markdown", markdown) })

    fun toolStarted(id: String, name: String, input: JsonObject): String = event("tool.started", buildJsonObject {
        put("protocolVersion", "0.1")
        putJsonObject("tool") {
            put("id", id); put("name", name); put("status", "running"); put("input", input)
        }
    })

    fun toolProgress(id: String, current: Double, total: Double, label: String): String =
        event("tool.progress", buildJsonObject {
            put("protocolVersion", "0.1"); put("toolId", id)
            putJsonObject("progress") { put("current", current); put("total", total); put("label", label) }
        })

    fun toolCompleted(id: String, result: JsonObject): String = event("tool.completed", buildJsonObject {
        put("protocolVersion", "0.1"); put("toolId", id); put("result", result)
    })

    fun toolPart(messageId: String, partId: String, toolId: String): String =
        partAdded(messageId, buildJsonObject { put("id", partId); put("type", "tool"); put("toolId", toolId) })

    fun approvalRequested(id: String, prompt: String, description: String): String =
        event("approval.requested", buildJsonObject {
            put("protocolVersion", "0.1")
            putJsonObject("approval") {
                put("id", id); put("prompt", prompt); put("description", description)
                put("status", "requested")
                putJsonObject("action") {
                    put("id", "invoice.publish")
                    putJsonObject("payload") { put("invoiceId", "inv-9") }
                }
            }
        })

    fun approvalPart(messageId: String, partId: String, approvalId: String): String =
        partAdded(messageId, buildJsonObject { put("id", partId); put("type", "approval"); put("approvalId", approvalId) })

    fun approvalResolved(id: String, decision: String, resolvedBy: String): String =
        event("approval.resolved", buildJsonObject {
            put("protocolVersion", "0.1"); put("approvalId", id)
            putJsonObject("resolution") {
                put("decision", decision); put("resolvedBy", resolvedBy)
                put("resolvedAt", "2026-01-01T00:00:30Z")
            }
        })

    fun resultSurface(id: String): String = event("surface.created", buildJsonObject {
        put("protocolVersion", "0.1")
        putJsonObject("surface") {
            put("id", id); put("name", "invoice-card"); put("revision", 0)
            putJsonObject("root") {
                put("type", "card"); put("title", "Invoice INV-9")
                putJsonArray("children") {
                    addJsonObject {
                        put("type", "keyValue")
                        putJsonArray("items") {
                            addJsonObject { put("key", "Total"); put("value", "$420.00") }
                            addJsonObject { put("key", "Status"); put("value", "sent") }
                        }
                    }
                    addJsonObject {
                        put("type", "status"); put("text", "Delivered to Acme"); put("tone", "success")
                    }
                }
            }
        }
    })

    fun surfacePart(messageId: String, partId: String, surfaceId: String): String =
        partAdded(messageId, buildJsonObject { put("id", partId); put("type", "surface"); put("surfaceId", surfaceId) })

    fun messageComplete(id: String): String = event("message.updated", buildJsonObject {
        put("protocolVersion", "0.1"); put("messageId", id); put("status", "complete")
    })

    fun runCompleted(id: String): String = event("run.completed", buildJsonObject {
        put("protocolVersion", "0.1"); put("runId", id)
    })

    private fun partAdded(messageId: String, part: JsonObject): String =
        event("part.added", buildJsonObject {
            put("protocolVersion", "0.1"); put("messageId", messageId); put("part", part)
        })
}
