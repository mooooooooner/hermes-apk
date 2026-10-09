import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../di.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'syntax_highlighter.dart';

// ---------------------------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------------------------

sealed class MdBlock {
  const MdBlock();
}

class MdHeading extends MdBlock {
  final int level;
  final String text;
  const MdHeading(this.level, this.text);
}

class MdParagraph extends MdBlock {
  final String text;
  const MdParagraph(this.text);
}

class MdCode extends MdBlock {
  final String? lang;
  final String code;
  const MdCode(this.lang, this.code);
}

class MdListBlock extends MdBlock {
  final bool ordered;
  final List<String> items;
  const MdListBlock(this.ordered, this.items);
}

class MdQuote extends MdBlock {
  final String text;
  const MdQuote(this.text);
}

class MdDivider extends MdBlock {
  const MdDivider();
}

class MdTable extends MdBlock {
  final List<String> header;
  final List<List<String>> rows;
  const MdTable(this.header, this.rows);
}

class MdImage extends MdBlock {
  final String alt;
  final String url;
  const MdImage(this.alt, this.url);
}

class MdMedia extends MdBlock {
  final String path;
  const MdMedia(this.path);
}

final _imageLine = RegExp(r'^!\[([^\]]*)\]\((\S+)\)$');
final _mediaLine = RegExp(r'^MEDIA:(\S+)$');
final _headingLine = RegExp(r'^#{1,6}\s+.*$');
final _bulletItem = RegExp(r'^\s*[-*+]\s+.*$');
final _orderedItem = RegExp(r'^\s*\d+[.)]\s+.*$');
final _tableDivider = RegExp(r'^\s*\|?\s*:?-{2,}:?.*$');

class MarkdownParser {
  static List<MdBlock> parse(String source) {
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    final blocks = <MdBlock>[];
    var i = 0;
    final paragraph = StringBuffer();

    void flushParagraph() {
      if (paragraph.isNotEmpty) {
        blocks.add(MdParagraph(paragraph.toString().trim()));
        paragraph.clear();
      }
    }

    while (i < lines.length) {
      final line = lines[i].trimRight();

      if (line.trimLeft().startsWith('```')) {
        flushParagraph();
        final stripped = line.trimLeft().replaceFirst('```', '').trim();
        final lang = stripped.isEmpty ? null : stripped;
        final code = StringBuffer();
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          code.write(lines[i]);
          code.write('\n');
          i++;
        }
        if (i < lines.length) i++; // skip closing fence
        var codeText = code.toString();
        while (codeText.endsWith('\n')) {
          codeText = codeText.substring(0, codeText.length - 1);
        }
        blocks.add(MdCode(lang, codeText));
      } else if (line.trim().isEmpty) {
        flushParagraph();
        i++;
      } else if (_headingLine.hasMatch(line)) {
        flushParagraph();
        var level = 0;
        for (final c in line.codeUnits) {
          if (c == 0x23) {
            level++;
          } else {
            break;
          }
        }
        blocks.add(MdHeading(
            level > 6 ? 6 : level, line.substring(level).trim()));
        i++;
      } else if (_isDivider(line)) {
        flushParagraph();
        blocks.add(const MdDivider());
        i++;
      } else if (_mediaLine.hasMatch(line.trim())) {
        flushParagraph();
        blocks.add(MdMedia(_mediaLine.firstMatch(line.trim())!.group(1)!));
        i++;
      } else if (_imageLine.hasMatch(line.trim())) {
        flushParagraph();
        final match = _imageLine.firstMatch(line.trim())!;
        blocks.add(MdImage(match.group(1)!, match.group(2)!));
        i++;
      } else if (line.trimLeft().startsWith('>')) {
        flushParagraph();
        final quote = StringBuffer();
        while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
          quote.write(lines[i].trimLeft().replaceFirst('>', '').trim());
          quote.write('\n');
          i++;
        }
        blocks.add(MdQuote(quote.toString().trim()));
      } else if (_bulletItem.hasMatch(line)) {
        flushParagraph();
        final items = <String>[];
        while (i < lines.length && _bulletItem.hasMatch(lines[i])) {
          items.add(lines[i].trimLeft().substring(1).trim());
          i++;
        }
        blocks.add(MdListBlock(false, items));
      } else if (_orderedItem.hasMatch(line)) {
        flushParagraph();
        final items = <String>[];
        while (i < lines.length && _orderedItem.hasMatch(lines[i])) {
          var text = lines[i].trimLeft();
          var drop = 0;
          while (drop < text.length &&
              (_isDigitChar(text.codeUnitAt(drop)) ||
                  text[drop] == '.' ||
                  text[drop] == ')')) {
            drop++;
          }
          items.add(text.substring(drop).trim());
          i++;
        }
        blocks.add(MdListBlock(true, items));
      } else if (line.contains('|') &&
          i + 1 < lines.length &&
          _tableDivider.hasMatch(lines[i + 1])) {
        flushParagraph();
        final header = _splitRow(line);
        i += 2;
        final rows = <List<String>>[];
        while (i < lines.length &&
            lines[i].contains('|') &&
            lines[i].trim().isNotEmpty) {
          rows.add(_splitRow(lines[i]));
          i++;
        }
        blocks.add(MdTable(header, rows));
      } else {
        if (paragraph.isNotEmpty) paragraph.write('\n');
        paragraph.write(line.trim());
        i++;
      }
    }
    flushParagraph();
    return blocks;
  }

  static List<String> _splitRow(String line) {
    var t = line.trim();
    if (t.startsWith('|')) t = t.substring(1);
    if (t.endsWith('|')) t = t.substring(0, t.length - 1);
    return t.split('|').map((e) => e.trim()).toList();
  }

  static bool _isDivider(String line) {
    final t = line.trim();
    if (t.length < 3) return false;
    return t.codeUnits.every((c) => c == 0x2D) ||
        t.codeUnits.every((c) => c == 0x2A) ||
        t.codeUnits.every((c) => c == 0x5F);
  }

  static bool _isDigitChar(int c) => c >= 0x30 && c <= 0x39;
}

// ---------------------------------------------------------------------------------------------
// Inline formatting
// ---------------------------------------------------------------------------------------------

final _inlineRegex = RegExp(
  r'(`[^`]+`)'
  r'|(\*\*[^*]+\*\*)'
  r'|(__[^_]+__)'
  r'|(~~[^~]+~~)'
  r'|(\*[^*\n]+\*)'
  r'|(_[^_\n]+_)'
  r'|(\[[^\]]+\]\([^)\s]+\))'
  r'|(https?://[^\s)]+)',
);

List<InlineSpan> buildInlineSpans(
  String text, {
  Color? color,
  Color? linkColor,
  Color? codeColor,
}) {
  linkColor ??= color;
  final spans = <InlineSpan>[];

  void appendPlain(String value) {
    spans.add(TextSpan(text: value));
  }

  var last = 0;
  for (final match in _inlineRegex.allMatches(text)) {
    if (match.start > last) {
      appendPlain(text.substring(last, match.start));
    }
    final value = match.group(0)!;
    if (value.startsWith('`')) {
      spans.add(TextSpan(
        text: value.replaceAll('`', ''),
        style: TextStyle(
          fontFamily: 'monospace',
          background:
              codeColor == null ? null : (Paint()..color = codeColor),
        ),
      ));
    } else if (value.startsWith('**') || value.startsWith('__')) {
      spans.add(TextSpan(
        text: value.substring(2, value.length - 2),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
    } else if (value.startsWith('~~')) {
      spans.add(TextSpan(
        text: value.substring(2, value.length - 2),
        style: TextStyle(
            decoration: TextDecoration.lineThrough,
            decorationColor: color,
            color: color),
      ));
    } else if (value.startsWith('*') || value.startsWith('_')) {
      spans.add(TextSpan(
        text: value.substring(1, value.length - 1),
        style: TextStyle(fontStyle: FontStyle.italic, color: color),
      ));
    } else if (value.startsWith('[')) {
      final label =
          value.substring(value.indexOf('[') + 1, value.indexOf(']'));
      final url = value.substring(value.indexOf('(') + 1, value.length - 1);
      spans.add(TextSpan(
        text: label,
        style: TextStyle(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _launch(url),
      ));
    } else {
      spans.add(TextSpan(
        text: value,
        style: TextStyle(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _launch(value),
      ));
    }
    last = match.end;
  }
  if (last < text.length) {
    appendPlain(text.substring(last));
  }
  // The base color applies to everything not explicitly colored above.
  return [
    TextSpan(children: spans, style: TextStyle(color: color)),
  ];
}

Future<void> _launch(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

// ---------------------------------------------------------------------------------------------
// Renderer
// ---------------------------------------------------------------------------------------------

class MarkdownText extends StatelessWidget {
  final String text;
  final Color? color;
  final void Function(String url)? onOpenMedia;

  const MarkdownText({
    super.key,
    required this.text,
    this.color,
    this.onOpenMedia,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? scheme.onSurface;
    final blocks = MarkdownParser.parse(text);
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < blocks.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _buildBlock(context, blocks[index], effectiveColor, scheme),
          ],
        ],
      ),
    );
  }

  Widget _buildBlock(
      BuildContext context, MdBlock block, Color color, ColorScheme scheme) {
    final codeColor = scheme.surfaceContainerHigh.withValues(alpha: 0.6);
    switch (block) {
      case MdHeading():
        return Text.rich(
          TextSpan(
            children: buildInlineSpans(block.text, color: color, codeColor: codeColor),
          ),
          style: switch (block.level) {
            1 => HermesTypography.headlineMedium,
            2 => HermesTypography.titleLarge,
            _ => HermesTypography.titleMedium,
          },
        );
      case MdParagraph():
        return Text.rich(
          TextSpan(
            children: buildInlineSpans(block.text, color: color, codeColor: codeColor),
          ),
          style: HermesTypography.bodyLarge,
        );
      case MdCode():
        return CodeBlock(code: block.code, lang: block.lang);
      case MdListBlock():
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < block.items.length; index++) ...[
              if (index > 0) const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      block.ordered ? '${index + 1}.' : '•',
                      style: HermesTypography.bodyLarge.copyWith(color: color),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: buildInlineSpans(block.items[index],
                          color: color, codeColor: codeColor)),
                      style: HermesTypography.bodyLarge,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      case MdQuote():
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: buildInlineSpans(block.text,
                    color: scheme.onSurfaceVariant, codeColor: codeColor)),
                style: HermesTypography.bodyLarge,
              ),
            ),
          ],
        );
      case MdDivider():
        return Divider(color: scheme.outlineVariant, height: 1);
      case MdTable():
        return _TableBlock(table: block, color: color);
      case MdImage():
        return _ImageBlock(
            alt: block.alt, url: block.url, onOpenMedia: onOpenMedia);
      case MdMedia():
        return MediaChip(path: block.path, onOpenMedia: onOpenMedia);
    }
  }
}

class _TableBlock extends StatelessWidget {
  final MdTable table;
  final Color color;

  const _TableBlock({required this.table, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final codeColor = scheme.surfaceContainerHigh.withValues(alpha: 0.6);
    var columnCount = table.header.length;
    for (final row in table.rows) {
      if (row.length > columnCount) columnCount = row.length;
    }
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minWidth: double.infinity),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var index = 0; index < columnCount; index++) ...[
                  if (index > 0) const SizedBox(width: 16),
                  SizedBox(
                    width: 120,
                    child: Text.rich(
                      TextSpan(children: buildInlineSpans(
                          _cellAt(table.header, index),
                          color: color,
                          codeColor: codeColor)),
                      style: HermesTypography.titleSmall,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Divider(color: scheme.outlineVariant, height: 1),
            const SizedBox(height: 6),
            for (final row in table.rows) ...[
              Row(
                children: [
                  for (var index = 0; index < columnCount; index++) ...[
                    if (index > 0) const SizedBox(width: 16),
                    SizedBox(
                      width: 120,
                      child: Text.rich(
                        TextSpan(children: buildInlineSpans(
                            _cellAt(row, index),
                            color: color,
                            codeColor: codeColor)),
                        style: HermesTypography.bodyMedium,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  static String _cellAt(List<String> cells, int index) =>
      index < cells.length ? cells[index] : '';
}

class _ImageBlock extends StatelessWidget {
  final String alt;
  final String url;
  final void Function(String url)? onOpenMedia;

  const _ImageBlock(
      {required this.alt, required this.url, this.onOpenMedia});

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (url.startsWith('data:')) {
      final bytes = decodeDataUrl(url);
      if (bytes != null) {
        image = Image.memory(
          bytes,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          errorBuilder: (_, _, _) => _altText(context),
        );
      } else {
        return _altText(context);
      }
    } else {
      image = Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        headers: _headersFor(url),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _placeholder(context),
        errorBuilder: (_, _, _) => _altText(context),
      );
    }
    final clickable = onOpenMedia != null && !url.startsWith('data:');
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: clickable
          ? GestureDetector(
              onTap: () => onOpenMedia!(url), child: image)
          : image,
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );

  Widget _altText(BuildContext context) => Text(
        alt.isEmpty ? '[图片]' : alt,
        style: HermesTypography.bodyMedium
            .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
}

/// Media chip for `MEDIA:url` lines produced by the agent (files it wants to
/// hand back). Tap downloads/opens via [onOpenMedia].
class MediaChip extends StatelessWidget {
  final String path;
  final void Function(String url)? onOpenMedia;

  const MediaChip({super.key, required this.path, this.onOpenMedia});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var name = path.substring(path.lastIndexOf('/') + 1);
    if (name.isEmpty) name = path;
    return GestureDetector(
      onTap: onOpenMedia == null ? null : () => onOpenMedia!(path),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.attach_file_rounded,
                size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HermesTypography.labelLarge
                          .copyWith(color: scheme.onSurface)),
                  Text(path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.outline)),
                ],
              ),
            ),
            if (onOpenMedia != null && !path.startsWith('/'))
              const Icon(Icons.download_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

Uint8List? decodeDataUrl(String url) {
  try {
    final comma = url.indexOf(',');
    if (comma < 0) return null;
    final meta = url.substring(5, comma);
    if (!meta.contains(';base64')) return null;
    return base64Decode(url.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

Map<String, String>? _headersFor(String url) {
  try {
    final service = Di.fileService;
    final settings = Di.settings;
    if (service.isFilesUrl(url) && settings.cachedApiKey.trim().isNotEmpty) {
      return {'Authorization': 'Bearer ${settings.cachedApiKey.trim()}'};
    }
  } catch (_) {}
  return null;
}

/// Dark code block with language label + copy button, reused for tool previews.
class CodeBlock extends StatelessWidget {
  final String code;
  final String? lang;

  const CodeBlock({super.key, required this.code, this.lang});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.surface.computeLuminance() < 0.5;
    final background = isDark ? codeBackgroundDark : codeBackgroundLight;
    final highlighted = SyntaxHighlighter.highlight(code, lang);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 4, top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lang ?? 'code',
                    style: HermesTypography.labelMedium
                        .copyWith(color: syntaxComment),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // ignore: invalid_use_of_protected_member
                    Clipboard.setData(ClipboardData(text: code));
                  },
                  icon: const Icon(Icons.copy_rounded,
                      size: 18, color: syntaxComment),
                  tooltip: '复制代码',
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 14, right: 14, bottom: 14),
              child: Text.rich(
                TextSpan(children: highlighted),
                style: HermesTypography.codeTextStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
