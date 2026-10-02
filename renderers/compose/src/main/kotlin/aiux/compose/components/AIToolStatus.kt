package aiux.compose.components

import androidx.compose.foundation.layout.Arrangement
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

/** Tool invocation card: running/completed/failed per protocol lifecycle. */
@Composable
fun AIToolStatus(
    tool: AIUXTool,
    modifier: Modifier = Modifier,
) {
    val theme = AIUX.theme
    Surface(
        color = theme.colors.surfaceElevated,
        shape = RoundedCornerShape(theme.radii.md),
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = theme.spacing.xs)
            .semantics {
                contentDescription = "tool ${tool.name} ${tool.status.name.lowercase()}"
            },
    ) {
        Column(modifier = Modifier.padding(theme.spacing.sm)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                when (tool.status) {
                    AIToolStatus.Running -> CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        strokeWidth = 2.dp,
                        color = theme.colors.accent,
                    )
                    AIToolStatus.Completed -> Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = theme.colors.success,
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
                Column(modifier = Modifier.padding(top = theme.spacing.xs)) {
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
                    modifier = Modifier.padding(top = theme.spacing.xs),
                )
            }
            tool.result?.let { r ->
                ResultSummary(r, Modifier.padding(top = theme.spacing.xs))
            }
        }
    }
}

@Composable
private fun ResultSummary(result: JsonElement, modifier: Modifier = Modifier) {
    val theme = AIUX.theme
    val summary = when (result) {
        is JsonPrimitive -> result.content
        is JsonObject -> result.entries.joinToString("  ") { (k, v) ->
            "$k=${(v as? JsonPrimitive)?.content ?: v}"
        }.take(140)
        else -> result.toString().take(140)
    }
    if (summary.isNotBlank()) {
        Text(
            summary,
            style = theme.typography.caption,
            color = theme.colors.mutedForeground,
            modifier = modifier,
        )
    }
}
