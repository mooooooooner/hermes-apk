import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_client/ui/markdown/syntax_highlighter.dart';

void main() {
  test('preserves original text', () {
    const code = 'fun main() {\n  val x = "hello \\n world" // comment\n  # hash\n}';
    final spans = SyntaxHighlighter.highlight(code, 'kotlin');
    expect(SyntaxHighlighter.plainText(spans), code);
  });

  test('handles strings and comments', () {
    const code = '// note\nval s = "text with \\" quote"';
    final spans = SyntaxHighlighter.highlight(code, 'kotlin');
    final flat = SyntaxHighlighter.plainText(spans);
    expect(flat, code);
    // The line comment and the string survive as spans starting with their
    // delimiter characters.
    expect(spans.any((s) => s.text != null && s.text!.startsWith('//')), isTrue);
    expect(spans.any((s) => s.text != null && s.text!.startsWith('"')), isTrue);
  });

  test('colors keywords, numbers, and calls distinctly', () {
    const code = 'return 42 max(1)';
    final spans = SyntaxHighlighter.highlight(code, 'kotlin');
    expect(spans.length, greaterThan(1));
    expect(SyntaxHighlighter.plainText(spans), code);
  });
}
