package aiux.compose.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import aiux.compose.AIUX
import aiux.compose.model.AIToolStatus
import aiux.compose.model.AIUXTool
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Tool invocation line (running/completed/failed per protocol lifecycle),
 * styled after ChatGPT's inline activity rows: status icon + tool name +
 * state — flat, no card. Result payloads render as a nested muted chip.
 */
@Composable
fun AIToolStatus(
    tool: AIUXTool,
    modifier: Modifier = Modifier,
) {
    val theme = AIUX.theme
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = theme.spacing.xs)
            .semantics {
                contentDescription = "tool ${tool.name} ${tool.status.name.lowercase()}"
            },
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            when (tool.status) {
                AIToolStatus.Running -> CircularProgressIndicator(
                    modifier = Modifier.size(16.dp),
                    strokeWidth = 2.dp,
                    color = theme.colors.mutedForeground,
                )
                AIToolStatus.Completed -> Icon(
                    Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = theme.colors.mutedForeground,
                    modifier = Modifier.size(16.dp),
                )
                AIToolStatus.Failed -> Icon(
                    Icons.Default.Warning,
                    contentDescription = null,
                    tint = theme.colors.destructive,
                    modifier = Modifier.size(16.dp),
                )
            }
            Text(
                tool.name,
                style = theme.typography.label,
                color = theme.colors.foreground,
                modifier = Modifier.padding(start = theme.spacing.sm).weight(1f),
            )
            Text(
                tool.status.name.lowercase(),
                style = theme.typography.caption,
                color = theme.colors.mutedForeground,
            )
        }
        tool.progress?.let { p ->
            Column(modifier = Modifier.padding(top = theme.spacing.xs, start = 24.dp)) {
                p.label?.let {
                    Text(it, style = theme.typography.caption, color = theme.colors.mutedForeground)
                }
                val f = p.fraction
                if (f != null) {
                    LinearProgressIndicator(progress = { f }, modifier = Modifier.fillMaxWidth())
                } else {
                    LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                }
            }
        }
        tool.error?.let { e ->
            Text(
                "${e.code}: ${e.message}",
                style = theme.typography.caption,
                color = theme.colors.destructive,
                modifier = Modifier.padding(top = theme.spacing.xs, start = 24.dp),
            )
        }
        tool.result?.let { r ->
            ResultChip(r, Modifier.padding(top = theme.spacing.xs, start = 24.dp))
        }
    }
}

@Composable
private fun ResultChip(result: JsonElement, modifier: Modifier = Modifier) {
    val theme = AIUX.theme
    val summary = when (result) {
        is JsonPrimitive -> result.content
        is JsonObject -> result.entries.joinToString("  ") { (k, v) ->
            "$k=${(v as? JsonPrimitive)?.content ?: v}"
        }.take(140)
        else -> result.toString().take(140)
    }
    if (summary.isNotBlank()) {
        Surface(
            color = theme.colors.muted,
            shape = RoundedCornerShape(theme.radii.sm),
            modifier = modifier.fillMaxWidth(),
        ) {
            Text(
                summary,
                style = theme.typography.caption,
                color = theme.colors.mutedForeground,
                modifier = Modifier.padding(horizontal = theme.spacing.sm, vertical = theme.spacing.xs),
            )
        }
    }
}
