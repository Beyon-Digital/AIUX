package aiux.compose.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import aiux.compose.AIUX
import aiux.compose.model.AIApprovalStatus
import aiux.compose.model.AIUXAction
import aiux.compose.model.AIUXActions
import aiux.compose.model.AIUXApproval
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Approval request (plan §23), styled after ChatGPT's confirmation surfaces:
 * `requested` is a thin-outlined card with prompt + Approve (filled, accent)
 * / Reject (outlined) actions; `approved`, `rejected`, `expired`, `executed`
 * render as flat status rows and never re-offer execution.
 */
@Composable
fun AIApproval(
    approval: AIUXApproval,
    modifier: Modifier = Modifier,
    onAction: (AIUXAction) -> Unit = {},
) {
    val theme = AIUX.theme

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = theme.spacing.xs)
            .semantics {
                contentDescription = "approval ${approval.status.name.lowercase()}: ${approval.prompt}"
            },
    ) {
        if (approval.status == AIApprovalStatus.Requested) {
            Surface(
                color = theme.colors.surface,
                shape = RoundedCornerShape(theme.radii.md),
                border = BorderStroke(1.dp, theme.colors.border),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(modifier = Modifier.padding(theme.spacing.md)) {
                    Text(
                        approval.prompt,
                        style = theme.typography.title,
                        color = theme.colors.foreground,
                    )
                    approval.description?.let {
                        Text(
                            it,
                            style = theme.typography.caption,
                            color = theme.colors.mutedForeground,
                            modifier = Modifier.padding(top = theme.spacing.xs),
                        )
                    }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = theme.spacing.md),
                        horizontalArrangement = Arrangement.spacedBy(theme.spacing.sm, Alignment.End),
                    ) {
                        OutlinedButton(
                            onClick = {
                                onAction(
                                    AIUXAction(
                                        AIUXActions.APPROVAL_REJECT,
                                        buildPayload(approval),
                                    ),
                                )
                            },
                        ) { Text("Reject", style = theme.typography.label) }
                        Button(
                            onClick = {
                                onAction(
                                    AIUXAction(
                                        AIUXActions.APPROVAL_APPROVE,
                                        buildPayload(approval),
                                    ),
                                )
                            },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = theme.colors.accent,
                                contentColor = theme.colors.accentForeground,
                            ),
                        ) { Text("Approve", style = theme.typography.label) }
                    }
                }
            }
        } else {
            // Terminal states: flat status row — icon + label + resolver.
            val (label, icon, tint) = when (approval.status) {
                AIApprovalStatus.Approved -> Triple("Approved", Icons.Default.CheckCircle, theme.colors.success)
                AIApprovalStatus.Executed -> Triple("Executed", Icons.Default.CheckCircle, theme.colors.success)
                AIApprovalStatus.Rejected -> Triple("Rejected", Icons.Default.Close, theme.colors.destructive)
                AIApprovalStatus.Expired -> Triple("Expired", Icons.Default.Info, theme.colors.mutedForeground)
                else -> Triple(approval.status.name, Icons.Default.Info, theme.colors.mutedForeground)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    icon,
                    contentDescription = null,
                    tint = tint,
                    modifier = Modifier.size(16.dp),
                )
                Text(
                    label,
                    style = theme.typography.label,
                    color = tint,
                    modifier = Modifier.padding(start = theme.spacing.sm),
                )
                approval.resolution?.resolvedBy?.let {
                    Text(
                        " by $it",
                        style = theme.typography.caption,
                        color = theme.colors.mutedForeground,
                    )
                }
            }
            approval.description?.let {
                Text(
                    it,
                    style = theme.typography.caption,
                    color = theme.colors.mutedForeground,
                    modifier = Modifier.padding(start = 24.dp, top = theme.spacing.xs),
                )
            }
        }
    }
}

private fun buildPayload(approval: AIUXApproval): JsonObject =
    kotlinx.serialization.json.buildJsonObject {
        put("approvalId", JsonPrimitive(approval.id))
        approval.action?.let { a ->
            put("actionId", JsonPrimitive(a.id))
            put("actionPayload", a.payload)
        }
    }
