package aiux.compose.model

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull

/**
 * Render-side model for the AIUX snapshot (core/rust `aiux-persistence`
 * `Snapshot`). Parsed from the canonical JSON `AiuxSession.snapshot()`
 * returns — never from internal reducer types (ADR 0005).
 *
 * Parsing is lenient by design (plan §21): unknown optional fields and unknown
 * part/node variants degrade to `Unknown` placeholders rather than failing the
 * whole snapshot.
 */

/** A semantic action emitted by interactive UI — data only, executed by host policy (plan §23). */
data class AIUXAction(
    val id: String,
    val payload: JsonObject = JsonObject(emptyMap()),
) {
    companion object {
        fun fromJson(obj: JsonObject?): AIUXAction? {
            val id = obj?.get("id")?.jsonPrimitive?.content ?: return null
            val payload = obj["payload"] as? JsonObject ?: JsonObject(emptyMap())
            return AIUXAction(id, payload)
        }
    }
}

/** Action ids emitted by AIUXCompose itself (host resolves; §23). */
object AIUXActions {
    const val COMPOSER_SEND = "aiux.composer.send"
    const val COMPOSER_CANCEL = "aiux.composer.cancel"
    const val COMPOSER_ATTACH = "aiux.composer.attach"
    const val APPROVAL_APPROVE = "aiux.approval.approve"
    const val APPROVAL_REJECT = "aiux.approval.reject"
    const val ERROR_RETRY = "aiux.error.retry"
    const val CITATION_OPEN = "aiux.citation.open"
    const val ATTACHMENT_OPEN = "aiux.attachment.open"
    const val IMAGE_OPEN = "aiux.image.open"
    const val ARTIFACT_OPEN = "aiux.artifact.open"
    const val CONTEXT_OPEN = "aiux.context.open"
    const val SURFACE_INPUT_CHANGE = "aiux.surface.input.change"
    const val SURFACE_SELECT_CHANGE = "aiux.surface.select.change"
    const val SURFACE_CHECKBOX_CHANGE = "aiux.surface.checkbox.change"
    const val SURFACE_RADIO_CHANGE = "aiux.surface.radio.change"
}

enum class AIRole { User, Assistant, System, Tool }

enum class AIMessageStatus { Streaming, Complete, Failed, Cancelled }

enum class AIStatusLevel { Info, Success, Warning, Error }

enum class AIToolStatus { Running, Completed, Failed }

enum class AIApprovalStatus { Requested, Approved, Rejected, Expired, Executed }

enum class AIRunStatus { Running, Completed, Failed, Cancelled }

data class AIUXAttachment(
    val id: String? = null,
    val name: String? = null,
    val mimeType: String? = null,
    val uri: String? = null,
    val sizeBytes: Long? = null,
)

data class AIUXCitation(
    val id: String? = null,
    val title: String? = null,
    val uri: String? = null,
    val snippet: String? = null,
    val source: String? = null,
)

data class AIUXProgress(
    val current: Double? = null,
    val total: Double? = null,
    val label: String? = null,
) {
    /** Normalized 0..1 fraction, or null when indeterminate/unknown. */
    val fraction: Float?
        get() {
            val c = current ?: return null
            val t = total ?: return null
            if (t <= 0.0) return null
            return (c / t).toFloat().coerceIn(0f, 1f)
        }
}

data class AIUXError(
    val code: String,
    val message: String,
    val retryable: Boolean? = null,
    val detail: JsonElement? = null,
)

data class AIUXTool(
    val id: String,
    val name: String,
    val status: AIToolStatus,
    val input: JsonElement? = null,
    val progress: AIUXProgress? = null,
    val result: JsonElement? = null,
    val error: AIUXError? = null,
    val startedAt: String? = null,
    val completedAt: String? = null,
)

data class AIUXApprovalResolution(
    val decision: String,
    val resolvedBy: String? = null,
    val note: String? = null,
    val resolvedAt: String? = null,
)

data class AIUXApproval(
    val id: String,
    val prompt: String,
    val description: String? = null,
    val toolId: String? = null,
    val action: AIUXAction? = null,
    val status: AIApprovalStatus,
    val expiresAt: String? = null,
    val resolution: AIUXApprovalResolution? = null,
)

data class AIUXArtifact(
    val id: String,
    val kind: String,
    val title: String? = null,
    val revision: Long = 0,
    val content: String? = null,
    val uri: String? = null,
    val metadata: JsonElement? = null,
    /** Inline preview contract (ADR 0007). */
    val preview: AIUXArtifactPreview? = null,
    /** Opened-workspace contract (ADR 0007). */
    val workspace: AIUXArtifactWorkspace? = null,
)

data class AIUXContextEntity(
    val id: String,
    val kind: String,
    val label: String,
    val description: String? = null,
    val uri: String? = null,
    val data: JsonElement? = null,
)

data class AIUXRun(
    val id: String,
    val status: AIRunStatus,
    val retryOf: String? = null,
    val inputMessageId: String? = null,
    val result: JsonElement? = null,
    val error: AIUXError? = null,
    val startedAt: String? = null,
    val completedAt: String? = null,
)

data class AIUXSessionInfo(
    val id: String,
    val title: String? = null,
    val createdAt: String? = null,
    val context: List<AIUXContextEntity> = emptyList(),
)

/** A typed part within a message — all 13 protocol kinds plus Unknown. */
sealed class AIUXPart {
    abstract val id: String

    data class Text(override val id: String, val text: String) : AIUXPart()
    data class Markdown(override val id: String, val markdown: String) : AIUXPart()
    data class Code(override val id: String, val code: String, val language: String? = null) : AIUXPart()
    data class Image(override val id: String, val attachment: AIUXAttachment) : AIUXPart()
    data class Attachment(override val id: String, val attachment: AIUXAttachment) : AIUXPart()
    data class Citation(override val id: String, val citation: AIUXCitation) : AIUXPart()
    data class ToolRef(override val id: String, val toolId: String) : AIUXPart()
    data class ApprovalRef(override val id: String, val approvalId: String) : AIUXPart()
    data class ArtifactRef(override val id: String, val artifactId: String) : AIUXPart()
    data class Status(override val id: String, val text: String, val level: AIStatusLevel? = null) : AIUXPart()
    data class Progress(override val id: String, val progress: AIUXProgress) : AIUXPart()
    data class SurfaceRef(override val id: String, val surfaceId: String) : AIUXPart()
    data class Error(override val id: String, val error: AIUXError) : AIUXPart()
    data class Unknown(override val id: String, val type: String, val raw: JsonElement? = null) : AIUXPart()
}

data class AIUXMessage(
    val id: String,
    val role: AIRole,
    val status: AIMessageStatus? = null,
    val parts: List<AIUXPart> = emptyList(),
    val createdAt: String? = null,
) {
    val streaming: Boolean get() = status == AIMessageStatus.Streaming
}

/**
 * Render-facing session snapshot — mirror of `aiux_persistence::Snapshot`.
 */
data class AIUXSnapshot(
    val protocolVersion: String = "",
    val sessionId: String = "",
    val session: AIUXSessionInfo? = null,
    val messages: List<AIUXMessage> = emptyList(),
    val tools: List<AIUXTool> = emptyList(),
    val approvals: List<AIUXApproval> = emptyList(),
    val artifacts: List<AIUXArtifact> = emptyList(),
    val surfaces: List<AIUXSurface> = emptyList(),
    val context: List<AIUXContextEntity> = emptyList(),
    val runs: List<AIUXRun> = emptyList(),
    val activeRunId: String? = null,
) {
    val toolById: Map<String, AIUXTool> get() = tools.associateBy { it.id }
    val approvalById: Map<String, AIUXApproval> get() = approvals.associateBy { it.id }
    val artifactById: Map<String, AIUXArtifact> get() = artifacts.associateBy { it.id }
    val surfaceById: Map<String, AIUXSurface> get() = surfaces.associateBy { it.id }

    /** Merged context (session-level + injected). */
    val allContext: List<AIUXContextEntity>
        get() = (session?.context.orEmpty() + context).distinctBy { it.id }

    val activeRun: AIUXRun? get() = runs.firstOrNull { it.id == activeRunId }

    companion object {
        val EMPTY = AIUXSnapshot()
    }
}

/** Result counters from `AiuxSession.dispatch*()` (`DispatchReport`). */
data class AIUXDispatchReport(
    val applied: Int = 0,
    val duplicatesIgnored: Int = 0,
    val buffered: Int = 0,
)

object AIUXModelParser {
    private val json = Json { ignoreUnknownKeys = true }

    fun parseSnapshot(jsonText: String): AIUXSnapshot =
        parseSnapshot(json.parseToJsonElement(jsonText).jsonObject)

    fun parseSnapshot(obj: JsonObject): AIUXSnapshot {
        val sessionObj = obj["session"] as? JsonObject
        return AIUXSnapshot(
            protocolVersion = obj["protocolVersion"]?.str() ?: "",
            sessionId = obj["sessionId"]?.str() ?: "",
            session = sessionObj?.let { parseSessionInfo(it) },
            messages = obj["messages"].arr().mapNotNull { parseMessage(it as? JsonObject) },
            tools = obj["tools"].arr().mapNotNull { parseTool(it as? JsonObject) },
            approvals = obj["approvals"].arr().mapNotNull { parseApproval(it as? JsonObject) },
            artifacts = obj["artifacts"].arr().mapNotNull { parseArtifact(it as? JsonObject) },
            surfaces = obj["surfaces"].arr().mapNotNull { parseSurface(it as? JsonObject) },
            context = obj["context"].arr().mapNotNull { parseContext(it as? JsonObject) },
            runs = obj["runs"].arr().mapNotNull { parseRun(it as? JsonObject) },
            activeRunId = obj["activeRunId"]?.str(),
        )
    }

    private fun parseSessionInfo(obj: JsonObject): AIUXSessionInfo = AIUXSessionInfo(
        id = obj["id"]?.str() ?: "",
        title = obj["title"]?.str(),
        createdAt = obj["createdAt"]?.str(),
        context = obj["context"].arr().mapNotNull { parseContext(it as? JsonObject) },
    )

    fun parseDispatchReport(jsonText: String): AIUXDispatchReport =
        parseDispatchReport(json.parseToJsonElement(jsonText).jsonObject)

    fun parseDispatchReport(obj: JsonObject): AIUXDispatchReport = AIUXDispatchReport(
        applied = obj["applied"].int() ?: 0,
        duplicatesIgnored = obj["duplicatesIgnored"].int() ?: 0,
        buffered = obj["buffered"].int() ?: 0,
    )

    fun parseMessage(obj: JsonObject?): AIUXMessage? {
        obj ?: return null
        val id = obj["id"]?.str() ?: return null
        val role = when (obj["role"]?.str()) {
            "user" -> AIRole.User
            "assistant" -> AIRole.Assistant
            "system" -> AIRole.System
            "tool" -> AIRole.Tool
            else -> AIRole.Assistant
        }
        val status = when (obj["status"]?.str()) {
            "streaming" -> AIMessageStatus.Streaming
            "complete" -> AIMessageStatus.Complete
            "failed" -> AIMessageStatus.Failed
            "cancelled" -> AIMessageStatus.Cancelled
            else -> null
        }
        return AIUXMessage(
            id = id,
            role = role,
            status = status,
            parts = obj["parts"].arr().mapNotNull { parsePart(it as? JsonObject) },
            createdAt = obj["createdAt"]?.str(),
        )
    }

    fun parsePart(obj: JsonObject?): AIUXPart? {
        obj ?: return null
        val type = obj["type"]?.str() ?: return null
        val id = obj["id"]?.str() ?: ""
        return when (type) {
            "text" -> AIUXPart.Text(id, obj["text"]?.str() ?: "")
            "markdown" -> AIUXPart.Markdown(id, obj["markdown"]?.str() ?: "")
            "code" -> AIUXPart.Code(id, obj["code"]?.str() ?: "", obj["language"]?.str())
            "image" -> AIUXPart.Image(id, parseAttachment(obj["attachment"] as? JsonObject) ?: AIUXAttachment())
            "attachment" -> AIUXPart.Attachment(id, parseAttachment(obj["attachment"] as? JsonObject) ?: AIUXAttachment())
            "citation" -> AIUXPart.Citation(id, parseCitation(obj["citation"] as? JsonObject) ?: AIUXCitation())
            "tool" -> obj["toolId"]?.str()?.let { AIUXPart.ToolRef(id, it) } ?: AIUXPart.Unknown(id, type, obj)
            "approval" -> obj["approvalId"]?.str()?.let { AIUXPart.ApprovalRef(id, it) } ?: AIUXPart.Unknown(id, type, obj)
            "artifact" -> obj["artifactId"]?.str()?.let { AIUXPart.ArtifactRef(id, it) } ?: AIUXPart.Unknown(id, type, obj)
            "status" -> AIUXPart.Status(id, obj["text"]?.str() ?: "", parseStatusLevel(obj["level"]?.str()))
            "progress" -> AIUXPart.Progress(id, parseProgress(obj["progress"] as? JsonObject) ?: AIUXProgress())
            "surface" -> obj["surfaceId"]?.str()?.let { AIUXPart.SurfaceRef(id, it) } ?: AIUXPart.Unknown(id, type, obj)
            "error" -> AIUXPart.Error(id, parseError(obj["error"] as? JsonObject) ?: AIUXError("unknown", "Unknown error"))
            else -> AIUXPart.Unknown(id, type, obj)
        }
    }

    fun parseTool(obj: JsonObject?): AIUXTool? {
        obj ?: return null
        return AIUXTool(
            id = obj["id"]?.str() ?: return null,
            name = obj["name"]?.str() ?: "",
            status = when (obj["status"]?.str()) {
                "running" -> AIToolStatus.Running
                "completed" -> AIToolStatus.Completed
                "failed" -> AIToolStatus.Failed
                else -> AIToolStatus.Running
            },
            input = obj["input"],
            progress = parseProgress(obj["progress"] as? JsonObject),
            result = obj["result"],
            error = parseError(obj["error"] as? JsonObject),
            startedAt = obj["startedAt"]?.str(),
            completedAt = obj["completedAt"]?.str(),
        )
    }

    fun parseApproval(obj: JsonObject?): AIUXApproval? {
        obj ?: return null
        return AIUXApproval(
            id = obj["id"]?.str() ?: return null,
            prompt = obj["prompt"]?.str() ?: "",
            description = obj["description"]?.str(),
            toolId = obj["toolId"]?.str(),
            action = AIUXAction.fromJson(obj["action"] as? JsonObject),
            status = when (obj["status"]?.str()) {
                "requested" -> AIApprovalStatus.Requested
                "approved" -> AIApprovalStatus.Approved
                "rejected" -> AIApprovalStatus.Rejected
                "expired" -> AIApprovalStatus.Expired
                "executed" -> AIApprovalStatus.Executed
                else -> AIApprovalStatus.Requested
            },
            expiresAt = obj["expiresAt"]?.str(),
            resolution = (obj["resolution"] as? JsonObject)?.let { r ->
                AIUXApprovalResolution(
                    decision = r["decision"]?.str() ?: "",
                    resolvedBy = r["resolvedBy"]?.str(),
                    note = r["note"]?.str(),
                    resolvedAt = r["resolvedAt"]?.str(),
                )
            },
        )
    }

    fun parseArtifact(obj: JsonObject?): AIUXArtifact? {
        obj ?: return null
        return AIUXArtifact(
            id = obj["id"]?.str() ?: return null,
            kind = obj["kind"]?.str() ?: "document",
            title = obj["title"]?.str(),
            revision = obj["revision"].long() ?: 0,
            content = obj["content"]?.str(),
            uri = obj["uri"]?.str(),
            metadata = obj["metadata"],
            preview = (obj["preview"] as? JsonObject)?.let { p ->
                AIUXArtifactPreview(
                    summary = p["summary"]?.str(),
                    surface = SurfaceNodeParser.parseDescriptor(p["surface"] as? JsonObject),
                )
            },
            workspace = (obj["workspace"] as? JsonObject)?.let { w ->
                AIUXArtifactWorkspace(
                    // Contract default is fullscreen; unknown values degrade to it.
                    mode = when (w["mode"]?.str()) {
                        "detail" -> AIWorkspaceMode.Detail
                        "sheet" -> AIWorkspaceMode.Sheet
                        else -> AIWorkspaceMode.Fullscreen
                    },
                    surface = SurfaceNodeParser.parseDescriptor(w["surface"] as? JsonObject),
                    lazy = w["lazy"].bool() ?: false,
                )
            },
        )
    }

    fun parseSurface(obj: JsonObject?): AIUXSurface? {
        obj ?: return null
        val id = obj["id"]?.str() ?: return null
        val root = SurfaceNodeParser.parse(obj["root"] as? JsonObject) ?: return null
        return AIUXSurface(
            id = id,
            name = obj["name"]?.str(),
            revision = obj["revision"].long() ?: 0,
            root = root,
        )
    }

    fun parseContext(obj: JsonObject?): AIUXContextEntity? {
        obj ?: return null
        return AIUXContextEntity(
            id = obj["id"]?.str() ?: return null,
            kind = obj["kind"]?.str() ?: "unknown",
            label = obj["label"]?.str() ?: obj["id"]?.str() ?: "",
            description = obj["description"]?.str(),
            uri = obj["uri"]?.str(),
            data = obj["data"],
        )
    }

    fun parseRun(obj: JsonObject?): AIUXRun? {
        obj ?: return null
        return AIUXRun(
            id = obj["id"]?.str() ?: return null,
            status = when (obj["status"]?.str()) {
                "running" -> AIRunStatus.Running
                "completed" -> AIRunStatus.Completed
                "failed" -> AIRunStatus.Failed
                "cancelled" -> AIRunStatus.Cancelled
                else -> AIRunStatus.Running
            },
            retryOf = obj["retryOf"]?.str(),
            inputMessageId = obj["inputMessageId"]?.str(),
            result = obj["result"],
            error = parseError(obj["error"] as? JsonObject),
            startedAt = obj["startedAt"]?.str(),
            completedAt = obj["completedAt"]?.str(),
        )
    }

    fun parseAttachment(obj: JsonObject?): AIUXAttachment? {
        obj ?: return null
        return AIUXAttachment(
            id = obj["id"]?.str(),
            name = obj["name"]?.str(),
            mimeType = obj["mimeType"]?.str(),
            uri = obj["uri"]?.str(),
            sizeBytes = obj["sizeBytes"].long(),
        )
    }

    fun parseCitation(obj: JsonObject?): AIUXCitation? {
        obj ?: return null
        return AIUXCitation(
            id = obj["id"]?.str(),
            title = obj["title"]?.str(),
            uri = obj["uri"]?.str(),
            snippet = obj["snippet"]?.str(),
            source = obj["source"]?.str(),
        )
    }

    fun parseProgress(obj: JsonObject?): AIUXProgress? {
        obj ?: return null
        return AIUXProgress(
            current = obj["current"].dbl(),
            total = obj["total"].dbl(),
            label = obj["label"]?.str(),
        )
    }

    fun parseError(obj: JsonObject?): AIUXError? {
        obj ?: return null
        return AIUXError(
            code = obj["code"]?.str() ?: "unknown",
            message = obj["message"]?.str() ?: "",
            retryable = obj["retryable"]?.let { (it as? JsonPrimitive)?.booleanOrNull },
            detail = obj["detail"],
        )
    }

    fun parseStatusLevel(raw: String?): AIStatusLevel? = when (raw) {
        "info" -> AIStatusLevel.Info
        "success" -> AIStatusLevel.Success
        "warning" -> AIStatusLevel.Warning
        "error" -> AIStatusLevel.Error
        else -> null
    }

    internal fun JsonElement?.str(): String? =
        if (this == null || this is JsonNull) null else (this as? JsonPrimitive)?.content

    internal fun JsonElement?.arr(): List<JsonElement> = (this as? JsonArray) ?: emptyList()
    internal fun JsonElement?.int(): Int? = (this as? JsonPrimitive)?.longOrNull?.toInt()
    internal fun JsonElement?.long(): Long? = (this as? JsonPrimitive)?.longOrNull
    internal fun JsonElement?.dbl(): Double? = (this as? JsonPrimitive)?.doubleOrNull
    internal fun JsonElement?.bool(): Boolean? = (this as? JsonPrimitive)?.booleanOrNull
}

internal fun JsonElement?.aiuxString() = AIUXModelParser.run { this@aiuxString.str() }
internal fun JsonElement?.aiuxArr() = AIUXModelParser.run { this@aiuxArr.arr() }
internal fun JsonElement?.aiuxInt() = AIUXModelParser.run { this@aiuxInt.int() }
internal fun JsonElement?.aiuxLong() = AIUXModelParser.run { this@aiuxLong.long() }
internal fun JsonElement?.aiuxDouble() = AIUXModelParser.run { this@aiuxDouble.dbl() }
internal fun JsonElement?.aiuxBool() = AIUXModelParser.run { this@aiuxBool.bool() }
