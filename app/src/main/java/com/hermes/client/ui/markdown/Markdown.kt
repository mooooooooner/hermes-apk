package com.hermes.client.ui.markdown

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AttachFile
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Download
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withLink
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.hermes.client.ui.theme.CodeBackgroundDark
import com.hermes.client.ui.theme.CodeBackgroundLight
import com.hermes.client.ui.theme.CodeTextStyle
import com.hermes.client.ui.theme.SyntaxComment
import com.hermes.client.ui.theme.SyntaxFunction
import com.hermes.client.ui.theme.SyntaxKeyword
import com.hermes.client.ui.theme.SyntaxNumber
import com.hermes.client.ui.theme.SyntaxPlain
import com.hermes.client.ui.theme.SyntaxString
import com.hermes.client.ui.theme.SyntaxType

// ---------------------------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------------------------

sealed interface MdBlock {
    data class Heading(val level: Int, val text: String) : MdBlock
    data class Paragraph(val text: String) : MdBlock
    data class Code(val lang: String?, val code: String) : MdBlock
    data class ListBlock(val ordered: Boolean, val items: List<String>) : MdBlock
    data class Quote(val text: String) : MdBlock
    data object Divider : MdBlock
    data class Table(val header: List<String>, val rows: List<List<String>>) : MdBlock
    data class Image(val alt: String, val url: String) : MdBlock
    data class Media(val path: String) : MdBlock
}

object MarkdownParser {

    private val IMAGE_LINE = Regex("^!\\[([^\\]]*)\\]\\((\\S+)\\)$")
    private val MEDIA_LINE = Regex("^MEDIA:(\\S+)$")

    fun parse(source: String): List<MdBlock> {
        val lines = source.replace("\r\n", "\n").split("\n")
        val blocks = mutableListOf<MdBlock>()
        var i = 0
        val paragraph = StringBuilder()

        fun flushParagraph() {
            if (paragraph.isNotEmpty()) {
                blocks += MdBlock.Paragraph(paragraph.toString().trim())
                paragraph.clear()
            }
        }

        while (i < lines.size) {
            val raw = lines[i]
            val line = raw.trimEnd()

            when {
                line.trimStart().startsWith("```") -> {
                    flushParagraph()
                    val lang = line.trimStart().removePrefix("```").trim().ifBlank { null }
                    val code = StringBuilder()
                    i++
                    while (i < lines.size && !lines[i].trimStart().startsWith("```")) {
                        code.append(lines[i]).append('\n')
                        i++
                    }
                    if (i < lines.size) i++ // skip closing fence
                    blocks += MdBlock.Code(lang, code.toString().trimEnd('\n'))
                }

                line.isBlank() -> {
                    flushParagraph()
                    i++
                }

                Regex("^#{1,6}\\s+.*").matches(line) -> {
                    flushParagraph()
                    val level = line.takeWhile { it == '#' }.length
                    blocks += MdBlock.Heading(level.coerceAtMost(6), line.drop(level).trim())
                    i++
                }

                isDivider(line) -> {
                    flushParagraph()
                    blocks += MdBlock.Divider
                    i++
                }

                MEDIA_LINE.matches(line.trim()) -> {
                    flushParagraph()
                    blocks += MdBlock.Media(MEDIA_LINE.find(line.trim())!!.groupValues[1])
                    i++
                }

                IMAGE_LINE.matches(line.trim()) -> {
                    flushParagraph()
                    val match = IMAGE_LINE.find(line.trim())!!
                    blocks += MdBlock.Image(match.groupValues[1], match.groupValues[2])
                    i++
                }

                line.trimStart().startsWith(">") -> {
                    flushParagraph()
                    val quote = StringBuilder()
                    while (i < lines.size && lines[i].trimStart().startsWith(">")) {
                        quote.append(lines[i].trimStart().removePrefix(">").trim()).append('\n')
                        i++
                    }
                    blocks += MdBlock.Quote(quote.toString().trim())
                }

                Regex("^\\s*[-*+]\\s+.*").matches(line) -> {
                    flushParagraph()
                    val items = mutableListOf<String>()
                    while (i < lines.size && Regex("^\\s*[-*+]\\s+.*").matches(lines[i])) {
                        items += lines[i].trimStart().drop(1).trim()
                        i++
                    }
                    blocks += MdBlock.ListBlock(false, items)
                }

                Regex("^\\s*\\d+[.)]\\s+.*").matches(line) -> {
                    flushParagraph()
                    val items = mutableListOf<String>()
                    while (i < lines.size && Regex("^\\s*\\d+[.)]\\s+.*").matches(lines[i])) {
                        items += lines[i].trimStart().dropWhile { it.isDigit() || it == '.' || it == ')' }.trim()
                        i++
                    }
                    blocks += MdBlock.ListBlock(true, items)
                }

                line.contains("|") && i + 1 < lines.size &&
                    Regex("^\\s*\\|?\\s*:?-{2,}:?.*").matches(lines[i + 1]) -> {
                    flushParagraph()
                    val header = splitRow(line)
                    i += 2
                    val rows = mutableListOf<List<String>>()
                    while (i < lines.size && lines[i].contains("|") && lines[i].isNotBlank()) {
                        rows += splitRow(lines[i])
                        i++
                    }
                    blocks += MdBlock.Table(header, rows)
                }

                else -> {
                    if (paragraph.isNotEmpty()) paragraph.append('\n')
                    paragraph.append(line.trim())
                    i++
                }
            }
        }
        flushParagraph()
        return blocks
    }

    private fun splitRow(line: String): List<String> =
        line.trim().trim('|').split('|').map { it.trim() }

    private fun isDivider(line: String): Boolean {
        val t = line.trim()
        if (t.length < 3) return false
        return t.all { it == '-' } || t.all { it == '*' } || t.all { it == '_' }
    }
}

// ---------------------------------------------------------------------------------------------
// Inline formatting
// ---------------------------------------------------------------------------------------------

private val inlineRegex = Regex(
    "(`[^`]+`)" +
        "|(\\*\\*[^*]+\\*\\*)" +
        "|(__[^_]+__)" +
        "|(~~[^~]+~~)" +
        "|(\\*[^*\\n]+\\*)" +
        "|(_[^_\\n]+_)" +
        "|(\\[[^\\]]+\\]\\([^)\\s]+\\))" +
        "|(https?://[^\\s)]+)",
)

private fun AnnotatedString.Builder.appendInline(
    text: String,
    linkColor: Color,
    codeColor: Color,
) {
    var last = 0
    inlineRegex.findAll(text).forEach { match ->
        if (match.range.first > last) append(text.substring(last, match.range.first))
        val value = match.value
        when {
            value.startsWith("`") ->
                withStyle(
                    SpanStyle(
                        fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                        background = codeColor,
                    ),
                ) { append(value.trim('`')) }

            value.startsWith("**") || value.startsWith("__") ->
                withStyle(SpanStyle(fontWeight = FontWeight.Bold)) {
                    append(value.substring(2, value.length - 2))
                }

            value.startsWith("~~") ->
                withStyle(SpanStyle(textDecoration = TextDecoration.LineThrough)) {
                    append(value.substring(2, value.length - 2))
                }

            value.startsWith("*") || value.startsWith("_") ->
                withStyle(SpanStyle(fontStyle = FontStyle.Italic)) {
                    append(value.substring(1, value.length - 1))
                }

            value.startsWith("[") -> {
                val label = value.substringAfter('[').substringBefore(']')
                val url = value.substringAfter('(').substringBeforeLast(')')
                withLink(
                    LinkAnnotation.Url(
                        url,
                        TextLinkStyles(SpanStyle(color = linkColor, textDecoration = TextDecoration.Underline)),
                    ),
                ) { append(label) }
            }

            else -> withLink(
                LinkAnnotation.Url(
                    value,
                    TextLinkStyles(SpanStyle(color = linkColor, textDecoration = TextDecoration.Underline)),
                ),
            ) { append(value) }
        }
        last = match.range.last + 1
    }
    if (last < text.length) append(text.substring(last))
}

@Composable
private fun inlineText(
    text: String,
    color: Color = Color.Unspecified,
    linkColor: Color = MaterialTheme.colorScheme.primary,
): AnnotatedString {
    val codeColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)
    return remember(text, color, linkColor, codeColor) {
        buildAnnotatedString {
            appendInline(text, linkColor, codeColor)
            if (color != Color.Unspecified) {
                addStyle(SpanStyle(color = color), 0, length)
            }
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Renderer
// ---------------------------------------------------------------------------------------------

@Composable
fun MarkdownText(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = MaterialTheme.colorScheme.onSurface,
    onOpenMedia: ((String) -> Unit)? = null,
) {
    val blocks = remember(text) { MarkdownParser.parse(text) }
    SelectionContainer {
        Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            blocks.forEach { block ->
                when (block) {
                    is MdBlock.Heading -> Text(
                        text = inlineText(block.text, color),
                        style = when (block.level) {
                            1 -> MaterialTheme.typography.headlineMedium
                            2 -> MaterialTheme.typography.titleLarge
                            else -> MaterialTheme.typography.titleMedium
                        },
                    )

                    is MdBlock.Paragraph -> Text(
                        text = inlineText(block.text, color),
                        style = MaterialTheme.typography.bodyLarge,
                    )

                    is MdBlock.Code -> CodeBlock(block.code, block.lang)

                    is MdBlock.ListBlock -> Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        block.items.forEachIndexed { index, item ->
                            Row {
                                Text(
                                    text = if (block.ordered) "${index + 1}." else "•",
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = color,
                                    modifier = Modifier.width(24.dp),
                                )
                                Text(
                                    text = inlineText(item, color),
                                    style = MaterialTheme.typography.bodyLarge,
                                )
                            }
                        }
                    }

                    is MdBlock.Quote -> Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.Top,
                    ) {
                        Box(
                            modifier = Modifier
                                .width(3.dp)
                                .background(MaterialTheme.colorScheme.primary, RoundedCornerShape(2.dp))
                                .padding(vertical = 2.dp),
                        ) { Spacer(Modifier.size(3.dp)) }
                        Spacer(Modifier.width(10.dp))
                        Text(
                            text = inlineText(block.text, MaterialTheme.colorScheme.onSurfaceVariant),
                            style = MaterialTheme.typography.bodyLarge,
                        )
                    }

                    MdBlock.Divider -> HorizontalDivider(
                        color = MaterialTheme.colorScheme.outlineVariant,
                    )

                    is MdBlock.Table -> TableBlock(block, color)
                    is MdBlock.Image -> ImageBlock(block.alt, block.url, onOpenMedia)
                    is MdBlock.Media -> MediaChip(block.path, onOpenMedia)
                }
            }
        }
    }
}

@Composable
private fun TableBlock(table: MdBlock.Table, color: Color) {
    val columnCount = maxOf(table.header.size, table.rows.maxOfOrNull { it.size } ?: 0)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f), RoundedCornerShape(10.dp))
            .padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            repeat(columnCount) { index ->
                Text(
                    text = inlineText(table.header.getOrElse(index) { "" }, color),
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.width(120.dp),
                )
            }
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
        table.rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                repeat(columnCount) { index ->
                    Text(
                        text = inlineText(row.getOrElse(index) { "" }, color),
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.width(120.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun ImageBlock(alt: String, url: String, onOpenMedia: ((String) -> Unit)? = null) {
    val modifier = Modifier
        .fillMaxWidth()
        .clip(RoundedCornerShape(10.dp))
        .let { if (onOpenMedia != null && !url.startsWith("data:")) it.clickable { onOpenMedia(url) } else it }
    if (url.startsWith("data:")) {
        val bitmap = remember(url) { decodeDataUrl(url) }
        if (bitmap != null) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = alt.ifBlank { "图片" },
                modifier = modifier,
                contentScale = ContentScale.FillWidth,
            )
        } else {
            Text(
                text = alt.ifBlank { "[图片]" },
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    } else {
        AsyncImage(
            model = url,
            contentDescription = alt.ifBlank { "图片" },
            modifier = modifier,
            contentScale = ContentScale.FillWidth,
        )
    }
}

@Composable
private fun MediaChip(path: String, onOpenMedia: ((String) -> Unit)? = null) {
    val name = path.substringAfterLast('/').ifBlank { path }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f))
            .let {
                if (onOpenMedia != null) it.clickable { onOpenMedia(path) } else it
            }
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = Icons.Rounded.AttachFile,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(18.dp),
        )
        Spacer(Modifier.width(8.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = name,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = path,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.outline,
            )
        }
        if (onOpenMedia != null && !path.startsWith("/")) {
            Icon(
                imageVector = Icons.Rounded.Download,
                contentDescription = "下载",
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

private fun decodeDataUrl(url: String): android.graphics.Bitmap? = runCatching {
    val comma = url.indexOf(',')
    if (comma < 0) return null
    val meta = url.substring(5, comma)
    if (!meta.contains(";base64")) return null
    val bytes = android.util.Base64.decode(url.substring(comma + 1), android.util.Base64.DEFAULT)
    android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
}.getOrNull()

@Composable
fun CodeBlock(code: String, lang: String?) {
    val clipboard = LocalClipboardManager.current
    val isDark = MaterialTheme.colorScheme.background.luminanceIsDark()
    val background = if (isDark) CodeBackgroundDark else CodeBackgroundLight
    val highlighted = remember(code, lang, isDark) { SyntaxHighlighter.highlight(code, lang) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(background, RoundedCornerShape(12.dp)),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 14.dp, end = 4.dp, top = 4.dp, bottom = 0.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = lang ?: "code",
                style = MaterialTheme.typography.labelMedium,
                color = SyntaxComment,
                modifier = Modifier.weight(1f),
            )
            IconButton(onClick = { clipboard.setText(AnnotatedString(code)) }) {
                Icon(
                    imageVector = Icons.Rounded.ContentCopy,
                    contentDescription = "复制代码",
                    tint = SyntaxComment,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
        Text(
            text = highlighted,
            style = CodeTextStyle,
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(start = 14.dp, end = 14.dp, bottom = 14.dp, top = 0.dp),
        )
    }
}

private fun Color.luminanceIsDark(): Boolean =
    (0.299f * red + 0.587f * green + 0.114f * blue) < 0.5f

// ---------------------------------------------------------------------------------------------
// Minimal, dependency-free syntax highlighter
// ---------------------------------------------------------------------------------------------

object SyntaxHighlighter {

    private val commonKeywords = setOf(
        "fun", "val", "var", "if", "else", "when", "for", "while", "do", "return", "break",
        "continue", "class", "object", "interface", "enum", "data", "sealed", "override", "open",
        "private", "public", "protected", "internal", "import", "package", "this", "super", "null",
        "true", "false", "is", "as", "in", "out", "try", "catch", "finally", "throw", "throws",
        "new", "static", "final", "void", "int", "long", "double", "float", "boolean", "char",
        "byte", "short", "def", "lambda", "yield", "with", "async", "await", "from", "global",
        "nonlocal", "pass", "raise", "except", "elif", "const", "let", "function", "export",
        "default", "extends", "implements", "type", "func", "go", "defer", "chan", "struct",
        "map", "range", "select", "switch", "case", "synchronized", "volatile", "transient",
    )

    private val tokenRegex = Regex(
        "/\\*[\\s\\S]*?\\*/" +          // block comment
            "|//[^\\n]*" +               // line comment
            "|#[^\\n]*" +                // hash comment
            "|--[^\\n]*" +               // sql comment
            "|\"(?:\\\\.|[^\"\\\\])*\"" + // double-quoted string
            "|'(?:\\\\.|[^'\\\\])*'" +   // single-quoted string
            "|`(?:\\\\.|[^`\\\\])*`" +   // template string
            "|\\b\\d+(?:\\.\\d+)?\\b" +  // number
            "|[A-Za-z_$][A-Za-z0-9_$]*", // identifier
    )

    fun highlight(code: String, lang: String?): AnnotatedString = buildAnnotatedString {
        var last = 0
        tokenRegex.findAll(code).forEach { match ->
            if (match.range.first > last) {
                withStyle(SpanStyle(color = SyntaxPlain)) {
                    append(code.substring(last, match.range.first))
                }
            }
            val token = match.value
            val color = when {
                token.startsWith("//") || token.startsWith("/*") ||
                    token.startsWith("#") || token.startsWith("--") -> SyntaxComment
                token.startsWith("\"") || token.startsWith("'") || token.startsWith("`") -> SyntaxString
                token.first().isDigit() -> SyntaxNumber
                token in commonKeywords -> SyntaxKeyword
                token.first().isUpperCase() -> SyntaxType
                nextNonSpace(code, match.range.last + 1) == '(' -> SyntaxFunction
                else -> SyntaxPlain
            }
            withStyle(SpanStyle(color = color)) { append(token) }
            last = match.range.last + 1
        }
        if (last < code.length) {
            withStyle(SpanStyle(color = SyntaxPlain)) { append(code.substring(last)) }
        }
    }

    private fun nextNonSpace(code: String, from: Int): Char? {
        var i = from
        while (i < code.length && code[i] == ' ') i++
        return code.getOrNull(i)
    }
}
