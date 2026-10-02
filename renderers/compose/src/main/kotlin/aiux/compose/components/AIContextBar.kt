package aiux.compose.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import aiux.compose.AIUX
import aiux.compose.model.AIUXAction
import aiux.compose.model.AIUXActions
import aiux.compose.model.AIUXContextEntity
import kotlinx.serialization.json.JsonPrimitive

/** Context entity chips (plan §3 context entities / §14 context chip). */
@Composable
fun AIContextBar(
    context: List<AIUXContextEntity>,
    modifier: Modifier = Modifier,
    onAction: (AIUXAction) -> Unit = {},
) {
    if (context.isEmpty()) return
    val theme = AIUX.theme
    Row(
        modifier = modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = theme.spacing.lg, vertical = theme.spacing.xs),
        horizontalArrangement = Arrangement.spacedBy(theme.spacing.sm),
    ) {
        context.forEach { entity ->
            Surface(
                color = theme.colors.surfaceElevated,
                shape = RoundedCornerShape(theme.radii.radius("full")),
                modifier = Modifier
                    .clickable {
                        onAction(
                            AIUXAction(
                                AIUXActions.CONTEXT_OPEN,
                                kotlinx.serialization.json.buildJsonObject {
                                    put("contextId", JsonPrimitive(entity.id))
                                    put("kind", JsonPrimitive(entity.kind))
                                    entity.uri?.let { put("uri", JsonPrimitive(it)) }
                                },
                            ),
                        )
                    }
                    .semantics { contentDescription = "context ${entity.kind}: ${entity.label}" },
            ) {
                Row(modifier = Modifier.padding(horizontal = theme.spacing.sm, vertical = theme.spacing.xs)) {
                    Text(
                        entity.kind,
                        style = theme.typography.caption,
                        color = theme.colors.accent,
                    )
                    Text(
                        entity.label,
                        style = theme.typography.caption,
                        color = theme.colors.foreground,
                        modifier = Modifier.padding(start = theme.spacing.xs),
                    )
                }
            }
        }
    }
}
