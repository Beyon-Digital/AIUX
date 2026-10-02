package aiux.compose.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import aiux.compose.AIUX
import aiux.compose.AIUXTheme
import aiux.compose.model.AIAlignment
import aiux.compose.model.AIButtonVariant
import aiux.compose.model.AIDistribution
import aiux.compose.model.AIGap
import aiux.compose.model.AIIconSize
import aiux.compose.model.AIInputType
import aiux.compose.model.AIPadding
import aiux.compose.model.AIRadius
import aiux.compose.model.AISurfaceNode
import aiux.compose.model.AITextVariant
import aiux.compose.model.AITone
import aiux.compose.model.AIUXAction
import aiux.compose.model.AIUXActions
import aiux.compose.model.AIUXSurface
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Renders an AIUX Surface tree (plan §6): the fixed semantic primitive set
 * mapped onto Material3. Layout attrs are semantic values only (ADR 0006);
 * unknown node types degrade to a placeholder (plan §21).
 */
@Composable
fun AISurface(
    surface: AIUXSurface,
    modifier: Modifier = Modifier,
    onAction: (AIUXAction) -> Unit = {},
) {
    SurfaceNodeView(node = surface.root, modifier = modifier, onAction = onAction)
}

@Composable
fun SurfaceNodeView(
    node: AISurfaceNode,
    modifier: Modifier = Modifier,
    onAction: (AIUXAction) -> Unit = {},
) {
    val theme = AIUX.theme
    val m = modifier.nodeStyle(node.style, theme)
    when (node) {
        is AISurfaceNode.Surface -> Column(
            modifier = m.fillMaxWidth(),
            verticalArrangement = node.arrangement(theme),
            horizontalAlignment = node.horizontalAlignment(),
        ) { node.children.forEach { SurfaceNodeView(it, onAction = onAction) } }

        is AISurfaceNode.Card -> Card(
            modifier = m.fillMaxWidth(),
            shape = RoundedCornerShape(theme.radii.radius(node.style.radius?.name?.lowercase() ?: "md")),
        ) {
            Column(
                modifier = Modifier.padding(theme.spacing.padding(node.style.padding?.name?.lowercase() ?: "md")),
                verticalArrangement = node.arrangement(theme),
                horizontalAlignment = node.horizontalAlignment(),
            ) {
                node.title?.let {
                    Text(it, style = theme.typography.title, color = theme.colors.foreground)
                }
                node.children.forEach { SurfaceNodeView(it, onAction = onAction) }
            }
        }

        is AISurfaceNode.Stack -> if (node.direction == aiux.compose.model.AIStackDirection.Horizontal) {
            Row(
                modifier = m.fillMaxWidth(),
                horizontalArrangement = node.horizontalArrangement(theme),
                verticalAlignment = node.verticalAlignment(),
            ) { node.children.forEach { SurfaceNodeView(it, onAction = onAction) } }
        } else {
            Column(
                modifier = m.fillMaxWidth(),
                verticalArrangement = node.arrangement(theme),
                horizontalAlignment = node.horizontalAlignment(),
            ) { node.children.forEach { SurfaceNodeView(it, onAction = onAction) } }
        }

        is AISurfaceNode.Row -> Row(
            modifier = m.fillMaxWidth(),
            horizontalArrangement = node.horizontalArrangement(theme),
            verticalAlignment = node.verticalAlignment(),
        ) { node.children.forEach { SurfaceNodeView(it, onAction = onAction) } }

        is AISurfaceNode.Grid -> {
            val cols = node.columns.coerceAtLeast(1)
            Column(modifier = m.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(theme.spacing.gap(node.style.gap?.name?.lowercase()))) {
                node.children.chunked(cols).forEach { rowItems ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(theme.spacing.gap(node.style.gap?.name?.lowercase())),
                    ) {
                        rowItems.forEach { SurfaceNodeView(it, modifier = Modifier.weight(1f), onAction = onAction) }
                        repeat(cols - rowItems.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }

        is AISurfaceNode.Heading -> Text(
            node.text,
            modifier = m,
            style = when (node.level) {
                1 -> theme.typography.heading
                2 -> theme.typography.title
                else -> theme.typography.label.copy(fontWeight = FontWeight.Bold)
            },
            color = theme.colors.foreground,
        )

        is AISurfaceNode.Text -> Text(
            node.text,
            modifier = m,
            style = when (node.variant) {
                AITextVariant.Caption -> theme.typography.caption
                AITextVariant.Label -> theme.typography.label
                AITextVariant.Emphasis -> theme.typography.body.copy(fontStyle = androidx.compose.ui.text.font.FontStyle.Italic)
                AITextVariant.Strong -> theme.typography.body.copy(fontWeight = FontWeight.Bold)
                AITextVariant.Muted -> theme.typography.body
                else -> theme.typography.body
            },
            color = if (node.variant == AITextVariant.Muted) theme.colors.mutedForeground else theme.colors.foreground,
        )

        is AISurfaceNode.Markdown -> AIMarkdown(
            markdown = node.markdown,
            modifier = m,
            onLink = { url ->
                onAction(AIUXAction(AIUXActions.CITATION_OPEN, buildJsonObject { put("uri", JsonPrimitive(url)) }))
            },
        )

        is AISurfaceNode.Code -> Box(m) { AICodeBlock(code = node.code, language = node.language) }

        is AISurfaceNode.Icon -> Icon(
            imageVector = iconFor(node.name),
            contentDescription = node.name,
            tint = theme.colors.mutedForeground,
            modifier = m.size(
                when (node.size) {
                    AIIconSize.Sm -> 16.dp; AIIconSize.Md -> 24.dp; AIIconSize.Lg -> 32.dp
                },
            ),
        )

        is AISurfaceNode.Image -> Surface(
            color = theme.colors.muted,
            shape = RoundedCornerShape(theme.radii.radius(node.style.radius?.name?.lowercase() ?: "md")),
            modifier = m
                .fillMaxWidth()
                .height(120.dp)
                .clickable {
                    onAction(AIUXAction(AIUXActions.IMAGE_OPEN, buildJsonObject { put("uri", JsonPrimitive(node.src)) }))
                }
                .semantics { contentDescription = node.alt ?: "image ${node.src}" },
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text(node.alt ?: "image", style = theme.typography.caption, color = theme.colors.mutedForeground)
            }
        }

        is AISurfaceNode.Badge -> Surface(
            color = toneColor(theme, node.tone).copy(alpha = 0.15f),
            shape = RoundedCornerShape(theme.radii.radius("full")),
            modifier = m,
        ) {
            Text(
                node.text,
                style = theme.typography.caption,
                color = toneColor(theme, node.tone),
                modifier = Modifier.padding(horizontal = theme.spacing.sm, vertical = 2.dp),
            )
        }

        is AISurfaceNode.Divider -> HorizontalDivider(
            modifier = m.fillMaxWidth(),
            color = theme.colors.border,
        )

        is AISurfaceNode.Spacer -> Spacer(m.size(theme.spacing.gap(node.size.name.lowercase())))

        is AISurfaceNode.KeyValue -> Column(
            modifier = m.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(theme.spacing.xs),
        ) {
            node.items.forEach { item ->
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(item.key, style = theme.typography.caption, color = theme.colors.mutedForeground)
                    Text(item.value, style = theme.typography.label, color = theme.colors.foreground)
                }
            }
        }

        is AISurfaceNode.ListNode -> Column(
            modifier = m.fillMaxWidth(),
            verticalArrangement = node.arrangement(theme),
        ) {
            node.children.forEachIndexed { index, child ->
                Row {
                    Text(
                        if (node.ordered) "${index + 1}." else "•",
                        style = theme.typography.body,
                        color = theme.colors.mutedForeground,
                        modifier = Modifier.padding(end = theme.spacing.sm),
                    )
                    SurfaceNodeView(child, onAction = onAction)
                }
            }
        }

        is AISurfaceNode.Table -> Column(modifier = m.fillMaxWidth()) {
            node.caption?.let {
                Text(it, style = theme.typography.caption, color = theme.colors.mutedForeground)
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(theme.colors.muted)
                    .padding(vertical = theme.spacing.xs),
            ) {
                node.headers.forEach { h ->
                    Text(
                        h,
                        style = theme.typography.label,
                        color = theme.colors.foreground,
                        modifier = Modifier.weight(1f).padding(horizontal = theme.spacing.xs),
                    )
                }
            }
            node.rows.forEach { row ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(width = Dp.Hairline, color = theme.colors.border)
                        .padding(vertical = theme.spacing.xs),
                ) {
                    row.forEach { c ->
                        Text(
                            c,
                            style = theme.typography.caption,
                            color = theme.colors.foreground,
                            modifier = Modifier.weight(1f).padding(horizontal = theme.spacing.xs),
                        )
                    }
                }
            }
        }

        is AISurfaceNode.Button -> {
            val click = { if (!node.disabled) onAction(node.action) }
            val shape = RoundedCornerShape(theme.radii.radius(node.style.radius?.name?.lowercase() ?: "md"))
            when (node.variant) {
                AIButtonVariant.Primary -> Button(
                    onClick = click,
                    enabled = !node.disabled,
                    shape = shape,
                    modifier = m.semantics { contentDescription = "button ${node.label}" },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = theme.colors.accent,
                        contentColor = theme.colors.accentForeground,
                    ),
                ) { Text(node.label) }
                AIButtonVariant.Secondary -> OutlinedButton(
                    onClick = click,
                    enabled = !node.disabled,
                    shape = shape,
                    modifier = m.semantics { contentDescription = "button ${node.label}" },
                ) { Text(node.label) }
                AIButtonVariant.Ghost -> TextButton(
                    onClick = click,
                    enabled = !node.disabled,
                    modifier = m.semantics { contentDescription = "button ${node.label}" },
                ) { Text(node.label) }
                AIButtonVariant.Destructive -> Button(
                    onClick = click,
                    enabled = !node.disabled,
                    shape = shape,
                    modifier = m.semantics { contentDescription = "button ${node.label}" },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = theme.colors.destructive,
                        contentColor = theme.colors.destructiveForeground,
                    ),
                ) { Text(node.label) }
            }
        }

        is AISurfaceNode.Menu -> {
            var expanded by remember { mutableStateOf(false) }
            Box(m) {
                OutlinedButton(onClick = { expanded = true }) {
                    Text(node.label)
                    Icon(Icons.Default.ArrowDropDown, contentDescription = null)
                }
                DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    node.items.forEach { item ->
                        DropdownMenuItem(
                            text = { Text(item.label) },
                            enabled = !item.disabled,
                            onClick = {
                                expanded = false
                                onAction(item.action)
                            },
                        )
                    }
                }
            }
        }

        is AISurfaceNode.Progress -> Column(m.fillMaxWidth()) {
            node.label?.let {
                Text(it, style = theme.typography.caption, color = theme.colors.mutedForeground)
            }
            val value = node.value
            if (value != null) {
                val max = node.max?.takeIf { it > 0 } ?: 1.0
                LinearProgressIndicator(
                    progress = { (value / max).toFloat().coerceIn(0f, 1f) },
                    modifier = Modifier.fillMaxWidth(),
                )
            } else {
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            }
        }

        is AISurfaceNode.Status -> Row(
            modifier = m.semantics { contentDescription = "status ${node.text}" },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val (icon, tint) = when (node.tone) {
                AITone.Success -> Icons.Default.CheckCircle to theme.colors.success
                AITone.Warning -> Icons.Default.Warning to theme.colors.warning
                AITone.Destructive -> Icons.Default.Warning to theme.colors.destructive
                AITone.Accent -> Icons.Default.Info to theme.colors.accent
                else -> Icons.Default.Info to theme.colors.mutedForeground
            }
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(16.dp))
            Text(
                node.text,
                style = theme.typography.label,
                color = tint,
                modifier = Modifier.padding(start = theme.spacing.sm),
            )
        }

        is AISurfaceNode.Input -> {
            var value by remember(node.value) { mutableStateOf(node.value ?: "") }
            OutlinedTextField(
                value = value,
                onValueChange = {
                    value = it
                    onAction(
                        AIUXAction(
                            AIUXActions.SURFACE_INPUT_CHANGE,
                            buildJsonObject {
                                put("name", JsonPrimitive(node.name))
                                put("value", JsonPrimitive(it))
                            },
                        ),
                    )
                },
                modifier = m.fillMaxWidth(),
                label = node.label?.let { { Text(it) } },
                placeholder = node.placeholder?.let { { Text(it) } },
                enabled = !node.disabled,
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = when (node.inputType) {
                        AIInputType.Email -> KeyboardType.Email
                        AIInputType.Number -> KeyboardType.Number
                        AIInputType.Password -> KeyboardType.Password
                        AIInputType.Url -> KeyboardType.Uri
                        else -> KeyboardType.Text
                    },
                ),
            )
        }

        is AISurfaceNode.TextArea -> {
            var value by remember(node.value) { mutableStateOf(node.value ?: "") }
            OutlinedTextField(
                value = value,
                onValueChange = {
                    value = it
                    onAction(
                        AIUXAction(
                            AIUXActions.SURFACE_INPUT_CHANGE,
                            buildJsonObject {
                                put("name", JsonPrimitive(node.name))
                                put("value", JsonPrimitive(it))
                            },
                        ),
                    )
                },
                modifier = m.fillMaxWidth(),
                label = node.label?.let { { Text(it) } },
                placeholder = node.placeholder?.let { { Text(it) } },
                enabled = !node.disabled,
                minLines = node.rows ?: 3,
            )
        }

        is AISurfaceNode.Select -> {
            var expanded by remember { mutableStateOf(false) }
            var selected by remember(node.value) { mutableStateOf(node.value) }
            val current = node.options.firstOrNull { it.value == selected }
            Box(m) {
                OutlinedButton(
                    onClick = { expanded = true },
                    enabled = !node.disabled,
                ) {
                    Text(current?.label ?: node.placeholder ?: node.label ?: node.name)
                    Icon(Icons.Default.ArrowDropDown, contentDescription = null)
                }
                DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    node.options.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(option.label) },
                            onClick = {
                                expanded = false
                                selected = option.value
                                onAction(
                                    AIUXAction(
                                        AIUXActions.SURFACE_SELECT_CHANGE,
                                        buildJsonObject {
                                            put("name", JsonPrimitive(node.name))
                                            put("value", JsonPrimitive(option.value))
                                        },
                                    ),
                                )
                            },
                        )
                    }
                }
            }
        }

        is AISurfaceNode.Checkbox -> {
            var checked by remember(node.checked) { mutableStateOf(node.checked) }
            Row(
                modifier = m.clickable(enabled = !node.disabled) {
                    checked = !checked
                    onAction(
                        AIUXAction(
                            AIUXActions.SURFACE_CHECKBOX_CHANGE,
                            buildJsonObject {
                                put("name", JsonPrimitive(node.name))
                                put("checked", JsonPrimitive(checked))
                            },
                        ),
                    )
                },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Checkbox(
                    checked = checked,
                    onCheckedChange = null,
                    enabled = !node.disabled,
                )
                Text(node.label, style = theme.typography.body, color = theme.colors.foreground)
            }
        }

        is AISurfaceNode.Actions -> Row(
            modifier = m.fillMaxWidth(),
            horizontalArrangement = node.horizontalArrangement(theme),
            verticalAlignment = node.verticalAlignment(),
        ) { node.children.forEach { SurfaceNodeView(it, onAction = onAction) } }

        is AISurfaceNode.UnknownNode -> Surface(
            color = theme.colors.muted,
            shape = RoundedCornerShape(theme.radii.sm),
            modifier = m.fillMaxWidth(),
        ) {
            Text(
                "Unsupported node: ${node.type}",
                style = theme.typography.caption,
                color = theme.colors.mutedForeground,
                modifier = Modifier
                    .padding(theme.spacing.sm)
                    .semantics { contentDescription = "unsupported surface node ${node.type}" },
            )
        }
    }
}

private fun toneColor(theme: AIUXTheme, tone: AITone) = when (tone) {
    AITone.Accent -> theme.colors.accent
    AITone.Muted -> theme.colors.mutedForeground
    AITone.Success -> theme.colors.success
    AITone.Warning -> theme.colors.warning
    AITone.Destructive -> theme.colors.destructive
    else -> theme.colors.foreground
}

private fun Modifier.nodeStyle(style: aiux.compose.model.AIUXNodeStyle, theme: AIUXTheme): Modifier {
    var m = this
    style.padding?.let { m = m.padding(theme.spacing.padding(it.name.lowercase())) }
    style.radius?.let { m = m.clip(RoundedCornerShape(theme.radii.radius(it.name.lowercase()))) }
    return m
}

private fun AISurfaceNode.arrangement(theme: AIUXTheme): Arrangement.Vertical {
    val gap = theme.spacing.gap(style.gap?.name?.lowercase() ?: "md")
    return when (style.distribution) {
        AIDistribution.Center -> Arrangement.spacedBy(gap, Alignment.CenterVertically)
        AIDistribution.End -> Arrangement.spacedBy(gap, Alignment.Bottom)
        AIDistribution.SpaceBetween -> Arrangement.SpaceBetween
        AIDistribution.SpaceAround -> Arrangement.SpaceAround
        AIDistribution.SpaceEvenly -> Arrangement.SpaceEvenly
        else -> Arrangement.spacedBy(gap)
    }
}

private fun AISurfaceNode.horizontalArrangement(theme: AIUXTheme): Arrangement.Horizontal {
    val gap = theme.spacing.gap(style.gap?.name?.lowercase() ?: "md")
    return when (style.distribution) {
        AIDistribution.Center -> Arrangement.spacedBy(gap, Alignment.CenterHorizontally)
        AIDistribution.End -> Arrangement.spacedBy(gap, Alignment.End)
        AIDistribution.SpaceBetween -> Arrangement.SpaceBetween
        AIDistribution.SpaceAround -> Arrangement.SpaceAround
        AIDistribution.SpaceEvenly -> Arrangement.SpaceEvenly
        else -> Arrangement.spacedBy(gap)
    }
}

private fun AISurfaceNode.horizontalAlignment(): Alignment.Horizontal = when (style.alignment) {
    AIAlignment.Center -> Alignment.CenterHorizontally
    AIAlignment.End -> Alignment.End
    else -> Alignment.Start
}

private fun AISurfaceNode.verticalAlignment(): Alignment.Vertical = when (style.alignment) {
    AIAlignment.Center -> Alignment.CenterVertically
    AIAlignment.End -> Alignment.Bottom
    else -> Alignment.Top
}

/** Semantic icon names → Material icons. Unknown names fall back to Info. */
private fun iconFor(name: String) = when (name.lowercase()) {
    "check", "done", "success", "ok" -> Icons.Default.Check
    "checkcircle", "complete" -> Icons.Default.CheckCircle
    "close", "cancel", "x" -> Icons.Default.Close
    "warning", "warn", "alert" -> Icons.Default.Warning
    "info" -> Icons.Default.Info
    "add", "plus" -> Icons.Default.Add
    "search" -> Icons.Default.Search
    "star", "favorite" -> Icons.Default.Star
    "chevron", "arrow", "forward" -> Icons.AutoMirrored.Default.KeyboardArrowRight
    else -> Icons.Default.Info
}
