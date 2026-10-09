import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_client/ui/markdown/markdown.dart';

void main() {
  test('parses code blocks with language', () {
    final blocks = MarkdownParser.parse('# Title\n\ntext\n\n```kotlin\nfun main() {}\n```');
    expect(blocks[0], isA<MdHeading>());
    expect((blocks[0] as MdHeading).level, 1);
    expect((blocks[0] as MdHeading).text, 'Title');
    expect(blocks[1], isA<MdParagraph>());
    final code = blocks[2] as MdCode;
    expect(code.lang, 'kotlin');
    expect(code.code, 'fun main() {}');
  });

  test('parses lists and quotes', () {
    final md = '- a\n- b\n\n> quoted';
    final blocks = MarkdownParser.parse(md);
    final list = blocks[0] as MdListBlock;
    expect(list.items, ['a', 'b']);
    expect(list.ordered, isFalse);
    final quote = blocks[1] as MdQuote;
    expect(quote.text, 'quoted');
  });

  test('parses ordered lists', () {
    final blocks = MarkdownParser.parse('1. one\n2. two');
    final list = blocks[0] as MdListBlock;
    expect(list.ordered, isTrue);
    expect(list.items, ['one', 'two']);
  });

  test('parses table', () {
    final md = '| a | b |\n| --- | --- |\n| 1 | 2 |';
    final table = MarkdownParser.parse(md)[0] as MdTable;
    expect(table.header, ['a', 'b']);
    expect(table.rows[0], ['1', '2']);
  });

  test('parses standalone image and media lines', () {
    final blocks = MarkdownParser.parse('![alt](https://x/y.png)\nMEDIA:https://files/z.bin');
    final image = blocks[0] as MdImage;
    expect(image.alt, 'alt');
    expect(image.url, 'https://x/y.png');
    final media = blocks[1] as MdMedia;
    expect(media.path, 'https://files/z.bin');
  });

  test('merges consecutive lines into one paragraph', () {
    final blocks = MarkdownParser.parse('first\nsecond\n\nthird');
    expect(blocks.length, 2);
    expect((blocks[0] as MdParagraph).text, 'first\nsecond');
    expect((blocks[1] as MdParagraph).text, 'third');
  });
}
