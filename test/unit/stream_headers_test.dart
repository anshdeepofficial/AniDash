import 'package:ani_dash/core/utils/stream_headers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeStreamHeaders', () {
    test('canonicalizes lowercase referer without a duplicate', () {
      final headers = normalizeStreamHeaders(
        'https://cdn.example/video/master.m3u8',
        {
          'referer': 'https://provider.example/watch/1',
          'Origin': 'https://provider.example',
        },
      );

      expect(headers['Referer'], 'https://provider.example/watch/1');
      expect(headers['Origin'], 'https://provider.example');
      expect(
        headers.keys.where((key) => key.toLowerCase() == 'referer').length,
        1,
      );
    });

    test('last case-insensitive provider value wins', () {
      final headers = normalizeStreamHeaders(
        'https://cdn.example/video/master.m3u8',
        {
          'Referer': 'https://old.example/',
          'rEfErEr': 'https://correct.example/',
          'user-agent': 'Provider-UA',
        },
      );

      expect(headers['Referer'], 'https://correct.example/');
      expect(headers['User-Agent'], 'Provider-UA');
      expect(
        headers.keys.where((key) => key.toLowerCase() == 'user-agent').length,
        1,
      );
    });

    test('derives same-host referer only when provider omitted it', () {
      final headers = normalizeStreamHeaders(
        'https://media.example/path/master.m3u8?token=abc',
        const {},
      );

      expect(headers['Referer'], 'https://media.example/');
      expect(headers['User-Agent'], isNotEmpty);
    });
  });
}
