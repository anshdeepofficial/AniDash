const String _defaultStreamUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/122.0.0.0 Safari/537.36';

/// Canonicalizes provider stream headers case-insensitively.
///
/// Extractors may return `referer`, `Referer` or `referrer`. Keeping more
/// than one semantic copy can make HLS master and segment requests disagree.
Map<String, String> normalizeStreamHeaders(
  String url,
  Map<String, String>? headers,
) {
  final normalized = <String, String>{};

  void put(String rawKey, String rawValue) {
    final key = rawKey.trim();
    final value = rawValue.trim();
    if (key.isEmpty || value.isEmpty) return;

    final lower = key.toLowerCase();
    final canonical = switch (lower) {
      'user-agent' => 'User-Agent',
      'referer' => 'Referer',
      'referrer' => 'Referer',
      'origin' => 'Origin',
      'cookie' => 'Cookie',
      _ => key,
    };

    String? duplicateKey;
    for (final existing in normalized.keys) {
      if (existing.toLowerCase() == canonical.toLowerCase()) {
        duplicateKey = existing;
        break;
      }
    }
    if (duplicateKey != null) normalized.remove(duplicateKey);
    normalized[canonical] = value;
  }

  put('User-Agent', _defaultStreamUserAgent);
  if (headers != null) {
    for (final entry in headers.entries) {
      put(entry.key, entry.value);
    }
  }

  if (!normalized.containsKey('Referer')) {
    final uri = Uri.tryParse(url);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      put('Referer', '${uri.scheme}://${uri.host}/');
    }
  }

  return normalized;
}
