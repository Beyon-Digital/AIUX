package aiux.compose.model

import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

/**
 * AIUX Surface Schema v1 (plan §6, ADR 0006) — the fixed primitive set.
 * Layout attributes stay semantic (`gap: xs..xl` etc.); unknown node types and
 * unknown enum values degrade gracefully (`UnknownNode` / defaults) so new
 * schema versions never crash old renderers (plan §21).
 */

enum class AIGap { Xs, Sm, Md, Lg, Xl }
enum class AIPadding { None, Xs, Sm, Md, Lg }
enum class AIRadius { Sm, Md, Lg, Full }
enum class AIAlignment { Start, Center, End, Stretch }
enum class AIDistribution { Start, Center, End, SpaceBetween, SpaceAround, SpaceEvenly }
enum class AIStackDirection { Vertical, Horizontal }
enum class AITextVariant { Body, Caption, Label, Emphasis, Strong, Muted }
enum class AITone { Default, Accent, Muted, Success, Warning, Destructive }
enum class AIButtonVariant { Primary, Secondary, Ghost, Destructive }
enum class AIIconSize { Sm, Md, Lg }
enum class AIInputType { Text, Email, Number, Password, Url }

/** Common semantic layout attributes shared by all surface nodes. */
data class AIUXNodeStyle(
    val gap: AIGap? = null,
    val padding: AIPadding? = null,
    val radius: AIRadius? = null,
    val alignment: AIAlignment? = null,
    val distribution: AIDistribution? = null,
)

data class AIUXMenuItem(val label: String, val action: AIUXAction, val icon: String? = null, val disabled: Boolean = false)
data class AIUXSelectOption(val label: String, val value: String)
data class AIUXKeyValueItem(val key: String, val value: String, val tone: AITone? = null)

/** Table column alignment (ADR 0007). */
enum class AIColumnAlign { Start, Center, End }

/** A `table` column descriptor (ADR 0007). */
data class AIUXTableColumn(val key: String, val title: String, val align: AIColumnAlign? = null)

/** A typed `table` cell — `{"type": ...}` on the wire; bare strings decode as Text (ADR 0007). */
sealed class AITableCell {
    data class Text(val text: String) : AITableCell()
    data class Number(val value: Double) : AITableCell()
    data class Badge(val text: String, val tone: AITone? = null) : AITableCell()
    data class Action(val label: String, val action: AIUXAction) : AITableCell()
}

/** An inline surface descriptor carried inside another entity (ADR 0007). */
data class AIUXSurfaceDescriptor(val id: String, val root: AISurfaceNode)

/** `artifact.preview` — what an artifact card shows inline (ADR 0007). */
data class AIUXArtifactPreview(val summary: String? = null, val surface: AIUXSurfaceDescriptor? = null)

enum class AIWorkspaceMode { Fullscreen, Detail, Sheet }

/** `artifact.workspace` — opened-workspace contract (ADR 0007). */
data class AIUXArtifactWorkspace(
    val mode: AIWorkspaceMode? = null,
    val surface: AIUXSurfaceDescriptor? = null,
    val lazy: Boolean = false,
)

data class AIUXSurface(
    val id: String,
    val name: String? = null,
    val revision: Long = 0,
    val root: AISurfaceNode,
)

sealed class AISurfaceNode {
    abstract val style: AIUXNodeStyle

    data class Surface(override val style: AIUXNodeStyle, val children: List<AISurfaceNode>) : AISurfaceNode()
    data class Card(override val style: AIUXNodeStyle, val title: String? = null, val children: List<AISurfaceNode>) : AISurfaceNode()
    data class Stack(override val style: AIUXNodeStyle, val direction: AIStackDirection = AIStackDirection.Vertical, val children: List<AISurfaceNode>) : AISurfaceNode()
    data class Row(override val style: AIUXNodeStyle, val children: List<AISurfaceNode>) : AISurfaceNode()
    data class Grid(override val style: AIUXNodeStyle, val columns: Int = 2, val children: List<AISurfaceNode>) : AISurfaceNode()
    data class Heading(override val style: AIUXNodeStyle, val text: String, val level: Int = 1) : AISurfaceNode()
    data class Text(override val style: AIUXNodeStyle, val text: String, val variant: AITextVariant = AITextVariant.Body) : AISurfaceNode()
    data class Markdown(override val style: AIUXNodeStyle, val markdown: String) : AISurfaceNode()
    data class Code(override val style: AIUXNodeStyle, val code: String, val language: String? = null) : AISurfaceNode()
    data class Icon(override val style: AIUXNodeStyle, val name: String, val size: AIIconSize = AIIconSize.Md) : AISurfaceNode()
    data class Image(override val style: AIUXNodeStyle, val src: String, val alt: String? = null) : AISurfaceNode()
    data class Badge(override val style: AIUXNodeStyle, val text: String, val tone: AITone = AITone.Default, val icon: String? = null) : AISurfaceNode()
    data class Divider(override val style: AIUXNodeStyle) : AISurfaceNode()
    data class Spacer(override val style: AIUXNodeStyle, val size: AIGap = AIGap.Md) : AISurfaceNode()
    data class KeyValue(override val style: AIUXNodeStyle, val items: List<AIUXKeyValueItem>) : AISurfaceNode()
    data class ListNode(override val style: AIUXNodeStyle, val ordered: Boolean = false, val children: List<AISurfaceNode>) : AISurfaceNode()
    data class ListItem(override val style: AIUXNodeStyle, val title: String, val subtitle: String? = null, val icon: String? = null, val action: AIUXAction? = null, val children: List<AISurfaceNode>) : AISurfaceNode()
    data class Table(override val style: AIUXNodeStyle, val headers: List<String>, val columns: List<AIUXTableColumn>, val rows: List<List<AITableCell>>, val caption: String? = null) : AISurfaceNode()
    data class Button(override val style: AIUXNodeStyle, val label: String, val action: AIUXAction, val variant: AIButtonVariant = AIButtonVariant.Primary, val disabled: Boolean = false) : AISurfaceNode()
    data class Menu(override val style: AIUXNodeStyle, val label: String, val items: List<AIUXMenuItem>) : AISurfaceNode()
    data class Progress(override val style: AIUXNodeStyle, val value: Double? = null, val max: Double? = null, val label: String? = null) : AISurfaceNode()
    data class Status(override val style: AIUXNodeStyle, val text: String, val tone: AITone = AITone.Default) : AISurfaceNode()
    data class Input(override val style: AIUXNodeStyle, val name: String, val label: String? = null, val placeholder: String? = null, val value: String? = null, val inputType: AIInputType = AIInputType.Text, val required: Boolean = false, val disabled: Boolean = false, val errorText: String? = null) : AISurfaceNode()
    data class TextArea(override val style: AIUXNodeStyle, val name: String, val label: String? = null, val placeholder: String? = null, val value: String? = null, val rows: Int? = null, val required: Boolean = false, val disabled: Boolean = false, val errorText: String? = null) : AISurfaceNode()
    data class Select(override val style: AIUXNodeStyle, val name: String, val options: List<AIUXSelectOption>, val label: String? = null, val placeholder: String? = null, val value: String? = null, val required: Boolean = false, val disabled: Boolean = false, val errorText: String? = null) : AISurfaceNode()
    data class Checkbox(override val style: AIUXNodeStyle, val name: String, val label: String, val checked: Boolean = false, val required: Boolean = false, val disabled: Boolean = false, val errorText: String? = null) : AISurfaceNode()
    data class Radio(override val style: AIUXNodeStyle, val name: String, val label: String? = null, val options: List<AIUXSelectOption>, val value: String? = null, val required: Boolean = false, val disabled: Boolean = false, val errorText: String? = null) : AISurfaceNode()
    data class Field(override val style: AIUXNodeStyle, val children: List<AISurfaceNode>, val label: String? = null, val helperText: String? = null, val required: Boolean = false, val disabled: Boolean = false, val errorText: String? = null) : AISurfaceNode()
    data class Form(override val style: AIUXNodeStyle, val children: List<AISurfaceNode>, val submit: AIUXAction, val submitLabel: String? = null, val disabled: Boolean = false) : AISurfaceNode()
    data class Actions(override val style: AIUXNodeStyle, val children: List<AISurfaceNode>) : AISurfaceNode()
    data class Custom(override val style: AIUXNodeStyle, val kind: String, val props: JsonObject, val children: List<AISurfaceNode>) : AISurfaceNode()

    /** A node type this renderer doesn't know — renders as a placeholder, never crashes. */
    data class UnknownNode(override val style: AIUXNodeStyle, val type: String, val raw: JsonElement? = null) : AISurfaceNode()
}

object SurfaceNodeParser {

    fun parse(obj: JsonObject?): AISurfaceNode? {
        obj ?: return null
        val type = obj["type"]?.aiuxString() ?: return null
        val style = parseStyle(obj)
        val children = { obj["children"].aiuxArr().mapNotNull { parse(it as? JsonObject) } }
        return when (type) {
            "surface" -> AISurfaceNode.Surface(style, children())
            "card" -> AISurfaceNode.Card(style, obj["title"]?.aiuxString(), children())
            "stack" -> AISurfaceNode.Stack(
                style,
                direction = if (obj["direction"]?.aiuxString() == "horizontal") AIStackDirection.Horizontal else AIStackDirection.Vertical,
                children = children(),
            )
            "row" -> AISurfaceNode.Row(style, children())
            "grid" -> AISurfaceNode.Grid(
                style,
                columns = obj["columns"].aiuxInt()?.coerceAtLeast(1) ?: 2,
                children = children(),
            )
            "heading" -> AISurfaceNode.Heading(
                style,
                text = obj["text"]?.aiuxString() ?: return null,
                level = obj["level"].aiuxInt()?.coerceIn(1, 6) ?: 1,
            )
            "text" -> AISurfaceNode.Text(
                style,
                text = obj["text"]?.aiuxString() ?: return null,
                variant = parseTextVariant(obj["variant"]?.aiuxString()),
            )
            "markdown" -> AISurfaceNode.Markdown(style, obj["markdown"]?.aiuxString() ?: return null)
            "code" -> AISurfaceNode.Code(style, obj["code"]?.aiuxString() ?: return null, obj["language"]?.aiuxString())
            "icon" -> AISurfaceNode.Icon(
                style,
                name = obj["name"]?.aiuxString() ?: return null,
                size = when (obj["size"]?.aiuxString()) {
                    "sm" -> AIIconSize.Sm; "lg" -> AIIconSize.Lg; else -> AIIconSize.Md
                },
            )
            "image" -> AISurfaceNode.Image(style, src = obj["src"]?.aiuxString() ?: return null, alt = obj["alt"]?.aiuxString())
            "badge" -> AISurfaceNode.Badge(
                style,
                text = obj["text"]?.aiuxString() ?: return null,
                tone = parseTone(obj["tone"]?.aiuxString()),
                icon = obj["icon"]?.aiuxString(),
            )
            "divider" -> AISurfaceNode.Divider(style)
            "spacer" -> AISurfaceNode.Spacer(style, size = parseGap(obj["size"]?.aiuxString()) ?: AIGap.Md)
            "keyValue" -> AISurfaceNode.KeyValue(
                style,
                items = obj["items"].aiuxArr().mapNotNull { (it as? JsonObject)?.let { i ->
                    val k = i["key"]?.aiuxString() ?: return@let null
                    AIUXKeyValueItem(
                        k,
                        i["value"]?.aiuxString() ?: "",
                        tone = i["tone"]?.aiuxString()?.let { parseTone(it) },
                    )
                } },
            )
            "list" -> AISurfaceNode.ListNode(
                style,
                ordered = obj["ordered"].aiuxBool() ?: false,
                children = children(),
            )
            "table" -> {
                val headers = obj["headers"].aiuxArr().mapNotNull { it.aiuxString() }
                val columns = obj["columns"].aiuxArr().mapNotNull { (it as? JsonObject)?.let { c ->
                    val key = c["key"]?.aiuxString() ?: return@let null
                    AIUXTableColumn(
                        key = key,
                        title = c["title"]?.aiuxString() ?: key,
                        align = when (c["align"]?.aiuxString()) {
                            "center" -> AIColumnAlign.Center
                            "end" -> AIColumnAlign.End
                            else -> AIColumnAlign.Start
                        },
                    )
                } }
                val rows = obj["rows"].aiuxArr().map { r -> r.aiuxArr().mapNotNull { c -> parseTableCell(c) } }
                AISurfaceNode.Table(
                    style,
                    headers = headers,
                    columns = columns,
                    rows = rows,
                    caption = obj["caption"]?.aiuxString(),
                )
            }
            "button" -> {
                val action = AIUXAction.fromJson(obj["action"] as? JsonObject) ?: return null
                AISurfaceNode.Button(
                    style,
                    label = obj["label"]?.aiuxString() ?: action.id,
                    action = action,
                    variant = when (obj["variant"]?.aiuxString()) {
                        "secondary" -> AIButtonVariant.Secondary
                        "ghost" -> AIButtonVariant.Ghost
                        "destructive" -> AIButtonVariant.Destructive
                        else -> AIButtonVariant.Primary
                    },
                    disabled = obj["disabled"].aiuxBool() ?: false,
                )
            }
            "menu" -> AISurfaceNode.Menu(
                style,
                label = obj["label"]?.aiuxString() ?: "Menu",
                items = obj["items"].aiuxArr().mapNotNull { (it as? JsonObject)?.let { i ->
                    val a = AIUXAction.fromJson(i["action"] as? JsonObject) ?: return@let null
                    AIUXMenuItem(
                        label = i["label"]?.aiuxString() ?: a.id,
                        action = a,
                        icon = i["icon"]?.aiuxString(),
                        disabled = i["disabled"].aiuxBool() ?: false,
                    )
                } },
            )
            "progress" -> AISurfaceNode.Progress(
                style,
                value = obj["value"].aiuxDouble(),
                max = obj["max"].aiuxDouble(),
                label = obj["label"]?.aiuxString(),
            )
            "status" -> AISurfaceNode.Status(
                style,
                text = obj["text"]?.aiuxString() ?: return null,
                tone = parseTone(obj["tone"]?.aiuxString()),
            )
            "input" -> AISurfaceNode.Input(
                style,
                name = obj["name"]?.aiuxString() ?: return null,
                label = obj["label"]?.aiuxString(),
                placeholder = obj["placeholder"]?.aiuxString(),
                value = obj["value"]?.aiuxString(),
                inputType = when (obj["inputType"]?.aiuxString()) {
                    "email" -> AIInputType.Email
                    "number" -> AIInputType.Number
                    "password" -> AIInputType.Password
                    "url" -> AIInputType.Url
                    else -> AIInputType.Text
                },
                required = obj["required"].aiuxBool() ?: false,
                disabled = obj["disabled"].aiuxBool() ?: false,
                errorText = obj["errorText"]?.aiuxString(),
            )
            "textarea" -> AISurfaceNode.TextArea(
                style,
                name = obj["name"]?.aiuxString() ?: return null,
                label = obj["label"]?.aiuxString(),
                placeholder = obj["placeholder"]?.aiuxString(),
                value = obj["value"]?.aiuxString(),
                rows = obj["rows"].aiuxInt(),
                required = obj["required"].aiuxBool() ?: false,
                disabled = obj["disabled"].aiuxBool() ?: false,
                errorText = obj["errorText"]?.aiuxString(),
            )
            "select" -> AISurfaceNode.Select(
                style,
                name = obj["name"]?.aiuxString() ?: return null,
                options = obj["options"].aiuxArr().mapNotNull { (it as? JsonObject)?.let { o ->
                    val v = o["value"]?.aiuxString() ?: return@let null
                    AIUXSelectOption(o["label"]?.aiuxString() ?: v, v)
                } },
                label = obj["label"]?.aiuxString(),
                placeholder = obj["placeholder"]?.aiuxString(),
                value = obj["value"]?.aiuxString(),
                required = obj["required"].aiuxBool() ?: false,
                disabled = obj["disabled"].aiuxBool() ?: false,
                errorText = obj["errorText"]?.aiuxString(),
            )
            "checkbox" -> AISurfaceNode.Checkbox(
                style,
                name = obj["name"]?.aiuxString() ?: return null,
                label = obj["label"]?.aiuxString() ?: return null,
                checked = obj["checked"].aiuxBool() ?: false,
                required = obj["required"].aiuxBool() ?: false,
                disabled = obj["disabled"].aiuxBool() ?: false,
                errorText = obj["errorText"]?.aiuxString(),
            )
            "radio" -> AISurfaceNode.Radio(
                style,
                name = obj["name"]?.aiuxString() ?: return null,
                label = obj["label"]?.aiuxString(),
                options = parseSelectOptions(obj),
                value = obj["value"]?.aiuxString(),
                required = obj["required"].aiuxBool() ?: false,
                disabled = obj["disabled"].aiuxBool() ?: false,
                errorText = obj["errorText"]?.aiuxString(),
            )
            "field" -> AISurfaceNode.Field(
                style,
                children = children(),
                label = obj["label"]?.aiuxString(),
                helperText = obj["helperText"]?.aiuxString(),
                required = obj["required"].aiuxBool() ?: false,
                disabled = obj["disabled"].aiuxBool() ?: false,
                errorText = obj["errorText"]?.aiuxString(),
            )
            "form" -> {
                val submit = AIUXAction.fromJson(obj["submit"] as? JsonObject)
                    ?: return AISurfaceNode.UnknownNode(style, type, obj)
                AISurfaceNode.Form(
                    style,
                    children = children(),
                    submit = submit,
                    submitLabel = obj["submitLabel"]?.aiuxString(),
                    disabled = obj["disabled"].aiuxBool() ?: false,
                )
            }
            "listItem" -> AISurfaceNode.ListItem(
                style,
                title = obj["title"]?.aiuxString() ?: return null,
                subtitle = obj["subtitle"]?.aiuxString(),
                icon = obj["icon"]?.aiuxString(),
                action = AIUXAction.fromJson(obj["action"] as? JsonObject),
                children = children(),
            )
            "custom" -> AISurfaceNode.Custom(
                style,
                kind = obj["kind"]?.aiuxString() ?: "",
                props = obj["props"] as? JsonObject ?: JsonObject(emptyMap()),
                children = children(),
            )
            "actions" -> AISurfaceNode.Actions(style, children())
            else -> AISurfaceNode.UnknownNode(style, type, obj)
        }
    }

    fun parseStyle(obj: JsonObject): AIUXNodeStyle = AIUXNodeStyle(
        gap = parseGap(obj["gap"]?.aiuxString()),
        padding = parsePadding(obj["padding"]?.aiuxString()),
        radius = parseRadius(obj["radius"]?.aiuxString()),
        alignment = parseAlignment(obj["alignment"]?.aiuxString()),
        distribution = parseDistribution(obj["distribution"]?.aiuxString()),
    )

    fun parseGap(v: String?): AIGap? = when (v) {
        "xs" -> AIGap.Xs; "sm" -> AIGap.Sm; "md" -> AIGap.Md; "lg" -> AIGap.Lg; "xl" -> AIGap.Xl; else -> null
    }
    fun parsePadding(v: String?): AIPadding? = when (v) {
        "none" -> AIPadding.None; "xs" -> AIPadding.Xs; "sm" -> AIPadding.Sm; "md" -> AIPadding.Md; "lg" -> AIPadding.Lg; else -> null
    }
    fun parseRadius(v: String?): AIRadius? = when (v) {
        "sm" -> AIRadius.Sm; "md" -> AIRadius.Md; "lg" -> AIRadius.Lg; "full" -> AIRadius.Full; else -> null
    }
    fun parseAlignment(v: String?): AIAlignment? = when (v) {
        "start" -> AIAlignment.Start; "center" -> AIAlignment.Center; "end" -> AIAlignment.End; "stretch" -> AIAlignment.Stretch; else -> null
    }
    fun parseDistribution(v: String?): AIDistribution? = when (v) {
        "start" -> AIDistribution.Start; "center" -> AIDistribution.Center; "end" -> AIDistribution.End
        "spaceBetween" -> AIDistribution.SpaceBetween; "spaceAround" -> AIDistribution.SpaceAround
        "spaceEvenly" -> AIDistribution.SpaceEvenly; else -> null
    }
    fun parseTextVariant(v: String?): AITextVariant = when (v) {
        "caption" -> AITextVariant.Caption; "label" -> AITextVariant.Label
        "emphasis" -> AITextVariant.Emphasis; "strong" -> AITextVariant.Strong
        "muted" -> AITextVariant.Muted; else -> AITextVariant.Body
    }
    fun parseTone(v: String?): AITone = when (v) {
        "accent" -> AITone.Accent; "muted" -> AITone.Muted; "success" -> AITone.Success
        "warning" -> AITone.Warning; "destructive" -> AITone.Destructive; else -> AITone.Default
    }

    private fun parseSelectOptions(obj: JsonObject): List<AIUXSelectOption> =
        obj["options"].aiuxArr().mapNotNull { (it as? JsonObject)?.let { o ->
            val v = o["value"]?.aiuxString() ?: return@let null
            AIUXSelectOption(o["label"]?.aiuxString() ?: v, v)
        } }

    private fun parseTableCell(el: JsonElement): AITableCell? {
        el.aiuxString()?.let { return AITableCell.Text(it) }
        val obj = el as? JsonObject ?: return null
        return when (obj["type"]?.aiuxString() ?: "text") {
            "text" -> AITableCell.Text(obj["text"]?.aiuxString() ?: "")
            "number" -> AITableCell.Number(obj["value"].aiuxDouble() ?: 0.0)
            "badge" -> AITableCell.Badge(
                obj["text"]?.aiuxString() ?: "",
                obj["tone"]?.aiuxString()?.let { parseTone(it) },
            )
            "action" -> AIUXAction.fromJson(obj["action"] as? JsonObject)?.let {
                AITableCell.Action(obj["label"]?.aiuxString() ?: it.id, it)
            }
            else -> AITableCell.Text("")
        }
    }

    /** Parse an inline surface descriptor `{id, root}` (ADR 0007). */
    fun parseDescriptor(obj: JsonObject?): AIUXSurfaceDescriptor? {
        obj ?: return null
        val id = obj["id"]?.aiuxString() ?: return null
        val root = parse(obj["root"] as? JsonObject) ?: return null
        return AIUXSurfaceDescriptor(id, root)
    }
}
