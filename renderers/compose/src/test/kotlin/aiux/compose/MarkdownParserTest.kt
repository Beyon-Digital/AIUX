package aiux.compose

import aiux.compose.components.MarkdownBlock
import aiux.compose.components.MarkdownParser
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

class MarkdownParserTest {

    @Test
    fun splitsBlocks() {
        val blocks = MarkdownParser.parse(
            """
            # Title
            Some **bold** text.
            - item one
            - item two
            ```kotlin
            fun x() = 1
            ```
            1. first
            """.trimIndent(),
        )
        assertIs<MarkdownBlock.Heading>(blocks[0])
        assertEquals(1, (blocks[0] as MarkdownBlock.Heading).level)
        assertIs<MarkdownBlock.Paragraph>(blocks[1])
        assertIs<MarkdownBlock.BulletItem>(blocks[2])
        assertIs<MarkdownBlock.BulletItem>(blocks[3])
        assertIs<MarkdownBlock.Code>(blocks[4])
        assertEquals("kotlin", (blocks[4] as MarkdownBlock.Code).language)
        assertEquals("fun x() = 1", (blocks[4] as MarkdownBlock.Code).code)
        assertIs<MarkdownBlock.OrderedItem>(blocks[5])
        assertEquals(1, (blocks[5] as MarkdownBlock.OrderedItem).index)
    }

    @Test
    fun unclosedFenceStillRenders() {
        val blocks = MarkdownParser.parse("```\npartial code")
        assertIs<MarkdownBlock.Code>(blocks[0])
        assertEquals("partial code", (blocks[0] as MarkdownBlock.Code).code)
    }

    @Test
    fun inlineStylesAnnotate() {
        val annotated = MarkdownParser.inline(
            "see **bold** and `code` and [link](https://x.dev)",
            AIUXTheme.light(),
        )
        val styles = annotated.spanStyles.map { annotated.text.substring(it.start, it.end) to it.item }
        assertTrue(styles.any { it.first == "bold" && it.second.fontWeight != null })
        assertTrue(styles.any { it.first == "code" })
        assertTrue(annotated.getStringAnnotations("url", 0, annotated.length)
            .any { it.item == "https://x.dev" })
    }
}
