import 'package:html/parser.dart' as html_parser;

String parseHtmlToString(String htmlString) {
  if (htmlString.isEmpty) return '';
  // Convert HTML line breaks and paragraphs to newlines
  final formatted = htmlString
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'~!.*?~!', dotAll: true), '') // remove AniList spoilers
      .replaceAll(
        RegExp(r'\[/?(b|i|u|quote|code|spoiler)\]', caseSensitive: false),
        '',
      ); // remove BBCode tags

  final document = html_parser.parse(formatted);
  final text = document.body?.text ?? '';
  // Normalize consecutive newlines and trim whitespace
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
