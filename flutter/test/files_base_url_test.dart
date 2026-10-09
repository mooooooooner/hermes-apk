import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_client/data/prefs/settings_repository.dart';

void main() {
  test('swaps /hermes-api suffix', () {
    expect(
      AppSettings.deriveFilesBaseUrl('https://example.com/hermes-api'),
      'https://example.com/hermes-files',
    );
  });

  test('swaps /api suffix', () {
    expect(
      AppSettings.deriveFilesBaseUrl('https://example.com/api'),
      'https://example.com/hermes-files',
    );
  });

  test('appends when no known suffix', () {
    expect(
      AppSettings.deriveFilesBaseUrl('https://example.com'),
      'https://example.com/hermes-files',
    );
  });

  test('trims trailing slashes', () {
    expect(
      AppSettings.deriveFilesBaseUrl('https://example.com/hermes-api/'),
      'https://example.com/hermes-files',
    );
  });

  test('empty base stays empty', () {
    expect(AppSettings.deriveFilesBaseUrl('  '), '');
  });
}
