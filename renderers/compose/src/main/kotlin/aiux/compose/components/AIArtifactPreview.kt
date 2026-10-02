package aiux.compose.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import aiux.compose.AIUX
import aiux.compose.model.AIUXAction
import aiux.compose.model.AIUXActions
import aiux.compose.model.AIUXArtifact
import kotlinx.serialization.json.JsonPrimitive

/** Artifact card: kind + title + revision, content preview (code monospace). */
@Composable
fun AIArtifactPreview(
    artifact: AIUXArtifact,
    modifier: Modifier = Modifier,
    onAction: (AIUXAction) -> Unit = {},
) {
    val theme = AIUX.theme
    Surface(
        color = theme.colors.surfaceElevated,
        shape = RoundedCornerShape(theme.radii.md),
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = theme.spacing.xs)
            .clickable {
                onAction(
                    AIUXAction(
                        AIUXActions.ARTIFACT_OPEN,
                        kotlinx.serialization.json.buildJsonObject {
                            put("artifactId", JsonPrimitive(artifact.id))
                            put("kind", JsonPrimitive(artifact.kind))
                            artifact.uri?.let { put("uri", JsonPrimitive(it)) }
                        },
                    ),
                )
            }
            .semantics {
                contentDescription = "artifact ${artifact.title ?: artifact.id} (${artifact.kind}) revision ${artifact.revision}"
            },
    ) {
        Column(modifier = Modifier.padding(theme.spacing.sm)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    artifact.kind.uppercase(),
                    style = theme.typography.caption,
                    color = theme.colors.accent,
                )
                Text(
                    artifact.title ?: artifact.id,
                    style = theme.typography.label,
                    color = theme.colors.foreground,
                    modifier = Modifier.padding(start = theme.spacing.sm).weight(1f),
                )
                Text(
                    "r${artifact.revision}",
                    style = theme.typography.caption,
                    color = theme.colors.mutedForeground,
                )
            }
            artifact.content?.let { content ->
                Surface(
                    color = theme.colors.muted,
                    shape = RoundedCornerShape(theme.radii.sm),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = theme.spacing.sm),
                ) {
                    Text(
                        text = content.take(800),
                        style = theme.typography.code,
                        color = theme.colors.foreground,
                        modifier = Modifier
                            .heightIn(max = 160.dp)
                            .verticalScroll(rememberScrollState())
                            .padding(theme.spacing.sm),
                    )
                }
            }
        }
    }
}
