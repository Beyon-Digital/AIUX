package aiux.compose.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.ClickableText
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import aiux.compose.AIUX
import aiux.compose.AIUXTheme

/**
 * Compose markdown path for `markdown` parts/nodes: headings, bold/italic/
 * strikethrough, inline code, fenced code blocks, bullet/ordered lists, and
 * links (link taps emit upward — never navigated implicitly, §23).
 */
@Composable
fun AIMarkdown(
    markdown: String,
    modifier: Modifier = Modifier,
    onLink: (String) -> Unit = {},
) {
    val theme = AIUX.theme
    val blocks = MarkdownParser.parse(markdown)
    Column(modifier = modifier) {
        blocks.forEach { block ->
            when (block) {
                is MarkdownBlock.Code -> AICodeBlock(code = block.code, language = block.language)
                is MarkdownBlock.Heading -> {
                    val annotated = MarkdownParser.inline(block.text, theme)
                    ClickableText(
                        text = annotated,
                        style = when (block.level) {
                            1 -> theme.typography.heading
                            2 -> theme.typography.title
                            else -> theme.typography.label.copy(fontWeight = FontWeight.Bold)
                        }.copy(color = theme.colors.foreground),
                        modifier = Modifier.padding(top = theme.spacing.sm),
                    ) { offset ->
                        annotated.getStringAnnotations("url", offset, offset)
                            .firstOrNull()?.let { onLink(it.item) }
                    }
                }
                is MarkdownBlock.BulletItem -> MarkdownListItem("•", block.text, theme, onLink)
                is MarkdownBlock.OrderedItem -> MarkdownListItem("${block.index}.", block.text, theme, onLink)
                is MarkdownBlock.Paragraph -> {
                    val annotated = MarkdownParser.inline(block.text, theme)
                    ClickableText(
                        text = annotated,
                        style = theme.typography.body.copy(color = theme.colors.foreground),
                        modifier = Modifier.fillMaxWidth(),
                    ) { offset ->
                        annotated.getStringAnnotations("url", offset, offset)
                            .firstOrNull()?.let { onLink(it.item) }
                    }
                }
            }
        }
    }
}

@Composable
private fun MarkdownListItem(
    marker: String,
    text: String,
    theme: AIUXTheme,
    onLink: (String) -> Unit,
    style: TextStyle = theme.typography.body,
) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = marker,
            style = style,
            color = theme.colors.mutedForeground,
            modifier = Modifier.padding(end = theme.spacing.sm),
        )
        val annotated = MarkdownParser.inline(text, theme)
        ClickableText(
            text = annotated,
            style = style.copy(color = theme.colors.foreground),
        ) { offset ->
            annotated.getStringAnnotations("url", offset, offset)
                .firstOrNull()?.let { onLink(it.item) }
        }
    }
}

sealed interface MarkdownBlock {
    data class Heading(val level: Int, val text: String) : MarkdownBlock
    data class Paragraph(val text: String) : MarkdownBlock
    data class BulletItem(val text: String) : MarkdownBlock
    data class OrderedItem(val index: Int, val text: String) : MarkdownBlock
    data class Code(val code: String, val language: String?) : MarkdownBlock
}

object MarkdownParser {

    /** Split markdown source into block-level elements. */
    fun parse(source: String): List<MarkdownBlock> {
        val blocks = mutableListOf<MarkdownBlock>()
        val lines = source.replace("\r\n", "\n").split('\n')
        var i = 0
        val para = StringBuilder()

        fun flushPara() {
            val t = para.toString().trim()
            if (t.isNotEmpty()) blocks += MarkdownBlock.Paragraph(t)
            para.clear()
        }

        while (i < lines.size) {
            val trimmed = lines[i].trim()
            when {
                trimmed.startsWith("```") -> {
                    flushPara()
                    val lang = trimmed.removePrefix("```").trim().ifEmpty { null }
                    val code = StringBuilder()
                    i++
                    while (i < lines.size && !lines[i].trim().startsWith("```")) {
                        code.append(lines[i]).append('\n')
                        i++
                    }
                    // `i` sits on the closing fence; the outer i++ consumes it.
                    blocks += MarkdownBlock.Code(code.toString().trimEnd('\n'), lang)
                }
                trimmed.matches(Regex("^#{1,6}\\s+.*")) -> {
                    flushPara()
                    val level = trimmed.takeWhile { it == '#' }.length
                    blocks += MarkdownBlock.Heading(level, trimmed.drop(level).trim())
                }
                trimmed.matches(Regex("^[-*+]\\s+.*")) -> {
                    flushPara()
                    blocks += MarkdownBlock.BulletItem(trimmed.drop(1).trim())
                }
                trimmed.matches(Regex("^\\d+[.)]\\s+.*")) -> {
                    flushPara()
                    val m = Regex("^(\\d+)[.)]\\s+(.*)").find(trimmed)!!
                    blocks += MarkdownBlock.OrderedItem(m.groupValues[1].toInt(), m.groupValues[2])
                }
                trimmed.isEmpty() -> flushPara()
                else -> para.append(trimmed).append(' ')
            }
            i++
        }
        flushPara()
        return blocks
    }

    /** Inline spans: `**bold**`, `*italic*`, `~~strike~~`, `` `code` ``, `[text](url)`. */
    fun inline(text: String, theme: AIUXTheme): AnnotatedString = buildAnnotatedString {
        var rest = text
        val token = Regex("(\\*\\*|__|~~|\\*|_|`)|\\[([^\\]]+)]\\(([^)]+)\\)")
        var m = token.find(rest)
        while (m != null) {
            val match = checkNotNull(m)
            append(rest.substring(0, match.range.first))
            val marker = match.groupValues[1]
            if (marker.isEmpty()) {
                val label = match.groupValues[2]
                val url = match.groupValues[3]
                pushStringAnnotation(tag = "url", annotation = url)
                withStyle(
                    SpanStyle(
                        color = theme.colors.accent,
                        textDecoration = TextDecoration.Underline,
                    ),
                ) { append(label) }
                pop()
                rest = rest.substring(match.range.last + 1)
            } else {
                val end = rest.indexOf(marker, match.range.last + 1)
                if (end < 0) {
                    append(marker)
                    rest = rest.substring(match.range.last + 1)
                } else {
                    val inner = rest.substring(match.range.last + 1, end)
                    when (marker) {
                        "**", "__" -> withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(inner) }
                        "~~" -> withStyle(SpanStyle(textDecoration = TextDecoration.LineThrough)) { append(inner) }
                        "`" -> withStyle(
                            SpanStyle(
                                fontFamily = FontFamily.Monospace,
                                background = theme.colors.muted,
                                fontSize = theme.typography.code.fontSize,
                            ),
                        ) { append(inner) }
                        else -> withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(inner) }
                    }
                    rest = rest.substring(end + marker.length)
                }
            }
            m = token.find(rest)
        }
        append(rest)
    }
}
