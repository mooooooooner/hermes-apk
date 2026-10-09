import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_client/data/remote/url_resolver.dart';

void main() {
  test('prepends base path exactly once for relative request', () {
    final resolved = resolveUri(
      'https://test.monsoons.dev/hermes-api',
      Uri.parse('http://localhost/v1/runs/run_1/events'),
    );
    expect(
      resolved.toString(),
      'https://test.monsoons.dev/hermes-api/v1/runs/run_1/events',
    );
  });

  test('works when base has no path', () {
    final resolved = resolveUri(
      'https://host',
      Uri.parse('http://localhost/v1/models'),
    );
    expect(resolved.toString(), 'https://host/v1/models');
  });

  test('preserves query parameters', () {
    final resolved = resolveUri(
      'https://host/hermes-api',
      Uri.parse('http://localhost/api/sessions/s1/messages?limit=500'),
    );
    expect(
      resolved.toString(),
      'https://host/hermes-api/api/sessions/s1/messages?limit=500',
    );
  });

  test('rejects base without scheme or host', () {
    expect(() => resolveUri('not a url', Uri.parse('http://localhost/v1')),
        throwsA(isA<InvalidBaseUrl>()));
    expect(() => resolveUri('ftp://host', Uri.parse('http://localhost/v1')),
        isNot(throwsA(anything)));
  });
}
