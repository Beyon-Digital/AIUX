package aiux.compose.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import aiux.compose.AIUX
import aiux.compose.model.AIApprovalStatus
import aiux.compose.model.AIUXAction
import aiux.compose.model.AIUXActions
import aiux.compose.model.AIUXApproval
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Approval request card (plan §23): `requested` offers Approve/Reject which
 * emit actions upward for the host to resolve; `approved`, `rejected`,
 * `expired`, `executed` render as clearly-distinguished terminal states and
 * never re-offer execution.
 */
@Composable
fun AIApproval(
    approval: AIUXApproval,
    modifier: Modifier = Modifier,
    onAction: (AIUXAction) -> Unit = {},
) {
    val theme = AIUX.theme
    val pending = approval.status == AIApprovalStatus.Requested

    val containerColor = when (approval.status) {
        AIApprovalStatus.Requested -> theme.colors.surfaceElevated
        AIApprovalStatus.Approved, AIApprovalStatus.Executed -> theme.colors.success.copy(alpha = 0.10f)
        AIApprovalStatus.Rejected -> theme.colors.destructive.copy(alpha = 0.10f)
        AIApprovalStatus.Expired -> theme.colors.muted
    }

    Surface(
        color = containerColor,
        shape = RoundedCornerShape(theme.radii.md),
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = theme.spacing.xs)
            .semantics {
                contentDescription = "approval ${approval.status.name.lowercase()}: ${approval.prompt}"
            },
    ) {
        Column(modifier = Modifier.padding(theme.spacing.md)) {
            Text(
                approval.prompt,
                style = theme.typography.label,
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

            when (approval.status) {
                AIApprovalStatus.Requested -> {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = theme.spacing.sm),
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
                else -> {
                    val (label, tint) = when (approval.status) {
                        AIApprovalStatus.Approved -> "Approved" to theme.colors.success
                        AIApprovalStatus.Executed -> "Executed" to theme.colors.success
                        AIApprovalStatus.Rejected -> "Rejected" to theme.colors.destructive
                        AIApprovalStatus.Expired -> "Expired" to theme.colors.mutedForeground
                        else -> "" to theme.colors.mutedForeground
                    }
                    Row(
                        modifier = Modifier.padding(top = theme.spacing.sm),
                        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                    ) {
                        Text(label, style = theme.typography.label, color = tint)
                        approval.resolution?.resolvedBy?.let {
                            Text(
                                " by $it",
                                style = theme.typography.caption,
                                color = theme.colors.mutedForeground,
                            )
                        }
                    }
                }
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
