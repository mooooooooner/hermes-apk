package com.hermes.client.ui.markdown

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MarkdownParserTest {

    @Test
    fun parsesHeadingsParagraphsAndCode() {
        val md = """
            # Title

            Some **bold** text.

            ```kotlin
            val x = 1
            ```
        """.trimIndent()

        val blocks = MarkdownParser.parse(md)
        assertEquals(3, blocks.size)

        val heading = blocks[0] as MdBlock.Heading
        assertEquals(1, heading.level)
        assertEquals("Title", heading.text)

        assertTrue(blocks[1] is MdBlock.Paragraph)

        val code = blocks[2] as MdBlock.Code
        assertEquals("kotlin", code.lang)
        assertEquals("val x = 1", code.code)
    }

    @Test
    fun parsesListsAndQuotes() {
        val md = """
            - a
            - b

            > quoted
        """.trimIndent()

        val blocks = MarkdownParser.parse(md)
        val list = blocks[0] as MdBlock.ListBlock
        assertEquals(listOf("a", "b"), list.items)
        val quote = blocks[1] as MdBlock.Quote
        assertEquals("quoted", quote.text)
    }

    @Test
    fun parsesOrderedLists() {
        val blocks = MarkdownParser.parse("1. one\n2. two")
        val list = blocks[0] as MdBlock.ListBlock
        assertTrue(list.ordered)
        assertEquals(listOf("one", "two"), list.items)
    }

    @Test
    fun parsesTable() {
        val md = """
            | a | b |
            | --- | --- |
            | 1 | 2 |
        """.trimIndent()
        val table = MarkdownParser.parse(md)[0] as MdBlock.Table
        assertEquals(listOf("a", "b"), table.header)
        assertEquals(listOf("1", "2"), table.rows[0])
    }
}
