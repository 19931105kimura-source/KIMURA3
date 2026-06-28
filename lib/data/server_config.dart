class ServerConfig {
  // まとめて変更したいときはこの1箇所だけ編集。
  // 例: --dart-define=SERVER_BASE_URL=http://10.0.2.2:3000
  static const String baseUrl = String.fromEnvironment(
    'SERVER_BASE_URL',
    defaultValue: 'http://192.168.11.5:3000',
  );

  static final Uri baseUri = Uri.parse(baseUrl);

  static String wsBaseUrl({String? mode, String? table}) {
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final query = <String, String>{};
    if (mode != null && mode.trim().isNotEmpty) {
      query['mode'] = mode.trim();
    }
    if (table != null && table.trim().isNotEmpty) {
      query['table'] = table.trim();
    }
    return baseUri
        .replace(
          scheme: wsScheme,
          queryParameters: query.isEmpty ? null : query,
        )
        .toString();
  }

  static Uri api(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return baseUri.replace(path: normalizedPath);
  }

  static String assetUrl(String path) {
    final raw = path.trim();
    if (raw.isEmpty) return '';

    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme) {
      if (!parsed.path.startsWith('/uploads/')) return raw;
      return baseUri
          .replace(
            path: parsed.path,
            query: parsed.hasQuery ? parsed.query : null,
            fragment: parsed.hasFragment ? parsed.fragment : null,
          )
          .toString();
    }

    final normalizedPath = raw.startsWith('/') ? raw : '/$raw';
    return baseUri.replace(path: normalizedPath).toString();
  }
}
