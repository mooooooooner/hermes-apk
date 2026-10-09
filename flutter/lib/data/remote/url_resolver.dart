/// Pure URL join used by the dynamic-URL interceptors; unit-tested to prevent
/// double path prefixes (the single most dangerous bug in this app: the Base
/// URL may contain a path prefix like `/hermes-api`, and every request must
/// carry only the *relative* path so the interceptor prepends it exactly once).
library;

class InvalidBaseUrl implements Exception {
  final String base;
  const InvalidBaseUrl(this.base);
  @override
  String toString() => '服务器地址无效: $base';
}

Uri resolveUri(String base, Uri requestUrl) {
  var trimmed = base.trim();
  while (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  Uri baseUrl;
  try {
    baseUrl = Uri.parse(trimmed);
  } on FormatException {
    throw InvalidBaseUrl(base);
  }
  if (!baseUrl.hasScheme || baseUrl.host.isEmpty) {
    throw InvalidBaseUrl(base);
  }
  final relative = requestUrl.path.replaceFirst(RegExp(r'^/+'), '');
  var path = baseUrl.path;
  if (relative.isNotEmpty) {
    path = path.endsWith('/') ? '$path$relative' : '$path/$relative';
  }
  return baseUrl.replace(
    path: path,
    query: requestUrl.query.isEmpty ? null : requestUrl.query,
  );
}
