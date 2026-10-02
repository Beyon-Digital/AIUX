package aiux.compose.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Star
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import aiux.compose.AIUX
import aiux.compose.model.AIUXAction
import aiux.compose.model.AIUXActions
import kotlinx.serialization.json.JsonPrimitive

/**
 * Prompt composer (§23), styled after the current ChatGPT mobile composer:
 * one floating rounded surface, the text input in its top region, and a
 * controls row pinned to the bottom — `+` attach on the left, and on the
 * right an accent-ringed tools toggle, an outline mic, and the filled
 * action circle (waveform → voice mode while empty, up-arrow → send with
 * text, square → stop while a run is active). Emits actions upward only.
 *
 * [toolbar] hides built-in controls and appends custom tools — see
 * [AIComposerToolbar].
 */
@Composable
fun AIComposer(
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    running: Boolean = false,
    placeholder: String = "Message",
    toolbar: AIComposerToolbar = AIComposerToolbar.Default,
    onAction: (AIUXAction) -> Unit = {},
) {
    val theme = AIUX.theme
    var text by rememberSaveable { mutableStateOf("") }

    fun send() {
        val t = text.trim()
        if (t.isEmpty() || !enabled) return
        text = ""
        onAction(
            AIUXAction(
                AIUXActions.COMPOSER_SEND,
                kotlinx.serialization.json.buildJsonObject { put("text", JsonPrimitive(t)) },
            ),
        )
    }

    val canSend = enabled && text.isNotBlank()

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(
                start = theme.spacing.md,
                end = theme.spacing.md,
                top = theme.spacing.xs,
                bottom = theme.spacing.md,
            ),
    ) {
        Surface(
            color = theme.colors.inputSurface,
            shape = RoundedCornerShape(30.dp),
            shadowElevation = 2.dp,
            modifier = Modifier.weight(1f),
        ) {
            Column(
                modifier = Modifier.padding(
                    start = theme.spacing.md,
                    end = theme.spacing.md,
                    top = theme.spacing.sm,
                    bottom = theme.spacing.sm,
                ),
            ) {
                TextField(
                    value = text,
                    onValueChange = { text = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 56.dp)
                        .semantics { contentDescription = "message input" },
                    placeholder = {
                        Text(placeholder, style = theme.typography.body, color = theme.colors.mutedForeground)
                    },
                    textStyle = theme.typography.body,
                    enabled = enabled,
                    maxLines = 6,
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        disabledContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                        disabledIndicatorColor = Color.Transparent,
                        cursorColor = theme.colors.accent,
                        focusedTextColor = theme.colors.foreground,
                        unfocusedTextColor = theme.colors.foreground,
                    ),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                    keyboardActions = KeyboardActions(onSend = { send() }),
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = theme.spacing.xs),
                ) {
                    if (toolbar.attach) {
                        Icon(
                            Icons.Default.Add,
                            contentDescription = "add attachment",
                            tint = theme.colors.foreground,
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .clickable(enabled = enabled) {
                                    onAction(AIUXAction(AIUXActions.COMPOSER_ATTACH))
                                }
                                .padding(theme.spacing.sm),
                        )
                    }
                    Spacer(Modifier.weight(1f))
                    if (toolbar.tools) {
                        ComposerGlyphButton(
                            enabled = enabled,
                            contentDescription = "composer tools",
                            onClick = { onAction(AIUXAction(AIUXActions.COMPOSER_TOOLS)) },
                        ) {
                            ToolsGlyph(accent = theme.colors.accent, glyph = theme.colors.foreground)
                        }
                    }
                    if (toolbar.dictate) {
                        Spacer(Modifier.width(theme.spacing.xs))
                        ComposerGlyphButton(
                            enabled = enabled,
                            contentDescription = "dictate",
                            onClick = { onAction(AIUXAction(AIUXActions.COMPOSER_DICTATE)) },
                        ) {
                            MicGlyph(color = theme.colors.foreground)
                        }
                    }
                    toolbar.extra.forEach { tool ->
                        Spacer(Modifier.width(theme.spacing.xs))
                        ComposerGlyphButton(
                            enabled = enabled,
                            contentDescription = tool.contentDescription,
                            onClick = { onAction(AIUXAction(tool.id)) },
                        ) {
                            if (tool.icon != null) {
                                tool.icon.invoke()
                            } else {
                                ComposerGlyphCanvas(
                                    glyph = tool.glyph,
                                    color = theme.colors.foreground,
                                    modifier = Modifier.size(22.dp),
                                )
                            }
                        }
                    }
                    Spacer(Modifier.width(theme.spacing.xs))
                    ComposerActionButton(
                        running = running,
                        canSend = canSend,
                        onSend = { send() },
                        onCancel = { onAction(AIUXAction(AIUXActions.COMPOSER_CANCEL)) },
                        onVoice = { onAction(AIUXAction(AIUXActions.COMPOSER_VOICE)) },
                    )
                }
            }
        }
    }
}

@Composable
private fun ComposerGlyphButton(
    enabled: Boolean,
    contentDescription: String,
    onClick: () -> Unit,
    glyph: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(CircleShape)
            .clickable(enabled = enabled, onClick = onClick)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) { glyph() }
}

/**
 * Filled accent action circle: waveform (voice mode) while the input is
 * empty, up-arrow while it has text, stop square while a run is active.
 */
@Composable
private fun ComposerActionButton(
    running: Boolean,
    canSend: Boolean,
    onSend: () -> Unit,
    onCancel: () -> Unit,
    onVoice: () -> Unit,
) {
    val theme = AIUX.theme
    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(theme.colors.accent)
            .clickable { if (running) onCancel() else if (canSend) onSend() else onVoice() }
            .semantics {
                contentDescription = if (running) "cancel run" else if (canSend) "send message" else "voice mode"
            },
        contentAlignment = Alignment.Center,
    ) {
        if (running) {
            Box(
                modifier = Modifier
                    .size(13.dp)
                    .background(theme.colors.accentForeground, RoundedCornerShape(3.dp)),
            )
        } else if (canSend) {
            UpArrowGlyph(
                color = theme.colors.accentForeground,
                modifier = Modifier.size(18.dp),
            )
        } else {
            WaveformGlyph(
                color = theme.colors.accentForeground,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

/** Accent-ringed circle with a magnifier — the tools toggle. */
@Composable
private fun ToolsGlyph(accent: Color, glyph: Color, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(28.dp)) {
        val w = size.width
        val ring = w * 0.075f
        // Accent ring.
        drawCircle(accent, radius = w * 0.46f, style = Stroke(width = ring))
        // Magnifier lens + handle inside.
        val lensR = w * 0.14f
        val lensC = Offset(w * 0.44f, w * 0.44f)
        drawCircle(glyph, radius = lensR, center = lensC, style = Stroke(width = ring * 0.9f))
        drawLine(
            glyph,
            Offset(lensC.x + lensR * 0.72f, lensC.y + lensR * 0.72f),
            Offset(w * 0.62f, w * 0.62f),
            strokeWidth = ring * 0.9f,
            cap = StrokeCap.Round,
        )
    }
}

/**
 * Stock glyph renderer for [AIComposerGlyph] — every custom tool icon is
 * drawn (material-icons-extended isn't a dependency).
 */
@Composable
internal fun ComposerGlyphCanvas(
    glyph: AIComposerGlyph,
    color: Color,
    modifier: Modifier = Modifier,
) {
    when (glyph) {
        AIComposerGlyph.Mic -> MicGlyph(color = color, modifier = modifier)
        AIComposerGlyph.Plus ->
            Icon(
                Icons.Default.Add,
                contentDescription = null,
                tint = color,
                modifier = modifier,
            )
        AIComposerGlyph.Star ->
            Icon(
                Icons.Default.Star,
                contentDescription = null,
                tint = color,
                modifier = modifier,
            )
        else -> Canvas(modifier = modifier) {
            val w = size.width
            val h = size.height
            val stroke = w * 0.09f
            when (glyph) {
                AIComposerGlyph.Sparkle -> {
                    // Four-point star: two crossed diamonds.
                    drawLine(
                        color,
                        Offset(w * 0.5f, h * 0.08f),
                        Offset(w * 0.5f, h * 0.92f),
                        strokeWidth = stroke,
                        cap = StrokeCap.Round,
                    )
                    drawLine(
                        color,
                        Offset(w * 0.08f, h * 0.5f),
                        Offset(w * 0.92f, h * 0.5f),
                        strokeWidth = stroke,
                        cap = StrokeCap.Round,
                    )
                    drawCircle(
                        color,
                        radius = w * 0.10f,
                        center = Offset(w * 0.5f, h * 0.5f),
                    )
                }
                AIComposerGlyph.Document -> {
                    drawRoundRect(
                        color,
                        topLeft = Offset(w * 0.22f, h * 0.08f),
                        size = Size(w * 0.56f, h * 0.84f),
                        cornerRadius = CornerRadius(w * 0.08f, w * 0.08f),
                        style = Stroke(width = stroke),
                    )
                    for (i in 0..2) {
                        val y = h * (0.30f + i * 0.18f)
                        drawLine(
                            color,
                            Offset(w * 0.34f, y),
                            Offset(w * 0.66f, y),
                            strokeWidth = stroke * 0.8f,
                            cap = StrokeCap.Round,
                        )
                    }
                }
                AIComposerGlyph.Photo -> {
                    drawRoundRect(
                        color,
                        topLeft = Offset(w * 0.10f, h * 0.16f),
                        size = Size(w * 0.80f, h * 0.68f),
                        cornerRadius = CornerRadius(w * 0.10f, w * 0.10f),
                        style = Stroke(width = stroke),
                    )
                    drawCircle(
                        color,
                        radius = w * 0.08f,
                        center = Offset(w * 0.34f, h * 0.38f),
                    )
                    drawLine(
                        color,
                        Offset(w * 0.16f, h * 0.78f),
                        Offset(w * 0.44f, h * 0.50f),
                        strokeWidth = stroke,
                        cap = StrokeCap.Round,
                    )
                    drawLine(
                        color,
                        Offset(w * 0.44f, h * 0.50f),
                        Offset(w * 0.62f, h * 0.66f),
                        strokeWidth = stroke,
                        cap = StrokeCap.Round,
                    )
                    drawLine(
                        color,
                        Offset(w * 0.62f, h * 0.66f),
                        Offset(w * 0.86f, h * 0.46f),
                        strokeWidth = stroke,
                        cap = StrokeCap.Round,
                    )
                }
                AIComposerGlyph.Gear -> {
                    val c = Offset(w * 0.5f, h * 0.5f)
                    drawCircle(color, radius = w * 0.16f, center = c, style = Stroke(width = stroke))
                    for (i in 0 until 8) {
                        val a = Math.toRadians(i * 45.0)
                        drawLine(
                            color,
                            Offset(c.x + kotlin.math.cos(a).toFloat() * w * 0.26f, c.y + kotlin.math.sin(a).toFloat() * w * 0.26f),
                            Offset(c.x + kotlin.math.cos(a).toFloat() * w * 0.44f, c.y + kotlin.math.sin(a).toFloat() * w * 0.44f),
                            strokeWidth = stroke,
                            cap = StrokeCap.Round,
                        )
                    }
                }
                AIComposerGlyph.Globe -> {
                    val c = Offset(w * 0.5f, h * 0.5f)
                    drawCircle(color, radius = w * 0.40f, center = c, style = Stroke(width = stroke))
                    drawOval(
                        color,
                        topLeft = Offset(w * 0.32f, h * 0.10f),
                        size = Size(w * 0.36f, h * 0.80f),
                        style = Stroke(width = stroke * 0.8f),
                    )
                    drawLine(
                        color,
                        Offset(w * 0.12f, h * 0.5f),
                        Offset(w * 0.88f, h * 0.5f),
                        strokeWidth = stroke * 0.8f,
                    )
                }
                AIComposerGlyph.Search -> {
                    val lensR = w * 0.30f
                    val lensC = Offset(w * 0.42f, h * 0.42f)
                    drawCircle(color, radius = lensR, center = lensC, style = Stroke(width = stroke))
                    drawLine(
                        color,
                        Offset(lensC.x + lensR * 0.72f, lensC.y + lensR * 0.72f),
                        Offset(w * 0.90f, h * 0.90f),
                        strokeWidth = stroke,
                        cap = StrokeCap.Round,
                    )
                }
                else -> {}
            }
        }
    }
}

/** Outline microphone glyph (material-icons-extended isn't a dep — drawn). */
@Composable
private fun MicGlyph(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.size(22.dp)) {
        val w = size.width
        val h = size.height
        val stroke = w * 0.085f
        // Capsule body.
        drawRoundRect(
            color,
            topLeft = Offset(w * 0.34f, h * 0.04f),
            size = Size(w * 0.32f, h * 0.52f),
            cornerRadius = CornerRadius(w * 0.16f, w * 0.16f),
            style = Stroke(width = stroke),
        )
        // U-shaped stand arc.
        drawArc(
            color,
            startAngle = 15f,
            sweepAngle = 150f,
            useCenter = false,
            topLeft = Offset(w * 0.15f, h * 0.30f),
            size = Size(w * 0.70f, h * 0.52f),
            style = Stroke(width = stroke, cap = StrokeCap.Round),
        )
        // Stem + base.
        drawLine(
            color,
            Offset(w * 0.5f, h * 0.82f),
            Offset(w * 0.5f, h * 0.97f),
            strokeWidth = stroke,
            cap = StrokeCap.Round,
        )
        drawLine(
            color,
            Offset(w * 0.36f, h * 0.97f),
            Offset(w * 0.64f, h * 0.97f),
            strokeWidth = stroke,
            cap = StrokeCap.Round,
        )
    }
}

/** Voice-mode waveform: five rounded vertical bars. */
@Composable
private fun WaveformGlyph(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val w = size.width
        val h = size.height
        val bar = w * 0.10f
        val heights = floatArrayOf(0.42f, 0.78f, 1f, 0.66f, 0.34f)
        val gap = (w - bar * heights.size) / (heights.size - 1)
        heights.forEachIndexed { i, frac ->
            val bh = h * 0.82f * frac
            drawRoundRect(
                color,
                topLeft = Offset(i * (bar + gap), (h - bh) / 2f),
                size = Size(bar, bh),
                cornerRadius = CornerRadius(bar / 2f, bar / 2f),
            )
        }
    }
}

/** Solid up-arrow glyph drawn with strokes (material-icons-extended free). */
@Composable
private fun UpArrowGlyph(color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val w = size.width
        val stroke = w * 0.14f
        val c = center
        // Shaft.
        drawLine(
            color,
            Offset(c.x, w * 0.84f),
            Offset(c.x, w * 0.16f),
            strokeWidth = stroke,
            cap = StrokeCap.Round,
        )
        // Arrowhead.
        drawLine(
            color,
            Offset(c.x, w * 0.16f),
            Offset(w * 0.28f, w * 0.44f),
            strokeWidth = stroke,
            cap = StrokeCap.Round,
        )
        drawLine(
            color,
            Offset(c.x, w * 0.16f),
            Offset(w * 0.72f, w * 0.44f),
            strokeWidth = stroke,
            cap = StrokeCap.Round,
        )
    }
}
