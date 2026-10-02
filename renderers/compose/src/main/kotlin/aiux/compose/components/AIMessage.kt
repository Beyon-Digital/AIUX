package aiux.compose.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import aiux.compose.AIUX
import aiux.compose.model.AIUXAction
import aiux.compose.model.AIUXActions
import aiux.compose.model.AIUXAttachment
import aiux.compose.model.AIUXCitation
import aiux.compose.model.AIUXError
import aiux.compose.model.AIUXMessage
import aiux.compose.model.AIUXPart
import aiux.compose.model.AIUXProgress
import aiux.compose.model.AIUXSnapshot
import aiux.compose.model.AIRole
import aiux.compose.model.AIStatusLevel
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * A message bubble + its typed parts. Pure rendering — all interactions emit
 * [AIUXAction]s upward; the host decides what to execute (plan §23).
 */
@Composable
fun AIMessage(
    message: AIUXMessage,
    snapshot: AIUXSnapshot,
    modifier: Modifier = Modifier,
    onAction: (AIUXAction) -> Unit = {},
) {
    val theme = AIUX.theme
    val isUser = message.role == AIRole.User
    val isSystem = message.role == AIRole.System

    val messageSemantics = Modifier.semantics {
        contentDescription = buildString {
            append(message.role.name.lowercase()).append(" message")
            if (message.streaming) append(", streaming")
        }
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = theme.spacing.lg, vertical = theme.spacing.xs),
        horizontalAlignment = when {
            isUser -> Alignment.End
            isSystem -> Alignment.CenterHorizontally
            else -> Alignment.Start
        },
    ) {
        if (isUser || isSystem) {
            // Bubbles are reserved for user/system — the assistant speaks flat.
            Surface(
                color = if (isUser) theme.colors.userSurface else theme.colors.muted,
                shape = RoundedCornerShape(theme.radii.lg),
                modifier = Modifier
                    .widthIn(max = 560.dp)
                    .then(messageSemantics),
            ) {
                Column(modifier = Modifier.padding(theme.spacing.md)) {
                    message.parts.forEach { part ->
                        AIPart(part = part, message = message, snapshot = snapshot, onAction = onAction)
                    }
                }
            }
        } else {
            Column(
                modifier = Modifier
                    .widthIn(max = 560.dp)
                    .then(messageSemantics)
                    .padding(vertical = theme.spacing.xs),
            ) {
                message.parts.forEach { part ->
                    AIPart(part = part, message = message, snapshot = snapshot, onAction = onAction)
                }
                if (message.streaming) {
                    CircularProgressIndicator(
                        modifier = Modifier
                            .size(14.dp)
                            .padding(top = theme.spacing.xs),
                        strokeWidth = 2.dp,
                        color = theme.colors.mutedForeground,
                    )
                }
            }
        }
    }
}

/** Dispatch on part kind — every protocol part type renders (plan §3). */
@Composable
fun AIPart(
    part: AIUXPart,
    message: AIUXMessage,
    snapshot: AIUXSnapshot,
    onAction: (AIUXAction) -> Unit,
) {
    val theme = AIUX.theme
    when (part) {
        is AIUXPart.Text -> Text(
            text = part.text,
            style = theme.typography.body,
            color = theme.colors.foreground,
        )
        is AIUXPart.Markdown -> AIMarkdown(
            markdown = part.markdown,
            onLink = { url -> onAction(AIUXAction(AIUXActions.CITATION_OPEN, buildJsonObject { put("uri", JsonPrimitive(url)) })) },
        )
        is AIUXPart.Code -> AICodeBlock(code = part.code, language = part.language)
        is AIUXPart.Image -> AIAttachmentRow(part.attachment, isImage = true, onAction = onAction)
        is AIUXPart.Attachment -> AIAttachmentRow(part.attachment, isImage = false, onAction = onAction)
        is AIUXPart.Citation -> AICitationRow(part.citation, onAction)
        is AIUXPart.ToolRef -> {
            val tool = snapshot.toolById[part.toolId]
            if (tool != null) {
                AIToolStatus(tool = tool)
            } else {
                AIMissingRef("tool", part.toolId)
            }
        }
        is AIUXPart.ApprovalRef -> {
            val approval = snapshot.approvalById[part.approvalId]
            if (approval != null) {
                AIApproval(approval = approval, onAction = onAction)
            } else {
                AIMissingRef("approval", part.approvalId)
            }
        }
        is AIUXPart.ArtifactRef -> {
            val artifact = snapshot.artifactById[part.artifactId]
            if (artifact != null) {
                AIArtifactPreview(artifact = artifact, onAction = onAction)
            } else {
                AIMissingRef("artifact", part.artifactId)
            }
        }
        is AIUXPart.Status -> AIStatusLine(text = part.text, level = part.level)
        is AIUXPart.Progress -> AIProgressRow(part.progress)
        is AIUXPart.SurfaceRef -> {
            val surface = snapshot.surfaceById[part.surfaceId]
            if (surface != null) {
                AISurface(surface = surface, onAction = onAction)
            } else {
                AIMissingRef("surface", part.surfaceId)
            }
        }
        is AIUXPart.Error -> AIErrorRow(part.error, messageId = message.id, onAction = onAction)
        is AIUXPart.Unknown -> AIUnknownPart(part)
    }
}

@Composable
fun AICodeBlock(code: String, language: String?, modifier: Modifier = Modifier) {
    val theme = AIUX.theme
    val clipboard = LocalClipboardManager.current
    Surface(
        color = theme.colors.codeSurface,
        shape = RoundedCornerShape(theme.radii.md),
        modifier = modifier.fillMaxWidth().padding(vertical = theme.spacing.xs),
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = theme.spacing.sm),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = language?.ifEmpty { "code" } ?: "code",
                    style = theme.typography.caption,
                    color = theme.colors.codeForeground.copy(alpha = 0.7f),
                )
                TextButton(
                    onClick = { clipboard.setText(AnnotatedString(code)) },
                ) { Text("Copy", style = theme.typography.caption, color = theme.colors.codeForeground.copy(alpha = 0.7f)) }
            }
            Text(
                text = code,
                style = theme.typography.code,
                color = theme.colors.codeForeground,
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = theme.spacing.sm, vertical = theme.spacing.xs),
            )
        }
    }
}

@Composable
private fun AIAttachmentRow(attachment: AIUXAttachment, isImage: Boolean, onAction: (AIUXAction) -> Unit) {
    val theme = AIUX.theme
    Surface(
        color = theme.colors.surfaceElevated,
        shape = RoundedCornerShape(theme.radii.md),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = theme.spacing.xs)
            .clickable {
                onAction(
                    AIUXAction(
                        if (isImage) AIUXActions.IMAGE_OPEN else AIUXActions.ATTACHMENT_OPEN,
                        buildJsonObject {
                            attachment.uri?.let { put("uri", JsonPrimitive(it)) }
                            attachment.name?.let { put("name", JsonPrimitive(it)) }
                        },
                    ),
                )
            }
            .semantics {
                contentDescription = "attachment ${attachment.name ?: attachment.uri ?: ""}"
            },
    ) {
        Row(
            modifier = Modifier.padding(theme.spacing.sm),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(theme.spacing.sm),
        ) {
            Icon(
                imageVector = if (isImage) Icons.Default.Info else Icons.Default.CheckCircle,
                contentDescription = null,
                tint = theme.colors.accent,
                modifier = Modifier.size(20.dp),
            )
            Column {
                Text(
                    attachment.name ?: attachment.uri ?: "attachment",
                    style = theme.typography.label,
                    color = theme.colors.foreground,
                )
                Text(
                    listOfNotNull(
                        attachment.mimeType,
                        attachment.sizeBytes?.let { "${it / 1024} KB" },
                    ).joinToString(" · "),
                    style = theme.typography.caption,
                    color = theme.colors.mutedForeground,
                )
            }
        }
    }
}

@Composable
private fun AICitationRow(citation: AIUXCitation, onAction: (AIUXAction) -> Unit) {
    val theme = AIUX.theme
    Surface(
        color = theme.colors.surfaceElevated,
        shape = RoundedCornerShape(theme.radii.sm),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = theme.spacing.xs)
            .clickable(enabled = citation.uri != null) {
                onAction(
                    AIUXAction(
                        AIUXActions.CITATION_OPEN,
                        buildJsonObject {
                            citation.uri?.let { put("uri", JsonPrimitive(it)) }
                            citation.id?.let { put("citationId", JsonPrimitive(it)) }
                        },
                    ),
                )
            }
            .semantics { contentDescription = "citation ${citation.title ?: citation.source ?: ""}" },
    ) {
        Row(modifier = Modifier.padding(theme.spacing.sm), verticalAlignment = Alignment.Top) {
            Text("❝", style = theme.typography.label, color = theme.colors.accent)
            Column(modifier = Modifier.padding(start = theme.spacing.sm)) {
                Text(
                    citation.title ?: citation.source ?: "source",
                    style = theme.typography.label,
                    color = theme.colors.accent,
                )
                citation.snippet?.let {
                    Text(it, style = theme.typography.caption, color = theme.colors.mutedForeground)
                }
            }
        }
    }
}

@Composable
private fun AIStatusLine(text: String, level: AIStatusLevel?) {
    val theme = AIUX.theme
    val (icon, tint) = when (level) {
        AIStatusLevel.Success -> Icons.Default.CheckCircle to theme.colors.success
        AIStatusLevel.Warning -> Icons.Default.Warning to theme.colors.warning
        AIStatusLevel.Error -> Icons.Default.Warning to theme.colors.destructive
        else -> Icons.Default.Info to theme.colors.mutedForeground
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = theme.spacing.xs)
            .semantics { contentDescription = "status ${level?.name ?: "info"}: $text" },
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(16.dp))
        Text(
            text,
            style = theme.typography.caption,
            color = tint,
            modifier = Modifier.padding(start = theme.spacing.sm),
        )
    }
}

@Composable
private fun AIProgressRow(progress: AIUXProgress) {
    val theme = AIUX.theme
    Column(modifier = Modifier.fillMaxWidth().padding(vertical = theme.spacing.xs)) {
        progress.label?.let {
            Text(it, style = theme.typography.caption, color = theme.colors.mutedForeground)
        }
        val fraction = progress.fraction
        if (fraction != null) {
            LinearProgressIndicator(
                progress = { fraction },
                modifier = Modifier.fillMaxWidth(),
            )
        } else {
            LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        }
    }
}

@Composable
private fun AIErrorRow(error: AIUXError, messageId: String, onAction: (AIUXAction) -> Unit) {
    val theme = AIUX.theme
    Surface(
        color = theme.colors.destructive.copy(alpha = 0.08f),
        shape = RoundedCornerShape(theme.radii.sm),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = theme.spacing.xs)
            .semantics { contentDescription = "error ${error.code}: ${error.message}" },
    ) {
        Row(
            modifier = Modifier.padding(theme.spacing.sm),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Default.Warning, contentDescription = null, tint = theme.colors.destructive, modifier = Modifier.size(18.dp))
            Column(modifier = Modifier.weight(1f).padding(horizontal = theme.spacing.sm)) {
                Text(error.message.ifEmpty { error.code }, style = theme.typography.label, color = theme.colors.destructive)
                Text(error.code, style = theme.typography.caption, color = theme.colors.mutedForeground)
            }
            if (error.retryable == true) {
                TextButton(
                    onClick = {
                        onAction(
                            AIUXAction(
                                AIUXActions.ERROR_RETRY,
                                buildJsonObject {
                                    put("messageId", JsonPrimitive(messageId))
                                    put("code", JsonPrimitive(error.code))
                                },
                            ),
                        )
                    },
                ) { Text("Retry", style = theme.typography.label) }
            }
        }
    }
}

@Composable
private fun AIMissingRef(kind: String, id: String) {
    val theme = AIUX.theme
    Text(
        "[$kind:$id]",
        style = theme.typography.caption,
        color = theme.colors.mutedForeground,
        modifier = Modifier.semantics { contentDescription = "missing $kind reference $id" },
    )
}

@Composable
private fun AIUnknownPart(part: AIUXPart.Unknown) {
    val theme = AIUX.theme
    Surface(
        color = theme.colors.muted,
        shape = RoundedCornerShape(theme.radii.sm),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = theme.spacing.xs),
    ) {
        Text(
            "Unsupported part: ${part.type}",
            style = theme.typography.caption,
            color = theme.colors.mutedForeground,
            modifier = Modifier
                .padding(theme.spacing.sm)
                .semantics { contentDescription = "unsupported part type ${part.type}" },
        )
    }
}
