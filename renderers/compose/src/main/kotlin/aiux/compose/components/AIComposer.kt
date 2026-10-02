package aiux.compose.components

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import aiux.compose.AIUX
import aiux.compose.model.AIUXAction
import aiux.compose.model.AIUXActions
import kotlinx.serialization.json.JsonPrimitive

/**
 * Prompt composer: input field, send/cancel, IME send action, attachment
 * hook. Emits actions upward only — the host owns event production (§23).
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

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = theme.spacing.lg, vertical = theme.spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(
            onClick = { onAction(AIUXAction(AIUXActions.COMPOSER_ATTACH)) },
            enabled = enabled,
            modifier = Modifier.semantics { contentDescription = "add attachment" },
        ) {
            Icon(Icons.Default.Add, contentDescription = null, tint = theme.colors.mutedForeground)
        }
        OutlinedTextField(
            value = text,
            onValueChange = { text = it },
            modifier = Modifier
                .weight(1f)
                .semantics { contentDescription = "message input" },
            placeholder = { Text(placeholder, style = theme.typography.body, color = theme.colors.mutedForeground) },
            textStyle = theme.typography.body,
            enabled = enabled,
            maxLines = 4,
            shape = RoundedCornerShape(theme.radii.lg),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
            keyboardActions = KeyboardActions(onSend = { send() }),
        )
        if (running) {
            IconButton(
                onClick = { onAction(AIUXAction(AIUXActions.COMPOSER_CANCEL)) },
                modifier = Modifier
                    .padding(start = theme.spacing.sm)
                    .semantics { contentDescription = "cancel run" },
            ) {
                Icon(Icons.Default.Close, contentDescription = null, tint = theme.colors.destructive)
            }
        } else {
            FilledIconButton(
                onClick = { send() },
                enabled = enabled && text.isNotBlank(),
                modifier = Modifier
                    .padding(start = theme.spacing.sm)
                    .size(40.dp)
                    .semantics { contentDescription = "send message" },
                colors = IconButtonDefaults.filledIconButtonColors(
                    containerColor = theme.colors.accent,
                    contentColor = theme.colors.accentForeground,
                ),
            ) {
                Icon(Icons.AutoMirrored.Filled.Send, contentDescription = null, modifier = Modifier.size(18.dp))
            }
        }
    }
}
