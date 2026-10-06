package com.hermes.client.ui.markdown

import org.junit.Assert.assertEquals
import org.junit.Test

class SyntaxHighlighterTest {

    @Test
    fun preservesOriginalText() {
        val code = "fun main() { val x = 42 /* hi */ }"
        val annotated = SyntaxHighlighter.highlight(code, "kotlin")
        assertEquals(code, annotated.text)
    }

    @Test
    fun handlesStringsAndComments() {
        val code = "println(\"hello\") // greet"
        val annotated = SyntaxHighlighter.highlight(code, "kotlin")
        assertEquals(code, annotated.text)
    }
}
