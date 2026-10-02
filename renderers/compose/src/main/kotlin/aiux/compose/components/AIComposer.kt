package aiux.compose.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
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
import androidx.compose.ui.draw.shadow
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
 * Prompt composer (§23), styled after the ChatGPT mobile composer: a
 * floating row — standalone `+` circle beside a rounded pill containing the
 * input with a monochrome circular action button at its right edge
 * (up-arrow to send, stop-square while a run is active). The row floats
 * above the content with margins + soft elevation rather than docking as
 * a bottom bar, and its contents center-align vertically. Emits actions
 * upward only.
 */
@Composable
fun AIComposer(
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    running: Boolean = false,
    placeholder: String = "Message",
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
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Unified floating pill: + | input | action circle — the current
        // ChatGPT mobile composer shape (borderless, shadowed).
        Surface(
            color = theme.colors.surfaceElevated,
            shape = RoundedCornerShape(28.dp),
            shadowElevation = 4.dp,
            modifier = Modifier.weight(1f),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(start = theme.spacing.sm, end = theme.spacing.xs),
            ) {
                Icon(
                    Icons.Default.Add,
                    contentDescription = "add attachment",
                    tint = theme.colors.foreground,
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .clickable(enabled = enabled) { onAction(AIUXAction(AIUXActions.COMPOSER_ATTACH)) }
                        .padding(theme.spacing.sm),
                )
                TextField(
                    value = text,
                    onValueChange = { text = it },
                    modifier = Modifier
                        .weight(1f)
                        .semantics { contentDescription = "message input" },
                    placeholder = {
                        Text(placeholder, style = theme.typography.body, color = theme.colors.mutedForeground)
                    },
                    textStyle = theme.typography.body,
                    enabled = enabled,
                    maxLines = 4,
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
                ComposerActionButton(
                    running = running,
                    canSend = canSend,
                    onSend = { send() },
                    onCancel = { onAction(AIUXAction(AIUXActions.COMPOSER_CANCEL)) },
                )
            }
        }
    }
}

/** Monochrome circular action: white-on-black up-arrow, or stop square. */
@Composable
private fun ComposerActionButton(
    running: Boolean,
    canSend: Boolean,
    onSend: () -> Unit,
    onCancel: () -> Unit,
) {
    val theme = AIUX.theme
    val active = running || canSend
    Box(
        modifier = Modifier
            .padding(vertical = theme.spacing.xs)
            .size(36.dp)
            .clip(CircleShape)
            .background(if (active) theme.colors.accent else theme.colors.muted)
            .clickable(enabled = active) { if (running) onCancel() else onSend() }
            .semantics { contentDescription = if (running) "cancel run" else "send message" },
        contentAlignment = Alignment.Center,
    ) {
        if (running) {
            Box(
                modifier = Modifier
                    .size(12.dp)
                    .background(theme.colors.accentForeground, RoundedCornerShape(3.dp)),
            )
        } else {
            // ChatGPT-style solid up-arrow (icon-extended isn't a dep — drawn).
            UpArrowGlyph(
                color = if (active) theme.colors.accentForeground else theme.colors.mutedForeground,
                modifier = Modifier.size(16.dp),
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
