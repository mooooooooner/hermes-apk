import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Minimal, dependency-free syntax highlighter, ported 1:1 from the Kotlin
/// original. The concatenated span text is guaranteed to equal the source
/// code (see [plainText], covered by unit tests).
class SyntaxHighlighter {
  static const commonKeywords = {
    'fun', 'val', 'var', 'if', 'else', 'when', 'for', 'while', 'do', 'return',
    'break', 'continue', 'class', 'object', 'interface', 'enum', 'data',
    'sealed', 'override', 'open', 'private', 'public', 'protected', 'internal',
    'import', 'package', 'this', 'super', 'null', 'true', 'false', 'is', 'as',
    'in', 'out', 'try', 'catch', 'finally', 'throw', 'throws', 'new', 'static',
    'final', 'void', 'int', 'long', 'double', 'float', 'boolean', 'char',
    'byte', 'short', 'def', 'lambda', 'yield', 'with', 'async', 'await',
    'from', 'global', 'nonlocal', 'pass', 'raise', 'except', 'elif', 'const',
    'let', 'function', 'export', 'default', 'extends', 'implements', 'type',
    'func', 'go', 'defer', 'chan', 'struct', 'map', 'range', 'select',
    'switch', 'case', 'synchronized', 'volatile', 'transient',
  };

  static final tokenRegex = RegExp(
    r'/\*[\s\S]*?\*/' // block comment
    r'|//[^\n]*' // line comment
    r'|#[^\n]*' // hash comment
    r'|--[^\n]*' // sql comment
    r'|"(?:\\.|[^"\\])*"' // double-quoted string
    r"|'(?:\\.|[^'\\])*'" // single-quoted string
    r'|`(?:\\.|[^`\\])*`' // template string
    r'|\b\d+(?:\.\d+)?\b' // number
    r'|[A-Za-z_$][A-Za-z0-9_$]*', // identifier
  );

  static List<TextSpan> highlight(String code, String? lang) {
    final spans = <TextSpan>[];
    var last = 0;
    for (final match in tokenRegex.allMatches(code)) {
      if (match.start > last) {
        spans.add(TextSpan(
            text: code.substring(last, match.start),
            style: const TextStyle(color: syntaxPlain)));
      }
      final token = match.group(0)!;
      final firstChar = token[0];
      Color color;
      if (token.startsWith('//') ||
          token.startsWith('/*') ||
          token.startsWith('#') ||
          token.startsWith('--')) {
        color = syntaxComment;
      } else if (firstChar == '"' || firstChar == '\'' || firstChar == '`') {
        color = syntaxString;
      } else if (_isDigit(firstChar)) {
        color = syntaxNumber;
      } else if (commonKeywords.contains(token)) {
        color = syntaxKeyword;
      } else if (_isUpper(firstChar)) {
        color = syntaxType;
      } else if (_nextNonSpace(code, match.end) == '(') {
        color = syntaxFunction;
      } else {
        color = syntaxPlain;
      }
      spans.add(TextSpan(text: token, style: TextStyle(color: color)));
      last = match.end;
    }
    if (last < code.length) {
      spans.add(TextSpan(
          text: code.substring(last), style: const TextStyle(color: syntaxPlain)));
    }
    return spans;
  }

  /// Concatenated text of [spans]; used by tests to prove losslessness.
  static String plainText(List<TextSpan> spans) {
    final buffer = StringBuffer();
    void walk(List<InlineSpan> children) {
      for (final span in children) {
        if (span is TextSpan) {
          if (span.text != null) buffer.write(span.text);
          if (span.children != null) walk(span.children!);
        }
      }
    }

    walk(spans);
    return buffer.toString();
  }

  static bool _isDigit(String c) =>
      c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

  static bool _isUpper(String c) {
    final unit = c.codeUnitAt(0);
    return unit >= 0x41 && unit <= 0x5A;
  }

  static String? _nextNonSpace(String code, int from) {
    var i = from;
    while (i < code.length && code[i] == ' ') {
      i++;
    }
    return i < code.length ? code[i] : null;
  }
}
